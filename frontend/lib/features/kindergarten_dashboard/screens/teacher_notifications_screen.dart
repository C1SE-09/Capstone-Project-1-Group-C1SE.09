import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:adark_frontend/domain/entities/class/class_dashboard_summary.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart'
    as ui;
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/leave_request_review_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';

class TeacherNotificationsScreen extends StatefulWidget {
  const TeacherNotificationsScreen({
    super.key,
    required this.classId,
    this.className,
    this.repository,
    this.medicationRepository,
    this.attendanceRepository,
    this.dashboardRepository,
    this.onNavigationSelected,
    this.onOpenAttendance,
    this.onOpenTimetable,
  });
  final String classId;
  final String? className;
  final HttpLeaveRequestRepository? repository;
  final HttpMedicationRepository? medicationRepository;
  final HttpAttendanceRepository? attendanceRepository;
  final HttpDashboardRepository? dashboardRepository;
  final ValueChanged<GardenVoiceTeacherDestination>? onNavigationSelected;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenTimetable;

  @override
  State<TeacherNotificationsScreen> createState() =>
      _TeacherNotificationsScreenState();
}

class _TeacherNotificationsScreenState
    extends State<TeacherNotificationsScreen> {
  late HttpLeaveRequestRepository _repository;
  late HttpMedicationRepository _medicationRepository;
  late HttpAttendanceRepository _attendanceRepository;
  late HttpDashboardRepository _dashboardRepository;
  final _read = <String>{};
  List<LeaveRequestEntity> _items = [];
  List<MedicationDose> _medications = [];
  List<Map<String, dynamic>> _incidents = [];
  Map<String, AttendanceChildRecord> _attendance = {};
  ClassDashboardSummary? _reports;
  String _filter = 'Tất cả';
  int _pendingOffset = 0, _reviewedOffset = 0, _version = 0;
  bool _loading = false, _hasMore = false, _retryMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? HttpLeaveRequestRepository();
    _medicationRepository =
        widget.medicationRepository ?? HttpMedicationRepository();
    _attendanceRepository =
        widget.attendanceRepository ?? HttpAttendanceRepository();
    _dashboardRepository =
        widget.dashboardRepository ?? HttpDashboardRepository();
    _load();
  }

  @override
  void didUpdateWidget(covariant TeacherNotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId ||
        oldWidget.repository != widget.repository ||
        oldWidget.medicationRepository != widget.medicationRepository ||
        oldWidget.attendanceRepository != widget.attendanceRepository ||
        oldWidget.dashboardRepository != widget.dashboardRepository) {
      _repository = widget.repository ?? HttpLeaveRequestRepository();
      _medicationRepository =
          widget.medicationRepository ?? HttpMedicationRepository();
      _attendanceRepository =
          widget.attendanceRepository ?? HttpAttendanceRepository();
      _dashboardRepository =
          widget.dashboardRepository ?? HttpDashboardRepository();
      _read.clear();
      _items = [];
      _medications = [];
      _incidents = [];
      _attendance = {};
      _reports = null;
      _load();
    }
  }

  bool _unread(_InboxNotice item) => item.unread && !_read.contains(item.key);

  Future<List<MedicationDose>> _loadMedicationsSafe() async {
    try {
      return await _medicationRepository.getClassMedicationRequests(
          classId: widget.classId);
    } on MedicationRequestException catch (e) {
      if (e.code == 'invalid_response' && e.message.contains('lớp')) {
        throw const LeaveRequestException(
            'Không thể xác minh thông báo của lớp.');
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadIncidentsSafe() async {
    try {
      return await _medicationRepository.getHealthIncidents(
          classId: widget.classId);
    } on MedicationRequestException catch (e) {
      if (e.code == 'invalid_response' && e.message.contains('lớp')) {
        throw const LeaveRequestException(
            'Không thể xác minh thông báo của lớp.');
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<ClassDashboardSummary?> _loadDashboardSafe() async {
    try {
      return await _dashboardRepository.getClassDashboard(
          widget.classId, medicationDateInVietnam(DateTime.now()));
    } catch (_) {
      return null;
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && _loading) return;
    final version = ++_version;
    setState(() {
      _loading = true;
      _error = null;
      _retryMore = more;
    });
    try {
      final leaveFuture = Future.wait([
        _repository.getLeaveRequests(
            classId: widget.classId,
            tab: 'pending',
            offset: more ? _pendingOffset : 0),
        _repository.getLeaveRequests(
            classId: widget.classId,
            tab: 'reviewed',
            offset: more ? _reviewedOffset : 0),
      ]);
      final medicationsFuture = more
          ? Future.value(_medications)
          : _loadMedicationsSafe();
      final incidentsFuture =
          more ? Future.value(_incidents) : _loadIncidentsSafe();
      final attendanceFuture = more
          ? Future.value(_attendance)
          : _attendanceRepository.getClassAttendanceDetails(
              widget.classId, medicationDateInVietnam(DateTime.now()));
      final dashboardFuture =
          more ? Future.value(_reports) : _loadDashboardSafe();

      final pages = await leaveFuture;
      final medications = await medicationsFuture;
      final incidents = await incidentsFuture;
      final attendance = await attendanceFuture;
      final reports = await dashboardFuture;

      if (!mounted || version != _version) return;
      final fetched = pages.expand((page) => page.items).toList();
      if (fetched.any((item) => item.classId != widget.classId) ||
          medications.any((item) => item.classId != widget.classId) ||
          incidents.any((item) => item['class_id'] != widget.classId) ||
          (reports != null && reports.classInfo.classId != widget.classId)) {
        throw const LeaveRequestException(
            'Không thể xác minh thông báo của lớp.');
      }
      setState(() {
        _pendingOffset = (more ? _pendingOffset : 0) + pages[0].items.length;
        _reviewedOffset = (more ? _reviewedOffset : 0) + pages[1].items.length;
        _hasMore = (pages[0].items.isNotEmpty &&
                _pendingOffset < pages[0].pendingCount) ||
            (pages[1].items.isNotEmpty &&
                _reviewedOffset < pages[1].reviewedCount);
        _items = {
          for (final item in [
            ...(more ? _items : <LeaveRequestEntity>[]),
            ...fetched
          ])
            item.requestId: item
        }.values.toList()
          ..sort((a, b) => _eventTime(b).compareTo(_eventTime(a)));
        _medications = medications;
        _incidents = incidents;
        _attendance = attendance;
        _reports = reports;
      });
    } catch (e) {
      if (mounted && version == _version) {
        setState(() => _error = e is LeaveRequestException
            ? e.message
            : e is MedicationRequestException
                ? e.message
                : 'Không thể tải thông báo. Vui lòng thử lại.');
      }
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  Future<void> _open(_InboxNotice notice) async {
    final item = notice.request!;
    setState(() => _read.add(notice.key));
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LeaveRequestReviewScreen(
              classId: widget.classId,
              className: widget.className,
              repository: _repository,
              initialRequest: item,
              onNavigationSelected: widget.onNavigationSelected,
              onOpenClassList: widget.onNavigationSelected == null
                  ? null
                  : () => widget.onNavigationSelected!(
                      GardenVoiceTeacherDestination.classList),
              onOpenAttendance: widget.onOpenAttendance == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      widget.onOpenAttendance!();
                    },
              onOpenTimetable: widget.onOpenTimetable == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      widget.onOpenTimetable!();
                    },
            )));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => GardenVoiceScope(
        child: Builder(builder: _buildScreen),
      );

  Widget _buildScreen(BuildContext context) {
    final k = context.k;
    final items = <_InboxNotice>[
      if (_filter == 'Tất cả' || _filter == 'Đơn nghỉ')
        ..._items.map((item) {
          final late = item.requestType == LeaveRequestType.lateArrival;
          final type = late ? 'báo đi trễ' : 'đơn xin nghỉ';
          return _InboxNotice(
              key:
                  '${item.requestId}:${item.status.name}:${_eventTime(item).toIso8601String()}',
              category: late ? 'BÁO TRỄ' : 'ĐƠN NGHỈ',
              time: _eventTime(item),
              title: item.status == LeaveStatus.pending
                  ? '${late ? 'Báo đi trễ' : 'Đơn xin nghỉ'} mới — ${item.childName ?? 'Học sinh'}'
                  : '${requestStatusLabel(item.status)} $type — ${item.childName ?? 'Học sinh'}',
              detail: late
                  ? 'Đi trễ ${DateFormat('dd/MM').format(item.fromDate)} · Dự kiến ${item.expectedArrivalTime?.split(':').take(2).join(':') ?? 'chưa cập nhật'} · ${item.reason}'
                  : 'Nghỉ ${DateFormat('dd/MM').format(item.fromDate)}${item.totalDays > 1 ? ' · ${item.totalDays} ngày' : ''} · ${item.reason}',
              request: item);
        }),
      if (_filter == 'Tất cả' || _filter == 'Thuốc')
        ..._medications.where((item) => item.status != 'cancelled').map(
            (item) => _InboxNotice(
                key: 'medication:${item.id}:${item.status}',
                category: 'THUỐC',
                time: item.createdAt,
                title: 'Đơn thuốc mới — ${item.childName ?? 'Học sinh'}',
                detail: '${item.name ?? 'Thuốc'} · ${item.dosage}',
                isToday: item.requestDate != null &&
                    DateUtils.isSameDay(item.requestDate!, DateTime.now()))),
      if (_filter == 'Tất cả' || _filter == 'Sự cố')
        ..._incidents.map((item) => _InboxNotice(
            key: 'incident:${item['incident_id']}',
            category: 'SỰ CỐ',
            time: DateTime.tryParse(item['reported_at']?.toString() ?? ''),
            title: 'Sự cố sức khỏe — ${item['child_name']}',
            detail: '${item['incident_type_label']} · ${item['description']}')),
      if (_filter == 'Tất cả')
        ..._attendance.values
            .where((item) =>
                item.status == ui.AttendanceStatus.late ||
                item.status == ui.AttendanceStatus.absent ||
                item.status == ui.AttendanceStatus.excusedAbsent)
            .where((item) => item.childName?.isNotEmpty == true)
            .map((item) => _InboxNotice(
                key: 'attendance:${item.childId}:${item.status.name}',
                category: 'ĐIỂM DANH',
                title: 'Điểm danh cập nhật — ${item.childName}',
                detail: item.status == ui.AttendanceStatus.late
                    ? 'Đến trễ${item.expectedArrivalTime == null ? '' : ' · ETA ${item.expectedArrivalTime!.split(':').take(2).join(':')}'}'
                    : item.status == ui.AttendanceStatus.excusedAbsent
                        ? 'Vắng có phép${item.note == null ? '' : ' · ${item.note}'}'
                        : 'Vắng mặt${item.note == null ? '' : ' · ${item.note}'}',
                isToday: true,
                unread: false)),
      if (_filter == 'Tất cả' && (_reports?.totalChildren ?? 0) > 0)
        _InboxNotice(
            key:
                'reports:${_reports!.classInfo.classId}:${DateUtils.dateOnly(DateTime.now())}',
            category: 'BÁO CÁO',
            title:
                'Báo cáo ngày đã gửi ${_reports!.completedCount}/${_reports!.totalChildren}',
            detail: _reports!.missingCount > 0
                ? 'Còn ${_reports!.pendingChildren.where((item) => item.status == null).map((item) => item.child.displayName).join(', ')} chưa có báo cáo'
                : _reports!.draftCount > 0
                    ? 'Còn ${_reports!.draftCount} bản nháp chưa gửi'
                    : 'Đã hoàn tất báo cáo của cả lớp',
            isToday: true,
            unread: false),
    ];
    final groups = <String, List<_InboxNotice>>{
      'Mới': items.where(_unread).toList(),
      'Hôm nay': items
          .where((item) =>
              !_unread(item) &&
              (item.isToday ||
                  (item.time != null &&
                      DateUtils.isSameDay(
                          item.time!.toLocal(), DateTime.now()))))
          .toList(),
      'Trước đó': items
          .where((item) =>
              !_unread(item) &&
              !item.isToday &&
              (item.time == null ||
                  !DateUtils.isSameDay(item.time!.toLocal(), DateTime.now())))
          .toList(),
    };
    final backButton = IconButton(
      key: const ValueKey('teacher-notifications-back'),
      onPressed: () => Navigator.of(context).maybePop(),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: SvgPicture.asset('assets/notifications/back_44.svg'),
    );
    final title = Semantics(
      header: true,
      child: Text('Thông báo',
          style: TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: k.ink)),
    );
    final markRead = TextButton(
      onPressed: items.any(_unread)
          ? () => setState(() => _read.addAll(items.map((item) => item.key)))
          : null,
      style: TextButton.styleFrom(
        foregroundColor: k.brand,
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
      ),
      child: const Text('Đánh dấu đã đọc',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
    );
    return ParentRequestLayout(
        bottomNavigationBar: GardenVoiceTeacherNavigation(
          selected: GardenVoiceTeacherDestination.home,
          onSelected: (destination) {
            if (widget.onNavigationSelected != null) {
              widget.onNavigationSelected!(destination);
            } else if (destination == GardenVoiceTeacherDestination.home) {
              Navigator.of(context).maybePop();
            }
          },
        ),
        child: ColoredBox(
          key: const ValueKey('teacher-notifications-canvas'),
          color: k.canvas,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 320 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1;
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            backButton,
                            const SizedBox(width: 4),
                            Expanded(child: title),
                          ]),
                          Align(
                              alignment: Alignment.centerRight,
                              child: markRead),
                        ],
                      );
                    }
                    return Row(children: [
                      backButton,
                      const SizedBox(width: 4),
                      Expanded(child: title),
                      markRead,
                    ]);
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 7,
                    children: [
                      for (final filter in [
                        'Tất cả',
                        'Đơn nghỉ',
                        'Thuốc',
                        'Sự cố'
                      ])
                        TextButton(
                          onPressed: () => setState(() => _filter = filter),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(44, 36),
                          ),
                          child: Semantics(
                            selected: _filter == filter,
                            child: Container(
                              height: 36,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _filter == filter
                                    ? k.brand
                                    : k.surface,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                    color: _filter == filter
                                        ? k.brand
                                        : k.line),
                              ),
                              child: Text(filter,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: _filter == filter
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: _filter == filter
                                          ? k.surface
                                          : k.inkSoft)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (final group in groups.entries
                    .where((group) => group.value.isNotEmpty)) ...[
                  Padding(
                    padding: EdgeInsets.only(
                        top: group.key == 'Mới' ? 4 : 0, bottom: 12),
                    child: Semantics(
                      header: true,
                      child: Text(group.key,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: k.ink)),
                    ),
                  ),
                  for (var i = 0; i < group.value.length; i++) ...[
                    _RequestNotice(
                        item: group.value[i],
                        unread: _unread(group.value[i]),
                        onTap: group.value[i].request == null
                            ? null
                            : () => _open(group.value[i])),
                    if (i < group.value.length - 1) const SizedBox(height: 12),
                  ],
                ],
                if (_loading)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator())),
                if (_error != null)
                  ParentRequestError(_error!,
                      onRetry: () => _load(more: _retryMore)),
                if (!_loading && _error == null && items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      switch (_filter) {
                        'Thuốc' => 'Chưa có thông báo thuốc.',
                        'Sự cố' => 'Chưa có thông báo sự cố.',
                        _ => 'Chưa có thông báo.'
                      },
                      textAlign: TextAlign.center,
                      style: TextStyle(color: k.inkSoft),
                    ),
                  ),
                if (_hasMore &&
                    !_loading &&
                    _error == null &&
                    (_filter == 'Tất cả' || _filter == 'Đơn nghỉ'))
                  TextButton(
                      onPressed: () => _load(more: true),
                      child: const Text('Tải thêm')),
              ],
            ),
          ),
        ));
  }
}

DateTime _eventTime(LeaveRequestEntity item) =>
    item.reviewedAt ?? item.createdAt;

class _InboxNotice {
  const _InboxNotice({
    required this.key,
    required this.category,
    required this.title,
    required this.detail,
    this.time,
    this.isToday = false,
    this.unread = true,
    this.request,
  });

  final String key, category, title, detail;
  final DateTime? time;
  final bool isToday;
  final bool unread;
  final LeaveRequestEntity? request;
}

class _RequestNotice extends StatelessWidget {
  const _RequestNotice({
    required this.item,
    required this.unread,
    required this.onTap,
  });
  final _InboxNotice item;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (badgeBackground, badgeForeground) = switch (item.category) {
      'THUỐC' => (k.warnTint, k.warnDeep),
      'SỰ CỐ' => (k.surface, k.badText),
      'ĐIỂM DANH' => (k.okTint, k.ok),
      'BÁO CÁO' => (k.surface, k.inkSoft),
      _ => (k.brandTint, k.brand),
    };
    return Semantics(
        button: onTap != null,
        label: unread ? 'Chưa đọc' : 'Đã đọc',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 98),
          child: Material(
            color: k.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: k.line)),
            key: ValueKey(
                'notification-card-${item.request?.requestId ?? item.key}'),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  color: badgeForeground),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.time != null)
                                Text(
                                  DateFormat('HH:mm').format(item.time!
                                      .toUtc()
                                      .add(const Duration(hours: 7))),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: k.inkSoft),
                                ),
                              if (unread) ...[
                                const SizedBox(width: 8),
                                SvgPicture.asset(
                                  'assets/notifications/unread_dot.svg',
                                  key: ValueKey(
                                      'unread-${item.key.split(':').first}'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(item.title,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: k.ink)),
                      Text(item.detail,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: k.inkSoft)),
                    ],
                  ),
                )),
          ),
        ));
  }
}
