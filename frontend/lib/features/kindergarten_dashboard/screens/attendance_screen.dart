import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_attendance_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/leave_request_review_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    required this.classId,
    required this.className,
    required this.date,
    required this.roster,
    this.repository,
    this.initialRecords,
    this.initialDetails,
    super.key,
  });

  final String classId;
  final String className;
  final String date;
  final List<Child> roster;
  final HttpAttendanceRepository? repository;
  final Map<String, AttendanceStatus>? initialRecords;
  final Map<String, AttendanceChildRecord>? initialDetails;

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
              (child.present ? AttendanceStatus.arrived : AttendanceStatus.absent),
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
        DateTime.tryParse(widget.date) ?? DateTime.now(),
      );
      if (details.isNotEmpty && mounted) {
        setState(() {
          _details = details;
          _saved = {
            for (final child in widget.roster)
              child.id: details[child.id]?.status ??
                  (child.present ? AttendanceStatus.arrived : AttendanceStatus.absent),
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

  AttendanceStatus _next(AttendanceStatus status) => switch (status) {
        AttendanceStatus.arrived => AttendanceStatus.absent,
        AttendanceStatus.absent => AttendanceStatus.excusedAbsent,
        AttendanceStatus.excusedAbsent => AttendanceStatus.late,
        AttendanceStatus.late => AttendanceStatus.arrived,
      };

  void _changeStatus(Child child) {
    if (_saving) return;
    setState(() {
      final current = _draft[child.id] ?? AttendanceStatus.arrived;
      _draft[child.id] = _next(current);
    });
  }

  void _setStatus(Child child, AttendanceStatus newStatus) {
    if (_saving) return;
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
        date: DateTime.tryParse(widget.date) ?? DateTime.now(),
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
        ..showSnackBar(const SnackBar(content: Text('Đã lưu điểm danh thành công')));
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
      ),
    );
    if (shouldSend != true || !mounted) return;

    try {
      final sentCount = await _repository.notifyAbsentParents(
        classId: widget.classId,
        date: DateTime.tryParse(widget.date) ?? DateTime.now(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final largeText = media.textScaler.scale(14) >= 24;
    final summaryHeight = largeText ? 144.0 : 88.0;

    return PopScope(
      canPop: _allowPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _saving ? null : _back,
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Điểm danh',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text(
                '${widget.className} · ${widget.date}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Duyệt đơn xin nghỉ',
              icon: const Icon(Icons.assignment_turned_in_outlined),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LeaveRequestReviewScreen(
                      classId: widget.classId,
                      className: widget.className,
                    ),
                  ),
                );
                // Sau khi quay lại, tự động refresh bảng điểm danh
                _fetchLatest();
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(summaryHeight),
            child: _AttendanceSummary(
              height: summaryHeight,
              total: widget.roster.length,
              arrived: _arrivedCount,
              absent: _absentCount,
              excusedAbsent: _excusedAbsentCount,
              late: _lateCount,
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchLatest,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Chọn trạng thái từ dropdown để cập nhật',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SavedIndicator(dirty: _dirty),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên bé…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _query = ''),
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                      onChanged: (val) => setState(() => _query = val),
                    ),
                    const SizedBox(height: 14),
                    if (_filteredRoster.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Không tìm thấy học sinh phù hợp.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.6),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (int i = 0; i < _filteredRoster.length; i++) ...[
                              _AttendanceRow(
                                student: _filteredRoster[i],
                                status: _draft[_filteredRoster[i].id] ??
                                    AttendanceStatus.arrived,
                                detail: _details[_filteredRoster[i].id],
                                enabled: !_saving,
                                onTapRow: () => _changeStatus(_filteredRoster[i]),
                                onChanged: (newStatus) =>
                                    _setStatus(_filteredRoster[i], newStatus),
                              ),
                              if (i < _filteredRoster.length - 1)
                                Divider(
                                  height: 1,
                                  indent: 68,
                                  color: theme.dividerColor.withValues(alpha: 0.5),
                                ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: FilledButton.icon(
                        onPressed: _dirty && !_saving ? _save : null,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _saving ? 'Đang lưu...' : 'Lưu điểm danh',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: OutlinedButton.icon(
                        onPressed: _absentCount > 0 && !_saving
                            ? _showAbsentNotifications
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _attendanceWarningText(context),
                          backgroundColor: theme.brightness == Brightness.dark
                              ? const Color(0xFF3A2F1A)
                              : KColors.warnTint,
                          side: BorderSide(
                            color: _absentCount > 0
                                ? KColors.warn
                                : theme.disabledColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.notifications_none),
                        label: const Text('Gửi thông báo bé vắng'),
                      ),
                    ),
                  ),
                  if (_absentCount == 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Không có bé vắng',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary({
    required this.height,
    required this.total,
    required this.arrived,
    required this.absent,
    required this.excusedAbsent,
    required this.late,
  });

  final double height;
  final int total;
  final int arrived;
  final int absent;
  final int excusedAbsent;
  final int late;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: divider)),
      ),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(child: _Counter(value: total, label: 'Tổng')),
            VerticalDivider(width: 1, color: divider),
            Expanded(
              child: _Counter(
                value: arrived,
                label: 'Đến',
                helper: late > 0 ? '$late bé trễ' : null,
              ),
            ),
            VerticalDivider(width: 1, color: divider),
            Expanded(child: _Counter(value: excusedAbsent, label: 'Có Phép')),
            VerticalDivider(width: 1, color: divider),
            Expanded(child: _Counter(value: absent, label: 'Vắng')),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.label, this.helper});

  final int value;
  final String label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value${helper == null ? '' : '. $helper'}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            if (helper != null)
              Text(
                helper!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: _attendanceWarningText(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SavedIndicator extends StatelessWidget {
  const _SavedIndicator({required this.dirty});

  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final color = dirty
        ? _attendanceWarningText(context)
        : _attendanceSuccessText(context);
    final background = dirty
        ? (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3A2F1A)
            : KColors.warnTint)
        : (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E3328)
            : KColors.okTint);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(dirty ? Icons.circle : Icons.check, size: dirty ? 7 : 15, color: color),
            const SizedBox(width: 5),
            Text(
              dirty ? 'Có thay đổi chưa lưu' : 'Đã lưu',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.student,
    required this.status,
    required this.enabled,
    required this.onChanged,
    required this.onTapRow,
    this.detail,
  });

  final Child student;
  final AttendanceStatus status;
  final bool enabled;
  final ValueChanged<AttendanceStatus> onChanged;
  final VoidCallback onTapRow;
  final AttendanceChildRecord? detail;

  Widget? _buildBadge(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (status == AttendanceStatus.excusedAbsent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF152A38) : KColors.infoTint,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: (dark ? const Color(0xFF64B5F6) : KColors.info)
                .withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_outlined,
              size: 11,
              color: dark ? const Color(0xFF64B5F6) : KColors.info,
            ),
            const SizedBox(width: 3),
            Text(
              'Excused Absent',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: dark ? const Color(0xFF64B5F6) : KColors.info,
              ),
            ),
          ],
        ),
      );
    }

    if (status == AttendanceStatus.late) {
      String label = 'Late';
      if (detail?.expectedArrivalTime != null &&
          detail!.expectedArrivalTime!.isNotEmpty) {
        final raw = detail!.expectedArrivalTime!;
        final parts = raw.split(':');
        final formattedEta =
            parts.length >= 2 ? '${parts[0]}:${parts[1]}' : raw;
        label = 'Late (ETA: $formattedEta)';
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF3A2F1A) : KColors.warnTint,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _attendanceWarningText(context).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 11,
              color: _attendanceWarningText(context),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _attendanceWarningText(context),
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _statusVisual(context, status);

    return InkWell(
      onTap: enabled ? onTapRow : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Text(
                _initials(student.name),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          student.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_buildBadge(context) != null) ...[
                        const SizedBox(width: 6),
                        _buildBadge(context)!,
                      ],
                    ],
                  ),
                  if (student.nickname != null &&
                      student.nickname!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Tên gọi: ${student.nickname}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (student.allergy != null &&
                      student.allergy!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.monitor_heart_outlined,
                            size: 13,
                            color: KColors.warn,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Lưu ý: ${student.allergy}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: KColors.warn,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: visual.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: visual.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AttendanceStatus>(
                  value: status,
                  isDense: true,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: visual.foreground,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: theme.colorScheme.surface,
                  onChanged: enabled
                      ? (newVal) {
                          if (newVal != null) {
                            onChanged(newVal);
                          }
                        }
                      : null,
                  selectedItemBuilder: (context) => [
                    _buildSelectedItem(context, AttendanceStatus.arrived),
                    _buildSelectedItem(context, AttendanceStatus.absent),
                    _buildSelectedItem(context, AttendanceStatus.excusedAbsent),
                    _buildSelectedItem(context, AttendanceStatus.late),
                  ],
                  items: [
                    DropdownMenuItem(
                      value: AttendanceStatus.arrived,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: _attendanceSuccessText(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Đến',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _attendanceSuccessText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: AttendanceStatus.absent,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_busy_outlined,
                            size: 16,
                            color: _attendanceDangerText(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Vắng',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _attendanceDangerText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: AttendanceStatus.excusedAbsent,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 16,
                            color: _attendanceInfoText(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Có Phép',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _attendanceInfoText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: AttendanceStatus.late,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_outlined,
                            size: 16,
                            color: _attendanceWarningText(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Đến Trễ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _attendanceWarningText(context),
                            ),
                          ),
                        ],
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

  Widget _buildSelectedItem(BuildContext context, AttendanceStatus itemStatus) {
    final v = _statusVisual(context, itemStatus);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(v.icon, size: 15, color: v.foreground),
        const SizedBox(width: 6),
        Text(
          v.label,
          style: TextStyle(
            color: v.foreground,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AbsentNotificationSheet extends StatelessWidget {
  const _AbsentNotificationSheet({
    required this.students,
    required this.unsaved,
  });

  final List<Child> students;
  final bool unsaved;

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
            Text('Gửi thông báo đẩy đến phụ huynh của ${students.length} bé vắng hôm nay.'),
            if (unsaved) ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF3A2F1A)
                      : KColors.warnTint,
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
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    AttendanceStatus.arrived => (
        label: 'Đến',
        icon: Icons.check_circle_outline,
        foreground: _attendanceSuccessText(context),
        background: dark ? const Color(0xFF1E3328) : KColors.okTint,
        border: KColors.ok.withAlpha(100),
      ),
    AttendanceStatus.absent => (
        label: 'Vắng',
        icon: Icons.event_busy_outlined,
        foreground: _attendanceDangerText(context),
        background: dark ? const Color(0xFF3A2621) : KColors.badTint,
        border: KColors.bad.withAlpha(100),
      ),
    AttendanceStatus.excusedAbsent => (
        label: 'Có Phép',
        icon: Icons.event_available_outlined,
        foreground: _attendanceInfoText(context),
        background: dark ? const Color(0xFF152A38) : KColors.infoTint,
        border: KColors.info.withAlpha(100),
      ),
    AttendanceStatus.late => (
        label: 'Đến Trễ',
        icon: Icons.schedule_outlined,
        foreground: _attendanceWarningText(context),
        background: dark ? const Color(0xFF3A2F1A) : KColors.warnTint,
        border: KColors.warn.withAlpha(110),
      ),
  };
}

Color _attendanceInfoText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF64B5F6)
        : const Color(0xFF1976D2);

Color _attendanceSuccessText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF6FCF8E)
        : const Color(0xFF2D7048);

Color _attendanceDangerText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE87B63)
        : const Color(0xFF923624);

Color _attendanceWarningText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF5C878)
        : const Color(0xFF7A510E);

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts[parts.length - 2].characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
