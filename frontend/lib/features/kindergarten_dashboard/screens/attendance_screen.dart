import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart'
    show Avatar;
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_class_header.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    required this.classId,
    required this.className,
    required this.date,
    required this.roster,
    this.teacherName,
    this.notificationCount,
    this.pendingLeaveCount,
    this.repository,
    this.initialRecords,
    this.initialDetails,
    this.onNavigationSelected,
    this.onOpenClassList,
    this.onOpenLeaveRequests,
    this.onOpenNotifications,
    this.onOpenTimetable,
    super.key,
  });

  final String classId;
  final String className;
  final String date;
  final List<Child> roster;
  final String? teacherName;
  final int? notificationCount;
  final int? pendingLeaveCount;
  final HttpAttendanceRepository? repository;
  final Map<String, AttendanceStatus>? initialRecords;
  final Map<String, AttendanceChildRecord>? initialDetails;
  final ValueChanged<GardenVoiceTeacherDestination>? onNavigationSelected;
  final VoidCallback? onOpenClassList;
  final VoidCallback? onOpenLeaveRequests;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenTimetable;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final HttpAttendanceRepository _repository =
      widget.repository ?? HttpAttendanceRepository();

  late Map<String, AttendanceStatus> _saved;
  late Map<String, AttendanceStatus> _draft;
  Map<String, AttendanceChildRecord> _details = {};
  bool _saving = false;
  bool _allowPop = false;
  bool _loading = false;
  String _query = '';
  final FocusNode _searchFocusNode = FocusNode();
  late DateTime _selectedDate;

  List<Child> get _filteredRoster {
    if (_query.trim().isEmpty) return widget.roster;
    final q = _query.trim().toLowerCase();
    return widget.roster.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.nickname?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.tryParse(widget.date) ?? DateTime.now();
    if (widget.initialDetails != null && widget.initialDetails!.isNotEmpty) {
      _details = Map.of(widget.initialDetails!);
    }
    if (widget.initialRecords != null && widget.initialRecords!.isNotEmpty) {
      _saved = Map.of(widget.initialRecords!);
      _draft = Map.of(_saved);
    } else {
      _saved = {
        for (final child in widget.roster)
          child.id: _details[child.id]?.status ??
              (child.present
                  ? AttendanceStatus.arrived
                  : AttendanceStatus.absent),
      };
      _draft = Map.of(_saved);
      _fetchLatest();
    }
  }

  Future<void> _fetchLatest() async {
    setState(() => _loading = true);
    try {
      final details = await _repository.getClassAttendanceDetails(
        widget.classId,
        _selectedDate,
      );
      if (details.isNotEmpty && mounted) {
        setState(() {
          _details = details;
          _saved = {
            for (final child in widget.roster)
              child.id: details[child.id]?.status ??
                  (child.present
                      ? AttendanceStatus.arrived
                      : AttendanceStatus.absent),
          };
          _draft = Map.of(_saved);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  bool get _dirty => widget.roster.any(
        (child) => _draft[child.id] != _saved[child.id],
      );

  int get _absentCount => widget.roster
      .where((child) => _draft[child.id] == AttendanceStatus.absent)
      .length;

  int get _excusedAbsentCount => widget.roster
      .where((child) => _draft[child.id] == AttendanceStatus.excusedAbsent)
      .length;

  int get _lateCount => widget.roster
      .where((child) => _draft[child.id] == AttendanceStatus.late)
      .length;

  int get _arrivedCount =>
      widget.roster.length - _absentCount - _excusedAbsentCount;

  List<Child> get _absentStudents => widget.roster
      .where((child) => _draft[child.id] == AttendanceStatus.absent)
      .toList();

  void _setStatus(Child child, AttendanceStatus newStatus) {
    if (_saving) return;
    final current = _draft[child.id] ?? AttendanceStatus.arrived;
    if (current == AttendanceStatus.excusedAbsent) return;
    setState(() {
      _draft[child.id] = newStatus;
    });
  }

  Future<void> _save() async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);
    try {
      await _repository.saveBatchAttendance(
        classId: widget.classId,
        date: _selectedDate,
        record: _draft,
        expectedArrivalTimes: {
          for (final e in _details.entries)
            if (e.value.expectedArrivalTime != null)
              e.key: e.value.expectedArrivalTime,
        },
        notes: {
          for (final e in _details.entries)
            if (e.value.note != null) e.key: e.value.note,
        },
      );
      if (!mounted) return;
      setState(() {
        _saved = Map.of(_draft);
        _saving = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Đã lưu điểm danh thành công')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu điểm danh. Vui lòng thử lại sau.'),
          ),
        );
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bỏ thay đổi điểm danh?'),
        content: const Text(
          'Các thay đổi trên thẻ điểm danh sẽ không được lưu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tiếp tục điểm danh'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _back() async {
    if (_saving) return;
    if (!await _confirmDiscard() || !mounted) return;
    setState(() {
      _draft = Map.of(_saved);
      _allowPop = true;
    });
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _showAbsentNotifications() async {
    if (_absentStudents.isEmpty || _saving) return;
    final shouldSend = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _AbsentNotificationSheet(
        students: _absentStudents,
        unsaved: _dirty,
        date: _selectedDate,
      ),
    );
    if (shouldSend != true || !mounted) return;

    try {
      final sentCount = await _repository.notifyAbsentParents(
        classId: widget.classId,
        date: _selectedDate,
        childIds: _absentStudents.map((s) => s.id).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Đã gửi thông báo điểm danh tới phụ huynh ($sentCount thiết bị nhận)',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể gửi thông báo lúc này. Vui lòng kiểm tra lại kết nối.',
            ),
          ),
        );
    }
  }

  Future<void> _changeDate(int days) async {
    if (_saving || _loading) return;
    if (_dirty) {
      if (!await _confirmDiscard() || !mounted) return;
      setState(() => _draft = Map.of(_saved));
    }

    final target = _selectedDate.add(Duration(days: days));
    setState(() => _loading = true);
    try {
      final details = await _repository.getClassAttendanceDetails(
        widget.classId,
        target,
      );
      if (!mounted) return;
      if (details.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Không có dữ liệu điểm danh cho ngày này.')),
        );
        return;
      }
      setState(() {
        _selectedDate = target;
        _details = details;
        _saved = {
          for (final child in widget.roster)
            child.id: details[child.id]?.status ??
                (child.present
                    ? AttendanceStatus.arrived
                    : AttendanceStatus.absent),
        };
        _draft = Map.of(_saved);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể tải điểm danh cho ngày đã chọn.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: context.k.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              GardenVoiceClassHeader(
                className: widget.className,
                subtitle: widget.teacherName ?? '',
                selectedTab: GardenVoiceClassTab.attendance,
                notificationCount: widget.notificationCount,
                pendingLeaveCount: widget.pendingLeaveCount,
                onOpenNotifications: widget.onOpenNotifications,
                onTabSelected: (tab) {
                  switch (tab) {
                    case GardenVoiceClassTab.roster:
                      widget.onOpenClassList?.call();
                    case GardenVoiceClassTab.attendance:
                      break;
                    case GardenVoiceClassTab.leaveRequests:
                      widget.onOpenLeaveRequests?.call();
                    case GardenVoiceClassTab.timetable:
                      widget.onOpenTimetable?.call();
                  }
                },
              ),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: context.k.brand,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchLatest,
                        color: context.k.brand,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                          children: [
                            _AttendanceDateLabel(
                              date: _selectedDate,
                              onPrevious: () => _changeDate(-1),
                              onNext: () => _changeDate(1),
                            ),
                            const SizedBox(height: 19),
                            _AttendanceSummary(
                              total: widget.roster.length,
                              arrived: _arrivedCount,
                              absent: _absentCount,
                              excusedAbsent: _excusedAbsentCount,
                              late: _lateCount,
                            ),
                            const SizedBox(height: 16),
                            _buildSearchField(context),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Danh sách điểm danh',
                                    style: TextStyle(
                                      fontSize: 18,
                                      height: 1.35,
                                      fontWeight: FontWeight.w800,
                                      color: context.k.ink,
                                    ),
                                  ),
                                ),
                                _SavedIndicator(
                                  dirty: _dirty,
                                  saving: _saving,
                                  onSave: _dirty && !_saving ? _save : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            _filteredRoster.isEmpty
                                ? _emptyRoster(context)
                                : _attendanceList(context),
                            if (_absentCount > 0) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed:
                                      _saving ? null : _showAbsentNotifications,
                                  icon: const Icon(Icons.notifications_none),
                                  label: const Text('Gửi thông báo bé vắng'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 13),
                            _PendingLeaveTile(
                              count: widget.pendingLeaveCount,
                              onTap: widget.onOpenLeaveRequests,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: GardenVoiceTeacherNavigation(
          selected: GardenVoiceTeacherDestination.classList,
          onSelected: widget.onNavigationSelected ?? (_) {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Widget _buildSearchField(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _searchFocusNode.requestFocus(),
        child: ListenableBuilder(
          listenable: _searchFocusNode,
          builder: (context, _) => Container(
            constraints: const BoxConstraints(minHeight: 39),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: context.k.activityRowTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _searchFocusNode.hasFocus
                    ? context.k.brand
                    : context.k.lineStrong,
                width: _searchFocusNode.hasFocus ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/garden_voice/class_search.svg',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    focusNode: _searchFocusNode,
                    onChanged: (value) => setState(() => _query = value),
                    style: TextStyle(
                        fontSize: 15, height: 1.24, color: context.k.ink),
                    decoration: InputDecoration(
                      hintText: 'Tìm tên bé…',
                      hintStyle:
                          TextStyle(fontSize: 15, color: context.k.inkSoft),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xóa tìm kiếm',
                              onPressed: () => setState(() => _query = ''),
                              icon: const Icon(Icons.clear, size: 18),
                              visualDensity: VisualDensity.compact,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _attendanceList(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.k.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.k.lineStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < _filteredRoster.length; index++) ...[
              SizedBox(
                height: 57,
                child: _AttendanceRow(
                  student: _filteredRoster[index],
                  status: _draft[_filteredRoster[index].id] ??
                      AttendanceStatus.arrived,
                  detail: _details[_filteredRoster[index].id],
                  enabled: !_saving,
                  onChanged: (status) =>
                      _setStatus(_filteredRoster[index], status),
                ),
              ),
              if (index < _filteredRoster.length - 1)
                Divider(height: 0.6, indent: 12, color: context.k.line),
            ],
          ],
        ),
      );

  Widget _emptyRoster(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.k.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.k.lineStrong),
        ),
        child: Center(
          child: Text(
            'Không tìm thấy học sinh phù hợp.',
            style: TextStyle(color: context.k.inkSoft),
          ),
        ),
      );
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({
    required this.total,
    required this.arrived,
    required this.absent,
    required this.excusedAbsent,
    required this.late,
  });

  final int total;
  final int arrived;
  final int absent;
  final int excusedAbsent;
  final int late;

  @override
  Widget build(BuildContext context) {
    final onTime = arrived - late;
    return Semantics(
      label:
          '$arrived/$total bé đã đến lớp. $onTime đúng giờ, $late đến trễ, $absent vắng, $excusedAbsent có phép.',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 67),
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 54),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 35,
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/garden_voice/attendance_users.svg',
                              width: 32,
                              height: 32,
                            ),
                            const SizedBox(width: 11),
                            Flexible(
                              child: Text(
                                '$arrived/$total bé đã đến lớp',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  height: 1.24,
                                  fontWeight: FontWeight.w800,
                                  color: context.k.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _AttendanceCountBadge(
                            label: '$onTime đúng giờ',
                            color: context.k.brand,
                            background: context.k.okTint,
                          ),
                          if (late > 0)
                            _AttendanceCountBadge(
                              label: '$late đến trễ',
                              color: context.k.warnDeep,
                              background: context.k.accentTint,
                            ),
                          _AttendanceCountBadge(
                            label: '$absent vắng',
                            color: absent > 0
                                ? context.k.badText
                                : context.k.brand,
                            background: absent > 0
                                ? context.k.badTint
                                : context.k.okTint,
                          ),
                          if (excusedAbsent > 0)
                            _AttendanceCountBadge(
                              label: '$excusedAbsent có phép',
                              color: context.k.info,
                              background: context.k.infoTint,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 1,
                  width: 47,
                  height: 65,
                  child: IgnorePointer(
                    child: ClipRect(
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned(
                            left: -268.6,
                            top: -32.5,
                            width: 335.7,
                            height: 191.2,
                            child: Image.asset(
                              'assets/garden_voice/plant_detail.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceCountBadge extends StatelessWidget {
  const _AttendanceCountBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            height: 1.24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}

class _AttendanceDateLabel extends StatelessWidget {
  const _AttendanceDateLabel({
    required this.date,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final parsed = date;
    final today = DateTime.now();
    final isToday = parsed.year == today.year &&
        parsed.month == today.month &&
        parsed.day == today.day;
    final weekdays = const [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật',
    ];
    final label = isToday ? 'Hôm nay' : weekdays[parsed.weekday - 1];
    final formatted =
        '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';

    return Container(
      height: 37,
      decoration: BoxDecoration(
        color: context.k.okTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Ngày trước',
            onPressed: onPrevious,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: SvgPicture.asset(
              'assets/garden_voice/attendance_chevron_left.svg',
              width: 23,
              height: 23,
            ),
          ),
          Expanded(
            child: Text(
              '$label · $formatted',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.24,
                fontWeight: FontWeight.w800,
                color: context.k.ink,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Ngày sau',
            onPressed: onNext,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: SvgPicture.asset(
              'assets/garden_voice/attendance_chevron_right.svg',
              width: 23,
              height: 23,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingLeaveTile extends StatelessWidget {
  const _PendingLeaveTile({this.count, this.onTap});

  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: context.k.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 43,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/garden_voice/attendance_calendar.svg',
                    width: 25,
                    height: 25,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      count == null
                          ? 'Xem đơn nghỉ của lớp'
                          : '$count đơn nghỉ đang chờ duyệt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.24,
                        fontWeight: FontWeight.w800,
                        color: context.k.ink,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.k.inkSoft),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SavedIndicator extends StatelessWidget {
  const _SavedIndicator({
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    if (dirty || saving) {
      return TextButton(
        onPressed: onSave,
        style: TextButton.styleFrom(
          foregroundColor: context.k.brand,
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(saving ? 'Đang lưu…' : 'Lưu'),
      );
    }
    return Text(
      'Đã cập nhật',
      style: TextStyle(fontSize: 12, height: 1.4, color: context.k.inkSoft),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.student,
    required this.status,
    required this.enabled,
    required this.onChanged,
    this.detail,
  });

  final Child student;
  final AttendanceStatus status;
  final bool enabled;
  final ValueChanged<AttendanceStatus> onChanged;
  final AttendanceChildRecord? detail;

  @override
  Widget build(BuildContext context) {
    final visual = _statusVisual(context, status);
    final isLocked = status == AttendanceStatus.excusedAbsent;
    final actualTime = detail?.checkInTime?.trim().isNotEmpty == true
        ? detail!.checkInTime!.trim()
        : student.time.trim();
    final expectedTime = detail?.expectedArrivalTime?.trim() ?? '';
    final subtitle = actualTime.isNotEmpty
        ? 'Đến lúc ${_formatAttendanceTime(actualTime)}'
        : expectedTime.isNotEmpty
            ? 'Dự kiến đến ${_formatAttendanceTime(expectedTime)}'
            : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 32, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(name: student.name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.24,
                    fontWeight: FontWeight.w800,
                    color: context.k.ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.24,
                      color: context.k.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 28,
            width: 90,
            decoration: BoxDecoration(
              color: visual.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    context.k.isGardenVoice ? visual.background : visual.border,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AttendanceStatus>(
                value: status,
                isDense: true,
                isExpanded: true,
                icon: const SizedBox.shrink(),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                borderRadius: BorderRadius.circular(14),
                dropdownColor: context.k.surface,
                onChanged: (enabled && !isLocked)
                    ? (newVal) {
                        if (newVal != null) onChanged(newVal);
                      }
                    : null,
                selectedItemBuilder: (context) => [
                  _buildSelectedItem(context, AttendanceStatus.arrived),
                  _buildSelectedItem(context, AttendanceStatus.absent),
                  _buildSelectedItem(context, AttendanceStatus.excusedAbsent),
                  _buildSelectedItem(context, AttendanceStatus.late),
                ],
                items: [
                  _statusOption(context, AttendanceStatus.arrived),
                  _statusOption(context, AttendanceStatus.absent),
                  _statusOption(context, AttendanceStatus.excusedAbsent),
                  _statusOption(context, AttendanceStatus.late),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedItem(BuildContext context, AttendanceStatus itemStatus) {
    final v = _statusVisual(context, itemStatus);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statusIcon(context, itemStatus, 15),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            v.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: v.foreground,
              fontSize: 11,
              height: 1.24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  DropdownMenuItem<AttendanceStatus> _statusOption(
    BuildContext context,
    AttendanceStatus itemStatus,
  ) {
    final visual = _statusVisual(context, itemStatus);
    return DropdownMenuItem(
      value: itemStatus,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusIcon(context, itemStatus, 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              visual.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: visual.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(
    BuildContext context,
    AttendanceStatus itemStatus,
    double size,
  ) {
    if (itemStatus == AttendanceStatus.arrived) {
      return SvgPicture.asset(
        'assets/garden_voice/attendance_check.svg',
        width: size,
        height: size,
      );
    }
    final visual = _statusVisual(context, itemStatus);
    return Icon(visual.icon, size: size, color: visual.foreground);
  }
}

class _AbsentNotificationSheet extends StatelessWidget {
  const _AbsentNotificationSheet({
    required this.students,
    required this.unsaved,
    required this.date,
  });

  final List<Child> students;
  final bool unsaved;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) >= 24;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Gửi thông báo bé vắng?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Gửi thông báo đẩy đến phụ huynh của ${students.length} bé vắng ngày ${_formatAttendanceDate(date)}.',
            ),
            if (unsaved) ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.k.warnTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Điểm danh chưa lưu · Khuyên bạn nên lưu điểm danh trước khi gửi thông báo.',
                    style: TextStyle(
                      color: _attendanceWarningText(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final student in students)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(_initials(student.name))),
                title: Text(student.name),
              ),
            const SizedBox(height: 16),
            if (largeText) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.notifications_none),
                  label: const Text('Gửi thông báo'),
                ),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.notifications_none),
                      label: const Text('Gửi thông báo'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

typedef _StatusVisual = ({
  String label,
  IconData icon,
  Color foreground,
  Color background,
  Color border,
});

_StatusVisual _statusVisual(
  BuildContext context,
  AttendanceStatus status,
) {
  return switch (status) {
    AttendanceStatus.arrived => (
        label: 'Đã đến',
        icon: Icons.check_circle_outline,
        foreground: context.k.brand,
        background: context.k.okTint,
        border: context.k.okDot.withValues(alpha: .4),
      ),
    AttendanceStatus.absent => (
        label: 'Vắng',
        icon: Icons.event_busy_outlined,
        foreground: _attendanceDangerText(context),
        background: context.k.badTint,
        border: context.k.bad.withValues(alpha: .4),
      ),
    AttendanceStatus.excusedAbsent => (
        label: 'Có phép',
        icon: Icons.event_available_outlined,
        foreground: _attendanceInfoText(context),
        background: context.k.infoTint,
        border: context.k.info.withValues(alpha: .4),
      ),
    AttendanceStatus.late => (
        label: 'Đến trễ',
        icon: Icons.schedule_outlined,
        foreground: _attendanceWarningText(context),
        background: context.k.accentTint,
        border: context.k.warnDot.withValues(alpha: .4),
      ),
  };
}

Color _attendanceInfoText(BuildContext context) => context.k.info;

Color _attendanceDangerText(BuildContext context) => context.k.badText;

Color _attendanceWarningText(BuildContext context) => context.k.warnDeep;

String _formatAttendanceDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

String _formatAttendanceTime(String value) {
  final raw = value.contains('T') ? value.split('T').last : value;
  final parts = raw.split(':');
  if (parts.length < 2) return raw;
  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts[parts.length - 2].characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
