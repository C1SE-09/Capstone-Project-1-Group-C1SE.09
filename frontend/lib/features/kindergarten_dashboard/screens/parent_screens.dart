// parent_screens.dart
// =========================================================
// Màn phụ huynh: shell 2 tab (Tổng quan / Tài khoản) + sheet báo cáo.
// Tab Tài khoản nằm ở parent_account.dart.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/data/repositories/http_schedule_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart'
    as domain_status;

import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_account.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_notifications.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/timetable_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:dio/dio.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/no_assignment_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_navigation.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_navigation_scroll.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_parent_overview.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/report_discussion_section.dart';

class NoChildAssignedException implements Exception {
  final String message;
  NoChildAssignedException([this.message = 'Chưa có bé được đăng ký']);
  @override
  String toString() => message;
}

class ParentFlow extends StatefulWidget {
  const ParentFlow({
    super.key,
    this.repository,
    this.leaveRequestRepository,
    this.onLogout,
    this.initialOpenReport = false,
    this.initialOpenRequests = false,
    this.childId,
    this.initialReportId,
    this.initialAttendanceDate,
    this.notificationId,
    this.medicationRepository,
    this.scheduleRepository,
  });
  final HttpDashboardRepository? repository;
  final HttpLeaveRequestRepository? leaveRequestRepository;
  final HttpMedicationRepository? medicationRepository;
  final ScheduleRepository? scheduleRepository;
  final VoidCallback? onLogout;

  /// True khi mở từ push notification: vào thẳng báo cáo hôm nay (Scope A).
  final bool initialOpenReport;
  final bool initialOpenRequests;
  final String? childId;
  final String? initialReportId;
  final String? initialAttendanceDate;
  final String? notificationId;
  @override
  State<ParentFlow> createState() => _ParentFlowState();
}

class _ParentFlowState extends State<ParentFlow> {
  late final HttpDashboardRepository repository =
      widget.repository ?? HttpDashboardRepository();
  late Future<_ParentData> future;
  int _tab = 0;
  bool _notificationsOpen = false;
  final _pages = <int, Widget>{};
  bool _notificationOpened = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(ParentFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.childId != oldWidget.childId ||
        widget.initialReportId != oldWidget.initialReportId ||
        widget.initialAttendanceDate != oldWidget.initialAttendanceDate ||
        widget.initialOpenRequests != oldWidget.initialOpenRequests ||
        widget.notificationId != oldWidget.notificationId ||
        (widget.initialOpenReport && !oldWidget.initialOpenReport)) {
      _notificationOpened = false;
      if (widget.childId != oldWidget.childId) _pages.clear();
      _reload();
    }
  }

  void _reload() {
    future = _load();
    _openInitialReport();
    _openInitialRequests();
  }

  void _openInitialRequests() {
    if (_notificationOpened || !widget.initialOpenRequests) return;
    final loading = future;
    loading.then((data) {
      if (!mounted || future != loading) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            future != loading ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        _notificationOpened = true;
        _openRequests(data);
        PushNotificationService.instance
            .completePendingNotification(widget.notificationId);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }, onError: (_) {});
  }

  void _openInitialReport() {
    if (_notificationOpened) return;
    final loading = future;
    final reportId = widget.initialReportId;
    final attendanceDate =
        DateTime.tryParse(widget.initialAttendanceDate ?? '');
    final openToday = widget.initialOpenReport;
    if (reportId == null && attendanceDate == null && !openToday) return;
    loading.then(
      (data) async {
        DailyReport? report;
        bool failed = false;
        if (reportId != null) {
          try {
            report = await repository.getParentReport(reportId);
            failed = report.dailyReportId != reportId ||
                report.childId != data.overview.child.childId ||
                report.status == domain_status.ReportStatus.draft;
          } catch (_) {
            failed = true;
          }
        } else if (openToday) {
          report = data.today;
        }
        if (!mounted || future != loading) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              future != loading ||
              ModalRoute.of(context)?.isCurrent != true) {
            return;
          }
          if (attendanceDate != null) {
            _notificationOpened = true;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Thông báo bé vắng: ${data.overview.child.fullName}, '
                  'ngày ${kDateLabel(attendanceDate)}. Vui lòng liên hệ giáo viên để xác nhận.'),
            ));
            PushNotificationService.instance
                .completePendingNotification(widget.notificationId);
          } else if (failed) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Không thể mở báo cáo này. Vui lòng thử lại sau.'),
            ));
          } else if (report != null) {
            _notificationOpened = true;
            _openReport(data, report);
            PushNotificationService.instance
                .completePendingNotification(widget.notificationId);
          }
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
      onError: (_) {},
    );
  }

  // Loads parent-linked child and report history from existing endpoints.
  Future<_ParentData> _load() async {
    final childId = widget.childId;
    final parent = await repository.getCurrentParent();
    try {
      final overview = childId == null
          ? await repository.getPrimaryChildOverview(parent.parentId)
          : await repository.getChildOverviewForParent(
              parent.parentId, childId);
      final reports = await repository.getRecentReports(
        overview.child.childId,
        includeDraft: false,
      );
      final today = DateTime.now();
      final todayReport = await repository.getTodayReport(
        overview.child.childId,
        today,
        includeDraft: false,
      );
      return _ParentData(parent, overview, reports, todayReport);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 ||
          (e.response?.data is Map &&
              e.response?.data['detail'] == 'Child not found')) {
        throw NoChildAssignedException();
      }
      rethrow;
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('404') || str.contains('child not found')) {
        throw NoChildAssignedException();
      }
      rethrow;
    }
  }

  void _openReport(_ParentData data, DailyReport report) {
    if (report.hasUnreadResponses) {
      final cleared = report.copyWith(unreadResponseCount: 0);
      setState(() {
        future = future.then((current) => current.withReport(cleared));
      });
    }
    showParentReportSheet(
      context,
      report: report,
      childName: data.overview.child.fullName,
      teacherName: data.overview.teacherName,
      repository: repository,
      onReportRead: (updated) {
        if (!mounted) return;
        setState(() {
          future = future.then((current) => current.withReport(updated));
        });
      },
    );
  }

  void _onPhoneUpdated(String phone) {
    setState(() {
      future = future.then(
        (current) => _ParentData(
          current.parent.copyWith(phone: phone),
          current.overview,
          current.reports,
          current.today,
        ),
      );
    });
  }

  void _onHealthUpdated(Child child) => _onChildUpdated(child);

  void _onParentUpdated(String phone, String? email, String? relationship) {
    setState(() {
      future = future.then(
        (current) => _ParentData(
          current.parent.copyWith(
            phone: phone,
            email: email,
            relationship: relationship,
          ),
          current.overview,
          current.reports,
          current.today,
        ),
      );
    });
  }

  void _onChildUpdated(Child updatedChild) {
    setState(() {
      future = future.then(
        (current) => _ParentData(
          current.parent,
          ChildOverview(
            child: updatedChild,
            className: current.overview.className,
            teacherName: current.overview.teacherName,
            teacherId: current.overview.teacherId,
            teacherPhone: current.overview.teacherPhone,
            roomNumber: current.overview.roomNumber,
          ),
          current.reports,
          current.today,
        ),
      );
    });
  }

  /// Báo cáo chưa đọc (đã gửi nhưng phụ huynh chưa mở hoặc có phản hồi mới).
  int _unreadCount(_ParentData data) {
    return data.notificationReports
        .where((r) =>
            r.status != domain_status.ReportStatus.read ||
            r.hasUnreadResponses)
        .length;
  }

  void _openRequests(_ParentData data) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => GardenVoiceScope(
              child: ParentRequestsScreen(
                child: data.overview.child,
                className: data.overview.className,
                teacherName: data.overview.teacherName,
                repository: widget.leaveRequestRepository,
              ),
            )));
  }

  void _openMedication(_ParentData data) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => GardenVoiceScope(
              child: ParentMedicationScreen(
                child: data.overview.child,
                className: data.overview.className,
                repository: widget.medicationRepository,
              ),
            )));
  }

  void _openTimetable(_ParentData data) {
    final overview = data.overview;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.k.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SizedBox.expand(
        child: GardenVoiceScope(
          child: TimetableScreen(
            classId: overview.child.classId?.isNotEmpty == true
                ? overview.child.classId!
                : 'aaaaaaaa-0000-0000-0000-000000000001',
            className: overview.className.isNotEmpty
                ? 'Lớp ${overview.className}'
                : 'Lớp của bé',
            repository: widget.scheduleRepository,
            isReadOnly: true,
            embedded: true,
          ),
        ),
      ),
    );
  }

  Future<void> _markAllNotificationsRead(_ParentData data) async {
    final unread = data.notificationReports
        .where((report) => report.status != domain_status.ReportStatus.read);
    await Future.wait(unread.map((report) async {
      try {
        final updated = await repository.markReportAsRead(report.dailyReportId);
        if (!mounted) return;
        setState(() {
          future = future.then((current) => current.withReport(updated));
        });
      } catch (_) {
        // Một báo cáo lỗi vẫn giữ trạng thái chưa đọc; các báo cáo khác tiếp tục.
      }
    }));
  }

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      _notificationsOpen = false;
    });
  }

  Future<void> _handleRefresh() async {
    setState(_reload);
    try {
      await future;
    } catch (_) {
      // FutureBuilder hiện lỗi và giữ nguyên đích thông báo cho lần thử lại.
    }
  }

  // Renders loading, error, empty, and fetched parent data states.
  @override
  Widget build(BuildContext context) => GardenVoiceScope(
        child: PopScope(
          canPop: !_notificationsOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _notificationsOpen) {
              setState(() => _notificationsOpen = false);
            }
          },
          child: _buildContent(context),
        ),
      );

  Widget _buildContent(BuildContext context) => FutureBuilder<_ParentData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return Scaffold(
              backgroundColor: context.k.canvas,
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final isNoChild = error is NoChildAssignedException ||
                error.toString().toLowerCase().contains('child not found') ||
                error.toString().toLowerCase().contains('404');
            if (isNoChild) {
              return NoAssignmentScreen(
                title: 'Chưa có bé được đăng ký',
                message:
                    'Tài khoản phụ huynh của bạn hiện chưa được liên kết với hồ sơ bé nào.\nVui lòng liên hệ nhà trường để được cập nhật thông tin bé.',
                icon: Icons.child_care_outlined,
                onBack: () {
                  if (widget.onLogout != null) {
                    widget.onLogout!();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              );
            }
            return Scaffold(
              backgroundColor: context.k.canvas,
              body: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: _loadError(() => setState(_reload)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return Scaffold(
              backgroundColor: context.k.canvas,
              body: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: _loadError(() => setState(_reload)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          final unread = _unreadCount(data);
          final page = _notificationsOpen
              ? ParentNotifications(
                  reports: data.notificationReports,
                  childName: data.overview.child.fullName,
                  teacherName: data.overview.teacherName,
                  onOpenReport: (report) => _openReport(data, report),
                  onMarkAllRead: () => _markAllNotificationsRead(data),
                )
              : _tab == 0
                  ? GardenVoiceParentOverview(
                      parent: data.parent,
                      overview: data.overview,
                      report: data.today,
                      unreadCount: unread,
                      onOpenReport: (report) => _openReport(data, report),
                      onOpenNotifications: () =>
                          setState(() => _notificationsOpen = true),
                      onOpenTimetable: () => _openTimetable(data),
                      onOpenRequests: () => _openRequests(data),
                      onOpenMedication: () => _openMedication(data),
                    )
                  : ParentAccount(
                      parent: data.parent,
                      overview: data.overview,
                      reports: data.reports,
                      repository: repository,
                      medicationRepository: widget.medicationRepository,
                      onOpenReport: (report) => _openReport(data, report),
                      onPhoneUpdated: _onPhoneUpdated,
                      onHealthUpdated: _onHealthUpdated,
                      onParentUpdated: _onParentUpdated,
                      onChildUpdated: _onChildUpdated,
                      onLogout: widget.onLogout,
                      onOpenNotifications: () =>
                          setState(() => _notificationsOpen = true),
                    );
          final activePage = _notificationsOpen ? 1 : (_tab == 1 ? 2 : 0);
          _pages[activePage] = page;
          return Scaffold(
            backgroundColor:
                _notificationsOpen ? context.k.surface : context.k.canvas,
            body: GardenVoiceNavigationFrame(
              activeTab: activePage,
              autoHide: true,
              body: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      key: const ValueKey('parent-mobile-frame'),
                      width: constraints.maxWidth > 480
                          ? 480
                          : constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: RefreshIndicator(
                        onRefresh: _handleRefresh,
                        child: KeyedSubtree(
                            key: ValueKey(data.overview.child.childId),
                            child: IndexedStack(index: activePage, children: [
                              for (var index = 0; index < 3; index++)
                                TickerMode(
                                    enabled: index == activePage,
                                    child: _pages[index] ??
                                        const SizedBox.shrink()),
                            ])),
                      ),
                    ),
                  ),
                ),
              ),
              navigation: GardenVoiceParentNavigation(
                selected: _notificationsOpen
                    ? GardenVoiceParentDestination.notifications
                    : _tab == 1
                        ? GardenVoiceParentDestination.account
                        : GardenVoiceParentDestination.home,
                onSelected: (destination) {
                  switch (destination) {
                    case GardenVoiceParentDestination.home:
                      _selectTab(0);
                      break;
                    case GardenVoiceParentDestination.reports:
                      if (data.today == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chưa có báo cáo hôm nay.'),
                          ),
                        );
                      } else {
                        _openReport(data, data.today!);
                      }
                      break;
                    case GardenVoiceParentDestination.notifications:
                      setState(() => _notificationsOpen = true);
                      break;
                    case GardenVoiceParentDestination.account:
                      _selectTab(1);
                      break;
                  }
                },
              ),
            ),
          );
        },
      );

  // Builds a retry panel for failed data requests.
  Widget _loadError(VoidCallback retry) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Không tải được dữ liệu phụ huynh.',
              style: TextStyle(fontSize: 14, color: context.k.ink),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: retry, child: const Text('Thử lại')),
          ],
        ),
      );
}

class _ParentData {
  const _ParentData(this.parent, this.overview, this.reports, this.today);
  final Parent parent;
  final ChildOverview overview;
  final List<DailyReport> reports;
  final DailyReport? today;

  List<DailyReport> get notificationReports {
    // Báo cáo hôm nay có thể đồng thời nằm trong lịch sử; ưu tiên dữ liệu mới nhất.
    final unique = <String, DailyReport>{};
    for (final report in [if (today != null) today!, ...reports]) {
      if (report.status == domain_status.ReportStatus.published ||
          report.status == domain_status.ReportStatus.read) {
        unique.putIfAbsent(report.dailyReportId, () => report);
      }
    }
    return unique.values.toList()
      ..sort((a, b) => (b.publishedAt ?? b.reportDate)
          .compareTo(a.publishedAt ?? a.reportDate));
  }

  _ParentData withReport(DailyReport updated) => _ParentData(
        parent,
        overview,
        reports
            .map((r) => r.dailyReportId == updated.dailyReportId ? updated : r)
            .toList(),
        today?.dailyReportId == updated.dailyReportId ? updated : today,
      );
}

/// Sheet báo cáo hằng ngày — mở từ card báo cáo, danh sách gần đây,
/// hoặc push notification.
Future<void> showParentReportSheet(
  BuildContext context, {
  required DailyReport? report,
  required String childName,
  required String teacherName,
  HttpDashboardRepository? repository,
  ValueChanged<DailyReport>? onReportRead,
}) {
  return showKSheet(
    context,
    GardenVoiceScope(
      child: _ParentReportBody(
        report: report,
        childName: childName,
        teacherName: teacherName,
        repository: repository,
        onReportRead: onReportRead,
      ),
    ),
  );
}

class _ParentReportBody extends StatefulWidget {
  const _ParentReportBody({
    required this.report,
    required this.childName,
    required this.teacherName,
    this.repository,
    this.onReportRead,
  });

  final DailyReport? report;
  final String childName;
  final String teacherName;
  final HttpDashboardRepository? repository;
  final ValueChanged<DailyReport>? onReportRead;

  @override
  State<_ParentReportBody> createState() => _ParentReportBodyState();
}

class _ParentReportBodyState extends State<_ParentReportBody> {
  late DailyReport? _currentReport = widget.report;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void didUpdateWidget(_ParentReportBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.report?.dailyReportId != oldWidget.report?.dailyReportId) {
      _currentReport = widget.report;
      _markRead();
    }
  }

  void _markRead() {
    final rep = _currentReport;
    if (rep != null &&
        rep.status != domain_status.ReportStatus.read &&
        rep.status != domain_status.ReportStatus.draft) {
      widget.repository?.markReportAsRead(rep.dailyReportId).then((updated) {
        if (mounted) setState(() => _currentReport = updated);
        widget.onReportRead?.call(updated);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _currentReport;
    final reportDate = report?.reportDate;
    final dayName =
        reportDate == null ? null : kWeekdayLabel(reportDate);
    final date = reportDate == null
        ? null
        : '$dayName · ${DateFormat('dd/MM').format(reportDate)}';

    // Chỉ hiển thị các mục có dữ liệu thực tế được giáo viên nhập/ghi âm
    final eating = _nonEmpty(report?.eating);
    final sleeping = _stripSleepMinutes(report?.sleeping);
    final activities = _nonEmpty(report?.activitiesText);
    final mood = _nonEmpty(report?.mood);
    final health = _nonEmpty(report?.health);
    final note = _nonEmpty(report?.summaryText);

    final hasAnyData = eating != null ||
        sleeping != null ||
        activities != null ||
        mood != null ||
        health != null ||
        note != null;

    final hasReportId = report != null && report.dailyReportId.isNotEmpty;

    final reportContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/garden_voice/teacher_garden.png',
            width: double.infinity,
            height: 106,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: KSpace.x3),
        if (eating != null)
          _ReportField(
              iconAsset: 'assets/garden_voice/review_bowl.svg',
              label: 'Ăn uống',
              value: eating),
        if (sleeping != null)
          _ReportField(
              iconAsset: 'assets/garden_voice/review_moon.svg',
              label: 'Giấc ngủ',
              value: sleeping),
        if (activities != null)
          _ReportField(
              iconAsset: 'assets/garden_voice/review_artist_palette.svg',
              label: 'Hoạt động',
              value: activities),
        if (mood != null)
          _ReportField(
              icon: Icons.sentiment_satisfied_outlined,
              label: 'Tâm trạng',
              value: mood),
        if (health != null)
          _ReportField(
              icon: Icons.health_and_safety_outlined,
              label: 'Sức khỏe',
              value: health),
        if (note != null)
          _ReportField(
              icon: Icons.edit_note,
              label: 'Lời nhắn của ${widget.teacherName}',
              value: note,
              highlighted: true),
        if (!hasAnyData)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Chưa có thông tin ghi nhận cho ngày này.',
                style: TextStyle(
                    color: context.k.inkFaint, fontSize: 13),
              ),
            ),
          ),
        const SizedBox(height: KSpace.x3),
        KButton(
          label: 'Đã đọc báo cáo ✓',
          secondary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );

    if (hasReportId) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            _buildHeaderRow(context, date),
            Expanded(
              child: ReportDiscussionSection(
                reportId: report.dailyReportId,
                childName: widget.childName,
                teacherName: widget.teacherName,
                header: reportContent,
                padding: const EdgeInsets.only(top: KSpace.x3),
                bottomBarPadding: const EdgeInsets.only(top: 8),
                onDiscussionUpdated: () {
                  if (!mounted) return;
                  if (_currentReport != null &&
                      _currentReport!.hasUnreadResponses) {
                    final updated =
                        _currentReport!.copyWith(unreadResponseCount: 0);
                    setState(() => _currentReport = updated);
                    widget.onReportRead?.call(updated);
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeaderRow(context, date),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: KSpace.x3),
              child: reportContent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, String? date) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Báo cáo ngày',
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: context.k.ink,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Đóng báo cáo',
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          icon: SvgPicture.asset(
            'assets/garden_voice/parent_report_close.svg',
            width: 44,
            height: 44,
          ),
        ),
        if (date != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: context.k.brandTint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              date,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: context.k.brand,
              ),
            ),
          ),
      ],
    );
  }
}

/// A single labelled field card in the parent report view.
class _ReportField extends StatelessWidget {
  const _ReportField({
    required this.label,
    required this.value,
    this.icon,
    this.iconAsset,
    this.highlighted = false,
  });
  final IconData? icon;
  final String? iconAsset;
  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: KSpace.x2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? context.k.accentTint : context.k.reviewSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (iconAsset != null)
            SvgPicture.asset(iconAsset!)
          else if (icon != null)
            Icon(icon, size: 24, color: context.k.brand),
          if (icon != null || iconAsset != null)
            const SizedBox(width: KSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: highlighted
                            ? context.k.accentDeep
                            : context.k.ink)),
                const SizedBox(height: KSpace.x1),
                Text(value,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color:
                            highlighted ? context.k.ink : context.k.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Returns null if value is null or blank — used to skip empty report fields.
String? _nonEmpty(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _stripSleepMinutes(String? value) {
  final clean = _nonEmpty(value);
  if (clean == null) return null;
  final stripped = clean
      .replaceAll(
          RegExp(r'\s*(?:[·,–-]\s*)?\d+\s*phút\b', caseSensitive: false), '')
      .trim();
  return stripped.isEmpty ? clean : stripped;
}
