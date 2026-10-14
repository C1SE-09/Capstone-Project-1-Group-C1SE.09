// frontend/lib/features/kindergarten_dashboard/screens/timetable_screens.dart
// =========================================================
// Màn hình Thời khóa biểu (Thời khóa biểu) — GV xem/sửa lịch tuần của lớp.
// Dữ liệu thật từ /api/schedules + /api/time-slots + /api/subjects.
// Thiết kế theo Figma Make (đã audit) + MASTER.md §7.10:
// - Điện thoại: chế độ Ngày/Tuần, DayStrip, hàng lịch có giờ · icon môn · GV · phòng.
// - Màn rộng (>=900): bảng 5–7 cột ngày.
// - Sheets: hành động (Sửa/Xóa), biểu mẫu thêm/sửa, xác nhận xóa (danger).
// - Xung đột: trùng khung giờ trong cùng ngày → cảnh báo mềm, không chặn.

import 'package:adark_frontend/data/repositories/http_schedule_repository.dart';
import 'package:adark_frontend/domain/entities/timetable/class_schedule.dart';
import 'package:adark_frontend/domain/entities/timetable/subject.dart';
import 'package:adark_frontend/domain/entities/timetable/time_slot.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:flutter/material.dart';

const _dayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
const _dayLong = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({
    super.key,
    required this.classId,
    required this.className,
    this.repository,
    this.isReadOnly = false,
  });

  final String classId;
  final String className;
  final ScheduleRepository? repository;
  final bool isReadOnly;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late final ScheduleRepository _repo = widget.repository ?? HttpScheduleRepository();
  late Future<_TimetableData> _future;
  int? _selectedDay;
  bool _weekMode = false;
  bool _conflictsOnly = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TimetableData> _load() async {
    final values = await Future.wait([
      _repo.getClassSchedule(widget.classId),
      _repo.getTimeSlots(),
      _repo.getSubjects(),
    ]);
    return _TimetableData(
      items: values[0] as List<ClassSchedule>,
      slots: values[1] as List<TimeSlot>,
      subjects: values[2] as List<Subject>,
    );
  }

  void _reload([int? targetDay]) => setState(() {
    if (targetDay != null) {
      _selectedDay = targetDay;
    }
    _future = _load();
  });

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.k.canvas,
      appBar: KAppBar(
        title: 'Thời khóa biểu',
        subtitle: widget.className,
        onBack: () => Navigator.pop(context),
      ),
      body: FutureBuilder<_TimetableData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Không tải được thời khóa biểu.', style: TextStyle(color: context.k.inkSoft)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _reload, child: const Text('Thử lại')),
                ],
              ),
            );
          }
          return _buildLoaded(context, snapshot.data!);
        },
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, _TimetableData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final items = data.items.where((i) => i.isActive).toList();
        final conflicts = _conflictMap(items);
        final days = _activeDays(items);
        final todayIndex = DateTime.now().weekday - 1;
        final selected =
            (_selectedDay != null && days.contains(_selectedDay)) ? _selectedDay! : (days.contains(todayIndex) ? todayIndex : days.first);

        if (items.isEmpty) {
          return _emptyState(context, data);
        }
        if (wide) {
          return _buildBoard(context, data, items, conflicts, days, todayIndex);
        }
        return Column(
          children: [
            Expanded(child: _buildPhone(context, data, items, conflicts, days, selected, todayIndex)),
            if (!widget.isReadOnly)
              BottomActionBar(
                child: KButton(
                  label: 'Thêm hoạt động',
                  icon: Icons.add,
                  large: true,
                  onPressed: () => _openEditor(data),
                ),
              ),
          ],
        );
      },
    );
  }

  /* ---------------- Phone (day / week) ---------------- */

  Widget _buildPhone(
    BuildContext context,
    _TimetableData data,
    List<ClassSchedule> items,
    Map<String, ClassSchedule> conflicts,
    List<int> days,
    int selected,
    int todayIndex,
  ) {
    final dayItems = _itemsForDay(items, selected);
    final visible = _conflictsOnly ? dayItems.where((i) => conflicts.containsKey(i.scheduleId)).toList() : dayItems;
    final statuses = _statusesFor(dayItems, selected == todayIndex);
    final isToday = selected == todayIndex;
    final date = _dateOfDay(selected);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Tuần này · ${_weekLabel(days)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.k.inkSoft)),
              ),
              _ViewToggle(
                weekMode: _weekMode,
                onChanged: (value) => setState(() => _weekMode = value),
              ),
            ],
          ),
        ),
        if (conflicts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChipButton(
                label: '${conflicts.length} xung đột',
                warn: true,
                selected: _conflictsOnly,
                onTap: () => setState(() => _conflictsOnly = !_conflictsOnly),
              ),
            ),
          ),
        if (!_weekMode) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _DayStrip(
              days: days,
              selected: selected,
              todayIndex: todayIndex,
              dateOfDay: _dateOfDay,
              hasItems: (d) => _itemsForDay(items, d).isNotEmpty,
              onPick: (d) => setState(() => _selectedDay = d),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              '${_dayLong[selected].toUpperCase()}, ${date.day}/${date.month}${isToday ? ' · HÔM NAY' : ''}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: context.k.inkFaint),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: KCard(
              child: visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          _conflictsOnly && dayItems.isNotEmpty ? 'Không có xung đột' : 'Chưa có hoạt động',
                          style: TextStyle(fontSize: 13, color: context.k.inkFaint),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (var index = 0; index < visible.length; index++) ...[
                          _ScheduleRow(
                            item: visible[index],
                            conflict: conflicts.containsKey(visible[index].scheduleId),
                            status: statuses[visible[index].scheduleId],
                            onTap: () => _openActions(data, visible[index]),
                          ),
                          if (index < visible.length - 1) const Divider(),
                        ],
                      ],
                    ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          for (final d in days) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Text(
                '${_dayLong[d].toUpperCase()}, ${_dateOfDay(d).day}/${_dateOfDay(d).month}${d == todayIndex ? ' · HÔM NAY' : ''}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: context.k.inkFaint),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _dayCard(data, items, conflicts, d),
            ),
          ],
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _dayCard(_TimetableData data, List<ClassSchedule> items, Map<String, ClassSchedule> conflicts, int day) {
    var list = _itemsForDay(items, day);
    if (_conflictsOnly) list = list.where((i) => conflicts.containsKey(i.scheduleId)).toList();
    return KCard(
      child: list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  _conflictsOnly ? 'Không có xung đột' : 'Chưa có hoạt động',
                  style: TextStyle(fontSize: 13, color: context.k.inkFaint),
                ),
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < list.length; index++) ...[
                  _ScheduleRow(
                    item: list[index],
                    compact: true,
                    conflict: conflicts.containsKey(list[index].scheduleId),
                    onTap: () => _openActions(data, list[index]),
                  ),
                  if (index < list.length - 1) const Divider(),
                ],
              ],
            ),
    );
  }

  /* ---------------- Wide board ---------------- */

  Widget _buildBoard(
    BuildContext context,
    _TimetableData data,
    List<ClassSchedule> items,
    Map<String, ClassSchedule> conflicts,
    List<int> days,
    int todayIndex,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      children: [
        Row(
          children: [
            Text('Tuần này · ${_weekLabel(days)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.k.inkSoft)),
            const Spacer(),
            if (conflicts.isNotEmpty) ...[
              FilterChipButton(
                label: '${conflicts.length} xung đột',
                warn: true,
                selected: _conflictsOnly,
                onTap: () => setState(() => _conflictsOnly = !_conflictsOnly),
              ),
              const SizedBox(width: 12),
            ],
            if (!widget.isReadOnly)
              KButton(label: 'Thêm hoạt động', icon: Icons.add, onPressed: () => _openEditor(data)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _DayColumn(
                    day: d,
                    date: _dateOfDay(d),
                    isToday: d == todayIndex,
                    list: _conflictsOnly
                        ? _itemsForDay(items, d).where((i) => conflicts.containsKey(i.scheduleId)).toList()
                        : _itemsForDay(items, d),
                    conflicts: conflicts,
                    onTapItem: (item) => _openActions(data, item),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /* ---------------- Actions / editor / delete ---------------- */

  void _openActions(_TimetableData data, ClassSchedule item) {
    showKSheet(
      context,
      Builder(
        builder: (sheetCtx) {
          final color = _hexColor(item.subject?.colorCode) ?? sheetCtx.k.brand;
          final meta = [
            _dayShort[item.dayIndex],
            if (item.startTime.isNotEmpty) '${item.startTime}–${item.endTime}',
            if (item.teacherLabel.isNotEmpty) item.teacherLabel,
          ].join(' · ');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(_iconForSubject(item.subject?.name), size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.displayName, style: Theme.of(sheetCtx).textTheme.titleMedium),
                        Text(meta, style: TextStyle(fontSize: 12, color: sheetCtx.k.inkFaint)),
                      ],
                    ),
                  ),
                ],
              ),
              if (item.roomLabel.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 14, color: sheetCtx.k.inkFaint),
                    const SizedBox(width: 4),
                    Text('Phòng: ${item.roomLabel}', style: TextStyle(fontSize: 13, color: sheetCtx.k.inkSoft)),
                  ],
                ),
              ],
              if (item.content?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Text(item.content!.trim(), style: TextStyle(fontSize: 13, color: sheetCtx.k.inkSoft)),
              ],
              // Phụ huynh chỉ được xem: không hiện "Chỉnh sửa" và "Xóa".
              if (widget.isReadOnly) ...[
                const SizedBox(height: 16),
                KButton(
                  label: 'Đóng',
                  secondary: true,
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ] else ...[
                const SizedBox(height: 16),
                KButton(
                  label: 'Chỉnh sửa',
                  secondary: true,
                  icon: Icons.edit_outlined,
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _openEditor(data, item);
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _confirmDelete(item);
                  },
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  icon: Icon(Icons.delete_outline, size: 18, color: sheetCtx.k.bad),
                  label: Text('Xóa', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sheetCtx.k.bad)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(ClassSchedule item) {
    if (widget.isReadOnly) return;
    showKSheet(
      context,
      Builder(
        builder: (sheetCtx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xóa hoạt động này?', style: Theme.of(sheetCtx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Hoạt động lặp lại hằng tuần — sẽ xóa khỏi thời khóa biểu của lớp.',
              style: TextStyle(fontSize: 13, height: 1.5, color: sheetCtx.k.inkSoft),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: KButton(label: 'Hủy', secondary: true, onPressed: () => Navigator.pop(sheetCtx))),
                const SizedBox(width: 12),
                Expanded(
                  child: KButton(
                    label: 'Xóa',
                    danger: true,
                    icon: Icons.delete_outline,
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      await _deleteItem(item);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(ClassSchedule item) async {
    if (widget.isReadOnly) return;
    try {
      await _repo.deleteSchedule(item.scheduleId);
      if (!mounted) return;
      _showMessage('Đã xóa hoạt động');
      _reload(item.dayIndex);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e is ScheduleException ? e.message : 'Không thể xóa hoạt động. Vui lòng thử lại.');
    }
  }

  void _openEditor(_TimetableData data, [ClassSchedule? existing]) {
    // Chặn phòng thủ: phụ huynh (read-only) không bao giờ mở được editor,
    // kể cả nếu sau này có thêm lối vào mới quên kiểm tra cờ.
    if (widget.isReadOnly) return;
    showKSheet(
      context,
      _ScheduleEditorSheet(
        data: data,
        existing: existing,
        classId: widget.classId,
        repository: _repo,
        onSaved: (message, savedDay) {
          Navigator.pop(context);
          _showMessage(message);
          _reload(savedDay);
        },
      ),
    );
  }

  /* ---------------- States ---------------- */

  Widget _emptyState(BuildContext context, _TimetableData data) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: context.k.surfaceSunken, shape: BoxShape.circle),
                child: Icon(Icons.calendar_month_outlined, size: 26, color: context.k.inkFaint),
              ),
              const SizedBox(height: 16),
              const Text('Tuần này chưa có hoạt động nào.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                widget.isReadOnly ? 'Lớp chưa có hoạt động nào trong tuần.' : 'Thêm hoạt động để lên lịch cho cả lớp.',
                style: TextStyle(fontSize: 13, color: context.k.inkSoft),
              ),
              if (!widget.isReadOnly) ...[
                const SizedBox(height: 20),
                KButton(label: 'Thêm hoạt động', icon: Icons.add, onPressed: () => _openEditor(data)),
              ],
            ],
          ),
        ),
      );

  /* ---------------- Helpers ---------------- */

  List<ClassSchedule> _itemsForDay(List<ClassSchedule> items, int day) {
    final list = items.where((i) => i.dayIndex == day).toList();
    list.sort((a, b) {
      final am = _toMin(a.startTime), bm = _toMin(b.startTime);
      if (am != null && bm != null && am != bm) return am.compareTo(bm);
      return (a.timeSlot?.orderIndex ?? 0).compareTo(b.timeSlot?.orderIndex ?? 0);
    });
    return list;
  }

  List<int> _activeDays(List<ClassSchedule> items) {
    final set = <int>{0, 1, 2, 3, 4};
    for (final item in items) {
      if (item.dayIndex >= 0 && item.dayIndex <= 5) set.add(item.dayIndex);
    }
    return set.toList()..sort();
  }

  Map<String, ClassSchedule> _conflictMap(List<ClassSchedule> items) {
    final byKey = <String, List<ClassSchedule>>{};
    for (final item in items) {
      byKey.putIfAbsent('${item.dayIndex}:${item.slotId}', () => []).add(item);
    }
    final map = <String, ClassSchedule>{};
    for (final group in byKey.values) {
      if (group.length > 1) {
        for (final a in group) {
          final other = group.firstWhere((b) => b.scheduleId != a.scheduleId, orElse: () => a);
          map[a.scheduleId] = other;
        }
      }
    }
    return map;
  }

  Map<String, String> _statusesFor(List<ClassSchedule> dayItems, bool isToday) {
    if (!isToday) return const {};
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final map = <String, String>{};
    ClassSchedule? next;
    for (final item in dayItems) {
      final start = _toMin(item.startTime);
      final end = _toMin(item.endTime);
      if (start == null || end == null) continue;
      if (start <= nowMinutes && nowMinutes < end) {
        map[item.scheduleId] = 'Đang diễn ra';
      } else if (start > nowMinutes && next == null) {
        next = item;
      }
    }
    if (next != null && !map.containsKey(next.scheduleId)) {
      map[next.scheduleId] = 'Tiếp theo';
    }
    return map;
  }

  DateTime _mondayOfWeek() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  }

  DateTime _dateOfDay(int day) => _mondayOfWeek().add(Duration(days: day));

  String _weekLabel(List<int> days) {
    final monday = _mondayOfWeek();
    final last = _dateOfDay(days.last);
    return monday.month == last.month
        ? '${monday.day}–${last.day}/${last.month}/${last.year}'
        : '${monday.day}/${monday.month}–${last.day}/${last.month}/${last.year}';
  }
}

/* ======================= Widgets ======================= */

class _TimetableData {
  const _TimetableData({required this.items, required this.slots, required this.subjects});
  final List<ClassSchedule> items;
  final List<TimeSlot> slots;
  final List<Subject> subjects;
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.weekMode, required this.onChanged});
  final bool weekMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: context.k.surfaceSunken, borderRadius: BorderRadius.circular(KRadii.control)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option(context, label: 'Ngày', selected: !weekMode, onTap: () => onChanged(false)),
          _option(context, label: 'Tuần', selected: weekMode, onTap: () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, {required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.k.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 2, offset: const Offset(0, 1))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? context.k.brand : context.k.inkSoft),
        ),
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.selected,
    required this.todayIndex,
    required this.dateOfDay,
    required this.hasItems,
    required this.onPick,
  });

  final List<int> days;
  final int selected;
  final int todayIndex;
  final DateTime Function(int) dateOfDay;
  final bool Function(int) hasItems;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => onPick(d),
                borderRadius: BorderRadius.circular(KRadii.control),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: d == selected ? context.k.brand : context.k.surface,
                    borderRadius: BorderRadius.circular(KRadii.control),
                    border: Border.all(color: d == selected ? context.k.brand : (d == todayIndex ? context.k.brand : context.k.line)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _dayShort[d],
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: d == selected ? Colors.white : context.k.inkFaint),
                      ),
                      Text(
                        '${dateOfDay(d).day}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: d == selected ? Colors.white : context.k.ink),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasItems(d) ? (d == selected ? Colors.white : context.k.brand) : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.date,
    required this.isToday,
    required this.list,
    required this.conflicts,
    required this.onTapItem,
  });

  final int day;
  final DateTime date;
  final bool isToday;
  final List<ClassSchedule> list;
  final Map<String, ClassSchedule> conflicts;
  final ValueChanged<ClassSchedule> onTapItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.k.surface,
        borderRadius: BorderRadius.circular(KRadii.card),
        border: Border.all(color: context.k.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: isToday ? context.k.brandTint : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_dayShort[day]} · ${date.day}/${date.month}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isToday ? context.k.brand : context.k.inkSoft),
                ),
                if (isToday) Text('Hôm nay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.k.brand)),
              ],
            ),
          ),
          const Divider(),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Chưa có hoạt động', style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
              ),
            )
          else
            for (var index = 0; index < list.length; index++) ...[
              _ScheduleRow(
                item: list[index],
                compact: true,
                conflict: conflicts.containsKey(list[index].scheduleId),
                onTap: () => onTapItem(list[index]),
              ),
              if (index < list.length - 1) const Divider(),
            ],
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item, required this.onTap, this.conflict = false, this.status, this.compact = false});

  final ClassSchedule item;
  final VoidCallback onTap;
  final bool conflict;
  final String? status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(item.subject?.colorCode) ?? context.k.brand;
    final name = item.displayName;
    final teacher = item.teacherLabel;
    final room = item.roomLabel;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
              ),
            ),
            if (conflict) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.warning_amber_rounded, size: 14, color: context.k.warn),
              ),
            ],
          ],
        ),
        if (teacher.isNotEmpty)
          Text(teacher, style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
        if (room.isNotEmpty)
          Row(
            children: [
              Icon(Icons.place_outlined, size: 12, color: context.k.inkFaint),
              const SizedBox(width: 3),
              Flexible(child: Text(room, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.k.inkFaint))),
            ],
          ),
        if (status != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: status == 'Đang diễn ra' ? context.k.okTint : context.k.infoTint,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              status!,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status == 'Đang diễn ra' ? context.k.ok : context.k.info),
            ),
          ),
      ],
    );

    final icon = Container(
      width: compact ? 28 : 32,
      height: compact ? 28 : 32,
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
      child: Icon(_iconForSubject(item.subject?.name), size: compact ? 15 : 17, color: color),
    );

    final time = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.startTime, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.k.ink)),
        if (item.endTime.isNotEmpty) Text(item.endTime, style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
      ],
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      icon,
                      const SizedBox(width: 8),
                      Text(
                        item.endTime.isNotEmpty ? '${item.startTime}–${item.endTime}' : item.startTime,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.k.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  body,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 46, child: time),
                  icon,
                  const SizedBox(width: 10),
                  Expanded(child: body),
                ],
              ),
      ),
    );
  }
}


class _ScheduleEditorSheet extends StatefulWidget {
  const _ScheduleEditorSheet({
    required this.data,
    required this.classId,
    required this.repository,
    required this.onSaved,
    this.existing,
  });

  final _TimetableData data;
  final String classId;
  final ScheduleRepository repository;
  final void Function(String message, int savedDay) onSaved;
  final ClassSchedule? existing;

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _roomController;
  late final ScrollController _subjectScrollController = ScrollController();
  late final ScrollController _slotScrollController = ScrollController();
  Subject? _subject;
  TimeSlot? _slot;
  late int _day;
  bool _saving = false;
  String? _error;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.activityName ?? '');
    _roomController = TextEditingController(text: existing?.roomName ?? '');
    _subject = existing != null
        ? _firstWhereOrNull(widget.data.subjects, (s) => s.subjectId == existing.subjectId) ?? existing.subject
        : (widget.data.subjects.length == 1 ? widget.data.subjects.first : null);
    _slot = existing != null
        ? _firstWhereOrNull(widget.data.slots, (s) => s.slotId == existing.slotId) ?? existing.timeSlot
        : (widget.data.slots.length == 1 ? widget.data.slots.first : null);
    final days = _editorDays();
    final todayIndex = DateTime.now().weekday - 1;
    _day = existing?.dayIndex ?? (days.contains(todayIndex) ? todayIndex : days.first);
    if (_day < 0 || _day > 5) _day = days.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _subjectScrollController.dispose();
    _slotScrollController.dispose();
    super.dispose();
  }

  List<int> _editorDays() {
    final set = <int>{0, 1, 2, 3, 4};
    for (final item in widget.data.items) {
      if (item.dayIndex >= 0 && item.dayIndex <= 5) set.add(item.dayIndex);
    }
    return set.toList()..sort();
  }

  T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Vui lòng nhập tên hoạt động.' : null;
      _error = null;
    });
    if (_nameError != null) return;
    if (_subject == null) {
      setState(() => _error = 'Vui lòng chọn môn / hoạt động.');
      return;
    }
    if (_slot == null) {
      setState(() => _error = 'Vui lòng chọn khung giờ.');
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.repository.createSchedule(
          classId: widget.classId,
          subjectId: _subject!.subjectId,
          slotId: _slot!.slotId,
          dayOfWeek: _day + 2,
          activityName: name,
          roomName: _roomController.text,
        );
        widget.onSaved('Đã thêm hoạt động', _day);
      } else {
        await widget.repository.updateSchedule(
          existing.scheduleId,
          subjectId: _subject!.subjectId,
          slotId: _slot!.slotId,
          dayOfWeek: _day + 2,
          activityName: name,
          roomName: _roomController.text,
        );
        widget.onSaved('Đã cập nhật hoạt động', _day);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ScheduleException ? e.message : 'Không thể lưu hoạt động. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final clashes = _slot == null
        ? const <ClassSchedule>[]
        : widget.data.items
            .where((i) => i.scheduleId != widget.existing?.scheduleId && i.dayIndex == _day && i.slotId == _slot!.slotId)
            .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? 'Thêm hoạt động' : 'Chỉnh sửa hoạt động', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _fieldLabel(context, 'Hoạt động'),
          TextField(
            controller: _nameController,
            decoration: _inputDecoration(context, hint: 'VD: Vẽ sáng tạo'),
          ),
          if (_nameError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_nameError!, style: TextStyle(fontSize: 12, color: context.k.bad)),
            ),
          const SizedBox(height: 14),
          _fieldLabel(context, 'Môn / Hoạt động'),
          _buildSubjectScrollSelector(context),
          const SizedBox(height: 14),
          _fieldLabel(context, 'Khung giờ'),
          _buildSlotScrollSelector(context),
          const SizedBox(height: 14),
          _fieldLabel(context, 'Thứ'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _editorDays())
                FilterChipButton(
                  label: _dayShort[d],
                  selected: _day == d,
                  onTap: () => setState(() => _day = d),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel(context, 'Phòng (không bắt buộc)'),
          TextField(
            controller: _roomController,
            decoration: _inputDecoration(context, hint: 'VD: Phòng tạo hình'),
          ),
          if (clashes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: context.k.warnTint, borderRadius: BorderRadius.circular(KRadii.control)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 15, color: context.k.warnDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Khung giờ này đã có "${clashes.first.displayName}" trong ngày ${_dayShort[_day]}.',
                      style: TextStyle(fontSize: 12, height: 1.4, color: context.k.warnDeep),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(fontSize: 13, color: context.k.bad)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: KButton(label: 'Hủy', secondary: true, onPressed: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                child: KButton(
                  label: _saving ? 'Đang lưu…' : 'Lưu hoạt động',
                  icon: Icons.check,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectScrollSelector(BuildContext context) {
    final subjects = widget.data.subjects;
    if (subjects.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.k.surfaceSunken,
          borderRadius: BorderRadius.circular(KRadii.control),
          border: Border.all(color: context.k.line),
        ),
        child: Text('Chưa có môn học nào. Vui lòng tạo môn học trước.',
            style: TextStyle(fontSize: 12.5, color: context.k.inkSoft)),
      );
    }

    return Scrollbar(
      controller: _subjectScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _subjectScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            for (final s in subjects) ...[
              Builder(builder: (itemCtx) {
                final isSelected = _subject?.subjectId == s.subjectId;
                final color = _hexColor(s.colorCode) ?? itemCtx.k.brand;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() {
                      _subject = s;
                      _error = null;
                    }),
                    borderRadius: BorderRadius.circular(KRadii.control),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected ? context.k.brandTint : context.k.surface,
                        borderRadius: BorderRadius.circular(KRadii.control),
                        border: Border.all(
                          color: isSelected ? context.k.brand : context.k.lineStrong,
                          width: isSelected ? 1.6 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: context.k.brand.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_iconForSubject(s.name), size: 14, color: color),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? context.k.brand : context.k.ink,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle_rounded, size: 15, color: context.k.brand),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlotScrollSelector(BuildContext context) {
    final slots = widget.data.slots;
    if (slots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.k.surfaceSunken,
          borderRadius: BorderRadius.circular(KRadii.control),
          border: Border.all(color: context.k.line),
        ),
        child: Text('Chưa có khung giờ nào. Vui lòng tạo khung giờ trước.',
            style: TextStyle(fontSize: 12.5, color: context.k.inkSoft)),
      );
    }

    return Scrollbar(
      controller: _slotScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: _slotScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            for (final slot in slots) ...[
              Builder(builder: (itemCtx) {
                final isSelected = _slot?.slotId == slot.slotId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() {
                      _slot = slot;
                      _error = null;
                    }),
                    borderRadius: BorderRadius.circular(KRadii.control),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? context.k.brandTint : context.k.surface,
                        borderRadius: BorderRadius.circular(KRadii.control),
                        border: Border.all(
                          color: isSelected ? context.k.brand : context.k.lineStrong,
                          width: isSelected ? 1.6 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: context.k.brand.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 13,
                                  color: isSelected ? context.k.brand : context.k.inkSoft),
                              const SizedBox(width: 4),
                              Text(
                                slot.name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? context.k.brand : context.k.ink,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.check_circle_rounded, size: 14, color: context.k.brand),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${slot.startTime} – ${slot.endTime}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? context.k.brand : context.k.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.k.ink)),
      );

  InputDecoration _inputDecoration(BuildContext context, {required String hint}) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: context.k.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KRadii.control),
          borderSide: BorderSide(color: context.k.lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KRadii.control),
          borderSide: BorderSide(color: context.k.lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KRadii.control),
          borderSide: BorderSide(color: context.k.brand, width: 1.5),
        ),
      );
}

/* ======================= Helpers ======================= */

String? _hexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final value = hex.replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

IconData _iconForSubject(String? subject) {
  switch (subject) {
    case 'Toán':
      return Icons.calculate_outlined;
    case 'Văn':
      return Icons.menu_book_outlined;
    case 'Ngoại ngữ':
      return Icons.language_outlined;
    case 'Âm nhạc':
      return Icons.music_note_outlined;
    case 'Mỹ thuật':
      return Icons.palette_outlined;
    case 'Thể dục':
      return Icons.sports_soccer_outlined;
    default:
      return Icons.event_outlined;
  }
}

int? _toMin(String time) {
  final parts = time.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}
