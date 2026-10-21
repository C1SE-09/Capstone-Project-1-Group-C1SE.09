// parent_screens.dart
// =========================================================
// Màn phụ huynh: shell 2 tab (Tổng quan / Tài khoản) + sheet báo cáo.
// Tab Tài khoản nằm ở parent_account.dart.

import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart' as domain_child;
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';
import 'package:adark_frontend/domain/entities/report/report_status.dart' as domain_status;

import 'package:adark_frontend/features/kindergarten_dashboard/adapters/report_status_adapter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_account.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/timetable_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:dio/dio.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/no_assignment_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class NoChildAssignedException implements Exception {
  final String message;
  NoChildAssignedException([this.message = 'Chưa có bé được đăng ký']);
  @override
  String toString() => message;
}

class ParentFlow extends StatefulWidget {
  const ParentFlow({super.key, this.repository, this.onLogout, this.initialOpenReport = false});
  final HttpDashboardRepository? repository;
  final VoidCallback? onLogout;

  /// True khi mở từ push notification: vào thẳng báo cáo hôm nay (Scope A).
  final bool initialOpenReport;
  @override
  State<ParentFlow> createState() => _ParentFlowState();
}

class _ParentFlowState extends State<ParentFlow> {
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late Future<_ParentData> future;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    future = _load();
    // Chạm push notification → mở thẳng sheet báo cáo hôm nay khi dữ liệu tải xong.
    future.then(
      (data) {
        if (!mounted || !widget.initialOpenReport) return;
        final today = data.today;
        if (today == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openReport(data, today);
        });
      },
      onError: (_) {},
    );
  }

  // Loads parent-linked child and report history from existing endpoints.
  Future<_ParentData> _load() async {
    final parent = await repository.getCurrentParent();
    try {
      final overview = await repository.getPrimaryChildOverview(parent.parentId);
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
          (e.response?.data is Map && e.response?.data['detail'] == 'Child not found')) {
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
    showParentReportSheet(
      context,
      report: report,
      childName: data.overview.child.fullName,
      teacherName: data.overview.teacherName,
      repository: repository,
      onReportRead: (updated) => setState(() {
        future = future.then((current) => current.withReport(updated));
      }),
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

  void _onHealthUpdated(domain_child.Child child) {
    setState(() {
      future = future.then(
        (current) => _ParentData(
          current.parent,
          ChildOverview(
            child: child,
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

  /// Báo cáo chưa đọc (đã gửi nhưng phụ huynh chưa mở).
  int _unreadCount(_ParentData data) {
    // API trả báo cáo hôm nay nằm luôn trong danh sách gần đây → khử trùng theo id,
    // nếu không badge sẽ đếm gấp đôi cùng một báo cáo.
    final unique = <String, DailyReport>{};
    for (final report in <DailyReport>[
      if (data.today != null) data.today!,
      ...data.reports,
    ]) {
      unique[report.dailyReportId] = report;
    }
    return unique.values
        .where(
          (r) =>
              r.status != domain_status.ReportStatus.read &&
              r.status != domain_status.ReportStatus.draft,
        )
        .length;
  }

  // Renders loading, error, empty, and fetched parent data states.
  @override
  Widget build(BuildContext context) => FutureBuilder<_ParentData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
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
                message: 'Tài khoản phụ huynh của bạn hiện chưa được liên kết với hồ sơ bé nào.\nVui lòng liên hệ nhà trường để được cập nhật thông tin bé.',
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
              body: SafeArea(child: _loadError(() => setState(() => future = _load()))),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return Scaffold(
              backgroundColor: context.k.canvas,
              body: SafeArea(child: _loadError(() => setState(() => future = _load()))),
            );
          }
          final unread = _unreadCount(data);
          return Scaffold(
            backgroundColor: context.k.canvas,
            body: SafeArea(
              child: _tab == 0
                  ? _ParentOverview(
                      data: data,
                      onOpenReport: (report) => _openReport(data, report),
                    )
                  : ParentAccount(
                      parent: data.parent,
                      overview: data.overview,
                      reports: data.reports,
                      repository: repository,
                      onOpenReport: (report) => _openReport(data, report),
                      onPhoneUpdated: _onPhoneUpdated,
                      onHealthUpdated: _onHealthUpdated,
                      onLogout: widget.onLogout,
                    ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (index) => setState(() => _tab = index),
              destinations: [
                NavigationDestination(
                  icon: Badge(
                    key: const ValueKey('parent-unread-badge'),
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.home_outlined),
                  ),
                  selectedIcon: Badge(
                    key: const ValueKey('parent-unread-badge-selected'),
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.home),
                  ),
                  label: 'Tổng quan',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Tài khoản',
                ),
              ],
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

  _ParentData withReport(DailyReport updated) => _ParentData(
        parent,
        overview,
        reports
            .map((r) => r.dailyReportId == updated.dailyReportId ? updated : r)
            .toList(),
        today?.dailyReportId == updated.dailyReportId ? updated : today,
      );
}

/// Tab Tổng quan: lời chào, card bé + thời khoá biểu, lưu ý sức khỏe,
/// báo cáo hôm nay và báo cáo gần đây.
class _ParentOverview extends StatelessWidget {
  const _ParentOverview({required this.data, required this.onOpenReport});

  final _ParentData data;
  final ValueChanged<DailyReport> onOpenReport;

  void _openTimetable(BuildContext context) {
    final overview = data.overview;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimetableScreen(
          classId: overview.child.classId?.isNotEmpty == true
              ? overview.child.classId!
              : 'aaaaaaaa-0000-0000-0000-000000000001',
          className: overview.className.isNotEmpty ? 'Lớp ${overview.className}' : 'Lớp của bé',
          isReadOnly: true,
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    final unread = data.reports
        .where((r) => r.status != domain_status.ReportStatus.read)
        .toList();
    showKSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Thông báo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (unread.isEmpty)
            const Text('Bạn đã đọc tất cả báo cáo.')
          else ...[
            KCard(
              onTap: () {
                Navigator.pop(context);
                onOpenReport(unread.first);
              },
              padding: const EdgeInsets.all(14),
              child: Text(
                'Bạn có ${unread.length} báo cáo chưa đọc. Báo cáo gần nhất ngày ${kDateLabel(unread.first.reportDate)}.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = data.overview;
    final child = overview.child;
    final date = kDateLabel(DateTime.now());
    final hasTodayReport = data.today != null;
    final allergy = child.allergy; // đã bỏ "Không có" + tiền tố "Dị ứng"

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào,',
                    style: TextStyle(fontSize: 13, color: context.k.inkSoft),
                  ),
                  Text(
                    data.parent.fullName.isEmpty ? 'Phụ huynh bé ${child.fullName}' : data.parent.fullName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: context.k.ink,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showNotifications(context),
              tooltip: 'Thông báo',
              icon: Icon(Icons.notifications_outlined, color: context.k.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: 14),
        KCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              InkWell(
                onTap: () => showParentChildSheet(context, overview: overview),
                child: Row(
                  children: [
                    Avatar(name: child.fullName, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.fullName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
                          ),
                          Text(
                            'Lớp ${overview.className} · ${overview.teacherName}',
                            style: TextStyle(fontSize: 12, color: context.k.inkFaint),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: context.k.inkFaint),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              InkWell(
                onTap: () => _openTimetable(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 18, color: context.k.brand),
                      const SizedBox(width: 8),
                      Text(
                        'Thời khóa biểu của lớp',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.k.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (allergy != null && allergy.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.k.badTint,
              borderRadius: BorderRadius.circular(KRadii.control),
            ),
            child: Row(
              children: [
                Icon(Icons.health_and_safety_outlined, size: 20, color: context.k.bad),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lưu ý sức khỏe',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.k.bad,
                        ),
                      ),
                      Text(
                        'Bé bị dị ứng $allergy',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'Cập nhật trong Hồ sơ sức khỏe để cô giáo lưu ý.',
                        style: TextStyle(fontSize: 12, color: context.k.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Text(
            'Báo cáo hôm nay',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.k.ink),
          ),
        ),
        KCard(
          onTap: hasTodayReport ? () => onOpenReport(data.today!) : null,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: context.k.brandTint,
                foregroundColor: context.k.brand,
                child: const Icon(Icons.description_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasTodayReport ? 'Đã có báo cáo' : 'Chưa có báo cáo hôm nay',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Text(date, style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
                  ],
                ),
              ),
              if (hasTodayReport) ...[
                Text(
                  'Xem báo cáo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.k.brand),
                ),
                Icon(Icons.chevron_right, size: 18, color: context.k.brand),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Text(
            'Báo cáo gần đây',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.k.ink),
          ),
        ),
        if (data.reports.isEmpty)
          const KCard(padding: EdgeInsets.all(16), child: Text('Chưa có báo cáo gần đây.'))
        else
          KCard(
            child: Column(
              children: [
                for (var index = 0; index < data.reports.length; index++) ...[
                  ListTile(
                    onTap: () => onOpenReport(data.reports[index]),
                    leading: Icon(Icons.description_outlined, color: context.k.inkSoft),
                    title: Text(
                      kDateLabel(data.reports[index].reportDate),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          uiReportStatusFromBackend(data.reports[index].status.name).label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: data.reports[index].status.name == 'read' ||
                                    data.reports[index].status.name == 'sent' ||
                                    data.reports[index].status.name == 'published'
                                ? context.k.brand
                                : context.k.inkFaint,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: context.k.inkFaint),
                      ],
                    ),
                  ),
                  if (index < data.reports.length - 1) const Divider(),
                ],
              ],
            ),
          ),
      ],
    );
  }
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
    _ParentReportBody(
      report: report,
      childName: childName,
      teacherName: teacherName,
      repository: repository,
      onReportRead: onReportRead,
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
    final date = kDateLabel(report?.reportDate ?? DateTime.now());

    // Dùng giá trị đã trích xuất, thiếu thì lấy mặc định để báo cáo luôn đủ mục.
    final eating = _nonEmpty(report?.eating) ?? 'Ăn hết suất cơm trưa, uống đủ nước.';
    final sleeping = _nonEmpty(report?.sleeping) ?? 'Ngủ ngon giấc, đúng giờ.';
    final activities = _nonEmpty(report?.activitiesText) ?? 'Tham gia tích cực các hoạt động học tập và vui chơi.';
    final mood = _nonEmpty(report?.mood) ?? 'Vui vẻ, hào hứng, hòa đồng với bạn bè.';
    final health = _nonEmpty(report?.health);
    final note = _nonEmpty(report?.summaryText);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KAppBar(
            title: 'Báo cáo hằng ngày',
            subtitle: date,
            onBack: () => Navigator.pop(context),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Avatar(name: widget.childName, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.childName, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              'Báo cáo hoạt động · ${widget.teacherName}',
                              style: TextStyle(fontSize: 12, color: context.k.inkFaint),
                            ),
                          ],
                        ),
                      ),
                      if (_currentReport != null)
                        StatusBadge(uiReportStatusFromBackend(_currentReport!.status.name)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ReportField(icon: Icons.restaurant_outlined, label: 'Ăn uống', value: eating),
                  _ReportField(icon: Icons.bedtime_outlined, label: 'Giấc ngủ', value: sleeping),
                  _ReportField(icon: Icons.palette_outlined, label: 'Hoạt động', value: activities),
                  _ReportField(icon: Icons.sentiment_satisfied_outlined, label: 'Tâm trạng', value: mood),
                  if (health != null) _ReportField(icon: Icons.health_and_safety_outlined, label: 'Sức khỏe', value: health),
                  if (note != null) _ReportField(icon: Icons.edit_note, label: 'Ghi chú của cô', value: note),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single labelled field card in the parent report view.
class _ReportField extends StatelessWidget {
  const _ReportField({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.k.surface,
        border: Border.all(color: context.k.line),
        borderRadius: BorderRadius.circular(KRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.k.brand),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.k.inkSoft)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 14, height: 1.55)),
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
