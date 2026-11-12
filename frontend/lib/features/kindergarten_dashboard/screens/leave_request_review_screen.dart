// frontend/lib/features/kindergarten_dashboard/screens/leave_request_review_screen.dart
// ======================================================================================
// Màn hình Duyệt đơn xin nghỉ học dành cho Giáo viên (Teacher UI)
// Tuân thủ:
// - Refactor-safely: Tách sub-widgets riêng, build method gọn gàng
// - Giữ nguyên 100% UI và trải nghiệm người dùng
// - Design System: KColors, KSpace, KRadii

import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/core/utils/phone_utils.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/attendance_approval_result_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/reject_reason_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_class_header.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:url_launcher/url_launcher.dart';

class LeaveRequestReviewScreen extends StatefulWidget {
  const LeaveRequestReviewScreen({
    super.key,
    required this.classId,
    this.className,
    this.teacherName,
    this.notificationCount,
    this.onSelectClass,
    this.onOpenNotifications,
    this.repository,
    this.initialRequest,
    this.onNavigationSelected,
    this.onOpenAttendance,
    this.onOpenAttendanceForDate,
    this.onOpenTimetable,
    this.onOpenClassList,
  });

  final String classId;
  final String? className;
  final String? teacherName;
  final int? notificationCount;
  final VoidCallback? onSelectClass;
  final VoidCallback? onOpenNotifications;
  final HttpLeaveRequestRepository? repository;
  final LeaveRequestEntity? initialRequest;
  final ValueChanged<GardenVoiceTeacherDestination>? onNavigationSelected;
  final VoidCallback? onOpenAttendance;
  final ValueChanged<DateTime>? onOpenAttendanceForDate;
  final VoidCallback? onOpenTimetable;
  final VoidCallback? onOpenClassList;

  @override
  State<LeaveRequestReviewScreen> createState() =>
      _LeaveRequestReviewScreenState();
}

class _LeaveRequestReviewScreenState extends State<LeaveRequestReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late HttpLeaveRequestRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  int _pendingCount = 0;
  int _reviewedCount = 0;
  List<LeaveRequestEntity> _items = [];
  List<LeaveRequestEntity> _recentReviewed = [];
  final Set<String> _processing = {};
  final Map<String, String> _rejectionDrafts = {};
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _moreError;
  int _nextOffset = 0;
  int _loadVersion = 0;
  int _scopeVersion = 0;
  bool _focusResolved = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HttpLeaveRequestRepository();
    _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: widget.initialRequest != null &&
                widget.initialRequest!.status != LeaveStatus.pending
            ? 1
            : 0);
    _tabController.addListener(_handleTabChange);
    _loadRequests(tab: _tabController.index == 0 ? 'pending' : 'reviewed');
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LeaveRequestReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId ||
        oldWidget.repository != widget.repository) {
      _scopeVersion++;
      _pendingCount = 0;
      _reviewedCount = 0;
      _repository = widget.repository ?? HttpLeaveRequestRepository();
      _processing.clear();
      _rejectionDrafts.clear();
      _focusResolved = false;
      _loadRequests(tab: _tabController.index == 0 ? 'pending' : 'reviewed');
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final tabName = _tabController.index == 0 ? 'pending' : 'reviewed';
    _loadRequests(tab: tabName);
  }

  Future<void> _loadRequests({required String tab, bool more = false}) async {
    if (more && (_isLoading || _loadingMore)) return;
    final version = ++_loadVersion;
    setState(() {
      _loadingMore = more;
      _isLoading = !more;
      _errorMessage = null;
      _moreError = null;
      if (!more) {
        _nextOffset = 0;
        _hasMore = false;
        _items = [];
      }
    });

    try {
      final Future<LeaveRequestBatchResult?>? recentFuture =
          !more && tab == 'pending'
              ? _repository
                  .getLeaveRequests(
                      classId: widget.classId, tab: 'reviewed', limit: 1)
                  .then<LeaveRequestBatchResult?>((result) => result,
                      onError: (Object _) => null)
              : null;
      final result = await _repository.getLeaveRequests(
        classId: widget.classId,
        tab: tab,
        offset: _nextOffset,
      );
      final recent = await recentFuture;
      if (!mounted || version != _loadVersion) return;
      final focused = widget.initialRequest;
      LeaveRequestEntity? extra;
      if (!more &&
          !_focusResolved &&
          focused != null &&
          focused.classId == widget.classId &&
          !result.items.any((item) => item.requestId == focused.requestId)) {
        extra = await _repository.getRequest(focused.requestId);
        if (!mounted || version != _loadVersion) return;
        if (extra.classId != widget.classId ||
            extra.requestId != focused.requestId) {
          throw const LeaveRequestException('Không thể xác minh đơn của lớp.');
        }
        if ((extra.status == LeaveStatus.pending) != (tab == 'pending')) {
          _tabController.index = extra.status == LeaveStatus.pending ? 0 : 1;
          return;
        }
      }
      if (!more) _focusResolved = true;
      setState(() {
        _pendingCount = result.pendingCount;
        _reviewedCount = result.reviewedCount;
        if (recent != null) _recentReviewed = recent.items;
        _nextOffset += result.items.length;
        final unique = {
          for (final item in [
            ..._items,
            ...result.items,
            if (extra != null &&
                (extra.status == LeaveStatus.pending) == (tab == 'pending'))
              extra
          ])
            item.requestId: item
        };
        _items = unique.values.toList();
        _hasMore = result.items.isNotEmpty &&
            _items.length < (tab == 'pending' ? _pendingCount : _reviewedCount);
        final focusIndex =
            _items.indexWhere((item) => item.requestId == focused?.requestId);
        if (focusIndex > 0) _items.insert(0, _items.removeAt(focusIndex));
        _isLoading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        if (more) {
          _moreError = 'Không tải thêm được đơn. Vui lòng thử lại.';
        } else {
          _errorMessage =
              'Không thể tải danh sách đơn. Vui lòng kiểm tra kết nối mạng.';
        }
        _isLoading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _handleApprove(LeaveRequestEntity item) async {
    if (_processing.contains(item.requestId)) return;
    setState(() => _processing.add(item.requestId));
    final scope = _scopeVersion;
    try {
      final reviewed = await _repository.approveLeaveRequest(item.requestId);
      if (!mounted || scope != _scopeVersion) return;
      if (widget.initialRequest != null) {
        setState(() {
          _items = [reviewed];
          if (_pendingCount > 0) _pendingCount--;
          _reviewedCount++;
        });
      } else {
        await _loadRequests(
            tab: _tabController.index == 0 ? 'pending' : 'reviewed');
      }
      if (!mounted || scope != _scopeVersion) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AttendanceApprovalResultScreen(
            request: reviewed,
            onReturnToAttendance: (date) {
              if (widget.onOpenAttendanceForDate != null) {
                widget.onOpenAttendanceForDate!(date);
              } else {
                widget.onOpenAttendance?.call();
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted || scope != _scopeVersion) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phê duyệt đơn thất bại. Vui lòng thử lại sau.'),
          backgroundColor: KColors.bad,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted && scope == _scopeVersion) {
        setState(() => _processing.remove(item.requestId));
      }
    }
  }

  Future<void> _handleReject(LeaveRequestEntity item) async {
    if (_processing.contains(item.requestId)) return;
    final scope = _scopeVersion;
    var processing = false;
    try {
      final confirmedReason = await RejectReasonDialog.show(
        context,
        childName: item.childName ?? 'Học sinh',
        initialReason: _rejectionDrafts[item.requestId] ?? '',
        request: item,
      );
      if (!mounted ||
          scope != _scopeVersion ||
          confirmedReason == null ||
          confirmedReason.isEmpty) {
        return;
      }
      setState(() => _processing.add(item.requestId));
      processing = true;
      _rejectionDrafts[item.requestId] = confirmedReason;
      final reviewed = await _repository.rejectLeaveRequest(
        requestId: item.requestId,
        rejectReason: confirmedReason,
      );
      if (!mounted || scope != _scopeVersion) return;
      _rejectionDrafts.remove(item.requestId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Đã từ chối đơn. Phụ huynh có thể xem lý do trong ứng dụng.'),
          backgroundColor: KColors.warnDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (widget.initialRequest != null) {
        setState(() {
          _items = [reviewed];
          if (_pendingCount > 0) _pendingCount--;
          _reviewedCount++;
        });
      } else {
        await _loadRequests(
            tab: _tabController.index == 0 ? 'pending' : 'reviewed');
      }
    } catch (e) {
      if (!mounted || scope != _scopeVersion) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Từ chối đơn thất bại. Vui lòng kiểm tra lại.'),
          backgroundColor: KColors.bad,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (processing && mounted && scope == _scopeVersion) {
        setState(() => _processing.remove(item.requestId));
      }
    }
  }

  Future<void> _openAttachment(LeaveRequestEntity item) async {
    final path = item.attachmentUrl;
    if (path == null) return;
    final version = _loadVersion;
    try {
      final bytes = await _repository.getAttachmentBytes(path);
      if (!mounted || version != _loadVersion) return;
      await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: 480,
                      maxHeight: MediaQuery.sizeOf(context).height * .8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Đóng ảnh',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )),
                    Flexible(
                        child: InteractiveViewer(
                            child: Image.memory(
                      bytes,
                      errorBuilder: (context, error, stack) => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Không thể hiển thị ảnh này.'),
                      ),
                    ))),
                  ]),
                ),
              ));
    } catch (_) {
      if (!mounted || version != _loadVersion) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Không tải được ảnh đính kèm. Vui lòng thử lại.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => GardenVoiceScope(
        child: Builder(builder: _buildScreen),
      );

  Widget _buildScreen(BuildContext context) {
    final k = context.k;
    if (widget.initialRequest != null && _focusResolved) {
      for (final item in _items) {
        if (item.requestId == widget.initialRequest!.requestId) {
          return _buildFocusedDetail(item);
        }
      }
    }

    return Scaffold(
      backgroundColor: k.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GardenVoiceClassHeader(
              className: widget.className ?? 'Lớp học',
              subtitle: widget.teacherName ?? '',
              selectedTab: GardenVoiceClassTab.leaveRequests,
              notificationCount: widget.notificationCount,
              pendingLeaveCount: _pendingCount,
              onSelectClass: widget.onSelectClass,
              onOpenNotifications: widget.onOpenNotifications,
              onTabSelected: (tab) {
                switch (tab) {
                  case GardenVoiceClassTab.roster:
                    Navigator.of(context).maybePop();
                    widget.onOpenClassList?.call();
                  case GardenVoiceClassTab.attendance:
                    Navigator.of(context).maybePop();
                    widget.onOpenAttendance?.call();
                  case GardenVoiceClassTab.leaveRequests:
                    break;
                  case GardenVoiceClassTab.timetable:
                    Navigator.of(context).maybePop();
                    widget.onOpenTimetable?.call();
                }
              },
            ),
            Expanded(child: _buildBody(k)),
          ],
        ),
      ),
      bottomNavigationBar: GardenVoiceTeacherNavigation(
        selected: GardenVoiceTeacherDestination.classList,
        onSelected: (destination) {
          if (widget.onNavigationSelected != null) {
            Navigator.of(context).maybePop();
            widget.onNavigationSelected!(destination);
          }
        },
      ),
    );
  }

  Widget _buildFocusedDetail(LeaveRequestEntity item) {
    final pending = item.status == LeaveStatus.pending;
    final late = item.requestType == LeaveRequestType.lateArrival;
    final name = item.childName ?? 'Học sinh';
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words.reversed
        .take(2)
        .toList()
        .reversed
        .map((word) => String.fromCharCode(word.runes.first))
        .join()
        .toUpperCase();
    final k = context.k;
    final (statusBackground, statusColor) = switch (item.status) {
      LeaveStatus.pending => (k.warnTint, k.warnDeep),
      LeaveStatus.approved => (k.okTint, k.ok),
      LeaveStatus.rejected => (k.badTint, k.badText),
      LeaveStatus.cancelled => (k.surfaceSunken, k.inkSoft),
    };
    final dateText = item.totalDays == 1
        ? requestDayLabel(item.fromDate)
        : '${requestDayLabel(item.fromDate)} – ${requestDayLabel(item.toDate)}';
    final avatar = CircleAvatar(
      radius: 20,
      backgroundColor: k.brand,
      child: Text(initials,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: k.surface)),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: k.ink)),
        Text('Lớp ${widget.className ?? 'học sinh'}',
            style: TextStyle(fontSize: 12, color: k.inkSoft)),
      ],
    );
    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: statusBackground, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pending) ...[
            SvgPicture.asset('assets/notifications/pending_dot.svg'),
            const SizedBox(width: 6),
          ],
          Text(requestStatusLabel(item.status),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor)),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: k.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    icon: SvgPicture.asset('assets/notifications/back_44.svg'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Duyệt đơn xin nghỉ',
                            style: TextStyle(
                                fontSize: 17,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: k.ink)),
                        Text('Chi tiết đơn · ${widget.className ?? 'Lớp học'}',
                            style: TextStyle(
                                fontSize: 12, height: 1.4, color: k.inkSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  _detailSurface(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.3;
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                avatar,
                                const SizedBox(width: 12),
                                Expanded(child: identity),
                              ]),
                              const SizedBox(height: 8),
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: statusBadge),
                            ],
                          );
                        }
                        return Row(children: [
                          avatar,
                          const SizedBox(width: 12),
                          Expanded(child: identity),
                          statusBadge,
                        ]);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailSurface(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        _detailRow(
                            'Ngày nghỉ',
                            late
                                ? '${requestDayLabel(item.fromDate)} · Dự kiến đến ${item.expectedArrivalTime?.split(':').take(2).join(':') ?? 'chưa cập nhật'}'
                                : dateText),
                        Divider(height: 1, color: k.line),
                        _detailRow('Số ngày', '${item.totalDays} ngày'),
                        Divider(height: 1, color: k.line),
                        _detailRow('Lý do', item.reason),
                        Divider(height: 1, color: k.line),
                        _detailRow('Người gửi', item.parentName ?? 'Phụ huynh'),
                        Divider(height: 1, color: k.line),
                        _detailRow('Gửi lúc', requestTimestamp(item.createdAt)),
                        if (item.attachmentUrl != null) ...[
                          Divider(height: 1, color: k.line),
                          _detailRow(
                              'Đính kèm',
                              TextButton(
                                  onPressed: () => _openAttachment(item),
                                  child: const Text('Xem ảnh đính kèm'))),
                        ],
                        if (item.contactPhone.isNotEmpty) ...[
                          Divider(height: 1, color: k.line),
                          _detailRow(
                              'SĐT liên hệ',
                              TextButton(
                                  onPressed: () => _callParent(item),
                                  child: Text(maskedPhone(item.contactPhone)))),
                        ],
                        if (item.rejectReason?.isNotEmpty == true) ...[
                          Divider(height: 1, color: k.line),
                          _detailRow('Lý do từ chối', item.rejectReason!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _detailSurface(
                    color: k.brandTint,
                    border: false,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Text(
                      late
                          ? 'Giờ đến dự kiến không phải giờ check-in thực tế.'
                          : 'Khi duyệt, điểm danh sẽ được đồng bộ sang “Vắng có phép”; giờ check-in thực tế được giữ nguyên.',
                      style: TextStyle(fontSize: 12, height: 1.4, color: k.ink),
                    ),
                  ),
                ],
              ),
            ),
            if (pending)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _processing.contains(item.requestId)
                              ? null
                              : () => _handleReject(item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: k.brand,
                            side: BorderSide(color: k.line),
                            minimumSize: const Size(0, 48),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _processing.contains(item.requestId)
                              ? null
                              : () => _handleApprove(item),
                          style: FilledButton.styleFrom(
                            backgroundColor: k.brand,
                            foregroundColor: k.surface,
                            minimumSize: const Size(0, 48),
                            shape: const StadiumBorder(),
                          ),
                          child: _processing.contains(item.requestId)
                              ? SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: k.surface),
                                )
                              : const Text('Duyệt đơn'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    Color? color,
    bool border = true,
  }) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? context.k.surface,
          borderRadius: BorderRadius.circular(24),
          border: border ? Border.all(color: context.k.line) : null,
        ),
        child: child,
      );

  Widget _detailRow(String label, Object value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: context.k.inkSoft)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: value is Widget
                  ? DefaultTextStyle.merge(
                      style: TextStyle(fontSize: 13, color: context.k.ink),
                      child: value)
                  : Text(value.toString(),
                      style: TextStyle(
                          fontSize: 13, height: 1.4, color: context.k.ink)),
            ),
          ],
        ),
      );

  Future<void> _callParent(LeaveRequestEntity item) async {
    final uri = phoneCallUri(item.contactPhone);
    if (uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được ứng dụng gọi điện.')));
    }
  }

  Widget _buildBody(KPalette k) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: k.brand));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(KSpace.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: k.bad),
              const SizedBox(height: KSpace.x3),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: k.inkSoft),
              ),
              const SizedBox(height: KSpace.x4),
              ElevatedButton.icon(
                onPressed: () => _loadRequests(
                  tab: _tabController.index == 0 ? 'pending' : 'reviewed',
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: k.brand,
                  foregroundColor: k.surface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pending = _tabController.index == 0;
    return RefreshIndicator(
      color: k.brand,
      onRefresh: () => _loadRequests(
        tab: pending ? 'pending' : 'reviewed',
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusFilter(k, 'Chờ duyệt ($_pendingCount)', pending, 0),
                const SizedBox(width: 8),
                _statusFilter(k, 'Đã xử lý', !pending, 1),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  pending
                      ? 'Không có đơn nào đang chờ duyệt'
                      : 'Chưa có lịch sử đơn đã xử lý',
                  style: TextStyle(fontSize: 14, color: k.inkSoft),
                ),
              ),
            )
          else
            ..._items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _requestPreview(k, item),
                )),
          if (pending && _recentReviewed.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Đã xử lý gần đây',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: k.ink)),
            const SizedBox(height: 12),
            _recentRequest(k, _recentReviewed.first),
          ],
          if (_hasMore || _loadingMore || _moreError != null) ...[
            if (_loadingMore)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(KSpace.x4),
                      child: CircularProgressIndicator()))
            else ...[
              if (_moreError != null)
                Text(_moreError!, style: TextStyle(color: k.bad)),
              TextButton(
                  onPressed: () => _loadRequests(
                      tab: pending ? 'pending' : 'reviewed', more: true),
                  child: Text(
                      _moreError == null ? 'Tải thêm' : 'Thử lại tải thêm')),
            ],
          ],
        ],
      ),
    );
  }

  Widget _statusFilter(KPalette k, String label, bool selected, int index) =>
      Material(
        color: selected ? k.warnTint : k.okTint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _tabController.index = index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: selected ? k.warnDeep : k.ok,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      );

  Widget _requestPreview(KPalette k, LeaveRequestEntity item) {
    final childName = item.childName ?? 'Học sinh';
    final initials = childName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList()
        .reversed
        .take(2)
        .toList()
        .reversed
        .map((part) => String.fromCharCode(part.runes.first))
        .join()
        .toUpperCase();
    final date = item.totalDays == 1
        ? DateFormat('dd/MM').format(item.fromDate)
        : '${DateFormat('dd/MM').format(item.fromDate)} – ${DateFormat('dd/MM').format(item.toDate)}';
    return Material(
      color: k.brandTint,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        key: ValueKey('leave-request-preview-${item.requestId}'),
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => LeaveRequestReviewScreen(
                  classId: widget.classId,
                  className: widget.className,
                  repository: _repository,
                  initialRequest: item,
                  onNavigationSelected: widget.onNavigationSelected,
                  onOpenAttendance: widget.onOpenAttendance,
                  onOpenTimetable: widget.onOpenTimetable,
                  onOpenClassList: widget.onOpenClassList,
                ))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: k.accentTint,
                  child: Text(initials,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: k.accentDeep)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(childName,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: k.ink)),
                    Text('Nghỉ $date · ${item.parentName ?? 'Phụ huynh'}',
                        style: TextStyle(fontSize: 12, color: k.inkSoft)),
                  ],
                )),
              ]),
              const SizedBox(height: 10),
              Text(item.reason,
                  style: TextStyle(fontSize: 14, color: k.inkSoft)),
              const SizedBox(height: 10),
              Row(children: [
                Flexible(
                  child: Text('Xem chi tiết đơn',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: k.brand)),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: k.brand),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentRequest(KPalette k, LeaveRequestEntity item) {
    final name = item.childName ?? 'Học sinh';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList()
        .reversed
        .take(2)
        .toList()
        .reversed
        .map((part) => String.fromCharCode(part.runes.first))
        .join()
        .toUpperCase();
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: switch (item.status) {
          LeaveStatus.pending => k.warnTint,
          LeaveStatus.approved => k.okTint,
          LeaveStatus.rejected => k.badTint,
          LeaveStatus.cancelled => k.surfaceSunken,
        },
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(requestStatusLabel(item.status),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: switch (item.status) {
                LeaveStatus.pending => k.warnDeep,
                LeaveStatus.approved => k.ok,
                LeaveStatus.rejected => k.bad,
                LeaveStatus.cancelled => k.inkSoft,
              })),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: k.ink)),
        Text('Nghỉ ${DateFormat('dd/MM').format(item.fromDate)}',
            style: TextStyle(fontSize: 12, color: k.inkSoft)),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final avatar = CircleAvatar(
              radius: 21,
              backgroundColor: k.infoTint,
              child: Text(initials,
                  style:
                      TextStyle(fontWeight: FontWeight.w700, color: k.info)));
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(child: identity),
                ]),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: badge),
              ],
            );
          }
          return Row(children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(child: identity),
            badge,
          ]);
        },
      ),
    );
  }
}
