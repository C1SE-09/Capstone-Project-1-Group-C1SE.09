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
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_class_header.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_teacher_navigation.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/schedule_editor_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/timetable_models_and_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/widgets/schedule_editor_sheet.dart' show ScheduleEditorSheet;
export 'package:adark_frontend/features/kindergarten_dashboard/widgets/timetable_models_and_helpers.dart' show TimetableData;

const _dayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
const _dayLong = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];

/// Kiểm tra xem một tiết học có khớp với từ khóa tìm kiếm (bao gồm tên tiết, môn học, phòng, giáo viên và KHUNG GIỜ) hay không.
bool matchesTimetableQuery(ClassSchedule item, String query) {
  if (query.trim().isEmpty) return true;
  final q = query.toLowerCase().trim();

  // 1. Thông tin văn bản
  if (item.displayName.toLowerCase().contains(q)) return true;
  if ((item.activityName ?? '').toLowerCase().contains(q)) return true;
  if ((item.content ?? '').toLowerCase().contains(q)) return true;
  if ((item.roomName ?? '').toLowerCase().contains(q)) return true;
  if ((item.teacherName ?? '').toLowerCase().contains(q)) return true;
  if ((item.subject?.name ?? '').toLowerCase().contains(q)) return true;
  if ((item.timeSlot?.name ?? '').toLowerCase().contains(q)) return true;

  // 2. Khung giờ (time slot / range)
  final start = item.startTime.toLowerCase(); // vd "08:00"
  final end = item.endTime.toLowerCase();     // vd "08:45"
  final range = '$start - $end';              // vd "08:00 - 08:45"

  if (start.contains(q) || end.contains(q) || range.contains(q)) return true;

  // Chuẩn hóa định dạng thời gian: "8h" / "8h30" / "8:00" / "08:00"
  final normalizedQ = q.replaceAll('h', ':').replaceAll(' ', '');
  if (start.contains(normalizedQ) || end.contains(normalizedQ) || range.contains(normalizedQ)) {
    return true;
  }

  // Khớp bỏ số 0 ở đầu: "08:00" -> "8:00"
  final startNoZero = start.startsWith('0') ? start.substring(1) : start;
  final endNoZero = end.startsWith('0') ? end.substring(1) : end;
  if (startNoZero.contains(q) || endNoZero.contains(q)) {
    return true;
  }

  // Khớp số giờ (vd: "8" hoặc "14")
  final hourNum = int.tryParse(q.replaceAll(RegExp(r'\D'), ''));
  if (hourNum != null && hourNum >= 6 && hourNum <= 20) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    if (startParts.isNotEmpty && int.tryParse(startParts.first) == hourNum) return true;
    if (endParts.isNotEmpty && int.tryParse(endParts.first) == hourNum) return true;
  }

  return false;
}

/// Lớp học dùng trong bộ chọn thời khóa biểu.
class TimetableClassItem {
  const TimetableClassItem({
    required this.id,
    required this.name,
    this.gradeLabel = '',
  });
  final String id;
  final String name;
  final String gradeLabel;
}

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({
    super.key,
    required this.classId,
    required this.className,
    this.repository,
    this.isReadOnly = false,
    this.embedded = false,
    this.teacherName,
    this.notificationCount,
    this.pendingLeaveCount,
    this.classList,
    this.onClassChanged,
    this.onNavigationSelected,
    this.onOpenClassList,
    this.onOpenAttendance,
    this.onOpenLeaveRequests,
    this.onOpenNotifications,
    this.searchQuery,
  });

  final String classId;
  final String className;
  final ScheduleRepository? repository;
  final bool isReadOnly;
  final bool embedded;
  final String? teacherName;
  final int? notificationCount;
  final int? pendingLeaveCount;
  final List<TimetableClassItem>? classList;
  final ValueChanged<String>? onClassChanged;
  final ValueChanged<GardenVoiceTeacherDestination>? onNavigationSelected;
  final VoidCallback? onOpenClassList;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenLeaveRequests;
  final VoidCallback? onOpenNotifications;
  final String? searchQuery;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late final ScheduleRepository _repo = widget.repository ?? HttpScheduleRepository();
  late Future<_TimetableData> _future;
  late String _currentClassId = widget.classId;
  late String _currentClassName = widget.className;
  final TextEditingController _searchController = TextEditingController();
  String _internalSearchQuery = '';
  int? _selectedDay;
  bool _weekMode = false;
  bool _conflictsOnly = false;

  @override
  void initState() {
    super.initState();
    _currentClassId = widget.classId;
    _currentClassName = widget.className;
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TimetableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId && widget.classId.isNotEmpty) {
      _currentClassId = widget.classId;
      _currentClassName = widget.className;
      _future = _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_TimetableData> _load() async {
    final values = await Future.wait([
      _repo.getClassSchedule(_currentClassId),
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
    final content = FutureBuilder<_TimetableData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
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
    );

    if (widget.embedded) {
      return Material(
        color: context.k.canvas,
        child: Column(
          children: [
            _buildParentSheetHeader(context),
            Expanded(child: content),
          ],
        ),
      );
    }

    if (!context.k.isGardenVoice) {
      return Scaffold(
        backgroundColor: context.k.canvas,
        appBar: KAppBar(
          title: 'Thời khóa biểu',
          subtitle: _currentClassName,
          onBack: () => Navigator.pop(context),
        ),
        body: content,
      );
    }

    return Scaffold(
      backgroundColor: context.k.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GardenVoiceClassHeader(
              className: _currentClassName,
              subtitle: widget.teacherName ?? '',
              selectedTab: GardenVoiceClassTab.timetable,
              notificationCount: widget.notificationCount,
              pendingLeaveCount: widget.pendingLeaveCount,
              onOpenNotifications: widget.onOpenNotifications,
              onTabSelected: _selectClassTab,
            ),
            Expanded(child: content),
          ],
        ),
      ),
      bottomNavigationBar: GardenVoiceTeacherNavigation(
        selected: GardenVoiceTeacherDestination.classList,
        onSelected: widget.onNavigationSelected ?? (_) {},
      ),
    );
  }

  void _selectClassTab(GardenVoiceClassTab tab) {
    switch (tab) {
      case GardenVoiceClassTab.roster:
        widget.onOpenClassList?.call();
      case GardenVoiceClassTab.attendance:
        widget.onOpenAttendance?.call();
      case GardenVoiceClassTab.leaveRequests:
        widget.onOpenLeaveRequests?.call();
      case GardenVoiceClassTab.timetable:
        break;
    }
  }

  Widget _buildParentSheetHeader(BuildContext context) => Column(
        children: [
          const SizedBox(height: 18),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: context.k.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Thời khóa biểu của lớp',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: context.k.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.maybePop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  icon: SvgPicture.asset(
                    'assets/garden_voice/parent_child_close.svg',
                    width: 44,
                    height: 44,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildClassSelectorBar(BuildContext context) {
    final classes = widget.classList!;
    final effectiveSelectedId = classes.any((c) => c.id == _currentClassId)
        ? _currentClassId
        : (classes.isNotEmpty ? classes.first.id : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.k.surfaceSunken,
        borderRadius: BorderRadius.circular(KRadii.control),
        border: Border.all(color: context.k.line),
      ),
      child: Row(
        children: [
          Icon(Icons.meeting_room_outlined, size: 20, color: context.k.brand),
          const SizedBox(width: 8),
          Text(
            'Lớp học:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.k.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: effectiveSelectedId,
                isDense: true,
                isExpanded: true,
                items: classes.map((c) {
                  return DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(
                      '${c.name} (${c.gradeLabel})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newClassId) {
                  if (newClassId != null && newClassId != _currentClassId) {
                    final matched = classes.firstWhere(
                      (c) => c.id == newClassId,
                      orElse: () => classes.first,
                    );
                    setState(() {
                      _currentClassId = newClassId;
                      _currentClassName = matched.name;
                      _future = _load();
                    });
                    widget.onClassChanged?.call(newClassId);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _internalSearchQuery = val.trim()),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Tìm tiết học, môn học, khung giờ (vd: 08:00, 8h)...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _internalSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _internalSearchQuery = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, _TimetableData data) {
    if (widget.embedded) return _buildParentSheetSchedule(context, data);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final effectiveQuery = (widget.searchQuery ?? _internalSearchQuery).trim();
        final allItems = data.items.where((i) => i.isActive).toList();
        final items = effectiveQuery.isEmpty
            ? allItems
            : allItems.where((i) => matchesTimetableQuery(i, effectiveQuery)).toList();
        final conflicts = _conflictMap(items);
        final days = _activeDays(items);
        final todayIndex = DateTime.now().weekday - 1;
        final selected =
            (_selectedDay != null && days.contains(_selectedDay)) ? _selectedDay! : (days.contains(todayIndex) ? todayIndex : (days.isNotEmpty ? days.first : 0));

        Widget mainContent;
        if (allItems.isEmpty) {
          mainContent = context.k.isGardenVoice
              ? _buildPhone(
                  context, data, items, conflicts, days, selected, todayIndex)
              : _emptyState(context, data);
        } else if (items.isEmpty) {
          mainContent = Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: context.k.inkFaint),
                  const SizedBox(height: 12),
                  Text(
                    'Không tìm thấy hoạt động nào phù hợp',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.k.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Thử tìm kiếm với khung giờ khác (vd: 08:00, 8h) hoặc tên môn/phòng.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: context.k.inkSoft),
                  ),
                ],
              ),
            ),
          );
        } else if (wide) {
          mainContent = _buildBoard(context, data, items, conflicts, days, todayIndex);
        } else {
          mainContent = _buildPhone(context, data, items, conflicts, days, selected, todayIndex);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embedded && widget.classList != null && widget.classList!.isNotEmpty)
              _buildClassSelectorBar(context),
            if (widget.searchQuery == null && !context.k.isGardenVoice)
              _buildSearchBar(context),
            Expanded(child: mainContent),
            if (!widget.isReadOnly && !wide)
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

  Widget _buildParentSheetSchedule(
    BuildContext context,
    _TimetableData data,
  ) {
    final items = data.items.where((item) => item.isActive).toList();
    final conflicts = _conflictMap(items);
    final days = _activeDays(items);
    final todayIndex = DateTime.now().weekday - 1;
    final selected = (_selectedDay != null && days.contains(_selectedDay))
        ? _selectedDay!
        : (days.contains(todayIndex) ? todayIndex : (days.isNotEmpty ? days.first : 0));
    final dayItems = _itemsForDay(items, selected);
    final status = _statusesFor(dayItems, selected == todayIndex);
    final visible = _conflictsOnly
        ? dayItems.where((item) => conflicts.containsKey(item.scheduleId)).toList()
        : dayItems;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            spacing: 6,
            children: [
              for (final day in days)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: day == selected,
                    label: _dayLong[day],
                    child: InkWell(
                      onTap: () => setState(() => _selectedDay = day),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: day == selected ? context.k.brand : context.k.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: day == selected
                                ? context.k.brand
                                : context.k.line,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _dayShort[day],
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: day == selected
                                ? context.k.surface
                                : context.k.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
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
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    _conflictsOnly
                        ? 'Không có xung đột'
                        : 'Chưa có hoạt động',
                    style: TextStyle(color: context.k.inkSoft),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 9, 20, 16),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return _ParentScheduleCard(
                      item: item,
                      status: status[item.scheduleId],
                      conflict: conflicts.containsKey(item.scheduleId),
                      onTap: () => _openActions(data, item),
                    );
                  },
                ),
        ),
      ],
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
    final gardenVoice = context.k.isGardenVoice;
    final dayItems = _itemsForDay(items, selected);
    final visible = _conflictsOnly ? dayItems.where((i) => conflicts.containsKey(i.scheduleId)).toList() : dayItems;
    final statuses = _statusesFor(dayItems, selected == todayIndex);
    final isToday = selected == todayIndex;
    final date = _dateOfDay(selected);

    final listWidget = ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, gardenVoice ? 0 : 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tuần này · ${gardenVoice ? _gardenVoiceWeekLabel(days) : _weekLabel(days)}',
                  style: TextStyle(
                    fontSize: gardenVoice ? 16 : 13,
                    height: gardenVoice ? 1.35 : null,
                    fontWeight: gardenVoice ? FontWeight.w700 : FontWeight.w600,
                    color: gardenVoice ? context.k.ink : context.k.inkSoft,
                  ),
                ),
              ),
              if (!gardenVoice)
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
            padding: EdgeInsets.fromLTRB(20, gardenVoice ? 12 : 14, 20, 0),
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
              gardenVoice
                  ? '${_dayLong[selected]}, ngày ${date.day.toString().padLeft(2, '0')} tháng ${date.month.toString().padLeft(2, '0')}'
                  : '${_dayLong[selected].toUpperCase()}, ${date.day}/${date.month}${isToday ? ' · HÔM NAY' : ''}',
              style: TextStyle(
                fontSize: gardenVoice ? 14 : 11,
                height: gardenVoice ? 1.35 : null,
                fontWeight: gardenVoice ? FontWeight.w400 : FontWeight.w600,
                letterSpacing: gardenVoice ? 0 : 0.4,
                color: context.k.inkSoft,
              ),
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
              style: TextStyle(
                fontSize: gardenVoice ? 14 : 11,
                height: gardenVoice ? 1.35 : null,
                fontWeight: gardenVoice ? FontWeight.w400 : FontWeight.w600,
                letterSpacing: gardenVoice ? 0 : 0.4,
                color: context.k.inkSoft,
              ),
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

    if (widget.embedded) return listWidget;
    return RefreshIndicator(
      onRefresh: () async {
        final d = await _load();
        if (mounted) setState(() => _future = Future.value(d));
      },
      child: listWidget,
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
          final Color color = _hexColor(item.subject?.colorCode) ?? sheetCtx.k.brand;
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
                    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
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
      _showMessage(getFriendlyErrorMessage(e, fallback: 'Không thể xóa hoạt động. Vui lòng thử lại.'));
    }
  }

  void _openEditor(_TimetableData data, [ClassSchedule? existing]) {
    // Chặn phòng thủ: phụ huynh (read-only) không bao giờ mở được editor,
    // kể cả nếu sau này có thêm lối vào mới quên kiểm tra cờ.
    if (widget.isReadOnly) return;
    final classOptions = (widget.classList != null && widget.classList!.isNotEmpty)
        ? widget.classList!.map((c) => {'id': c.id, 'name': c.name}).toList()
        : [{'id': _currentClassId, 'name': _currentClassName}];

    showKSheet(
      context,
      _ScheduleEditorSheet(
        data: data,
        existing: existing,
        classId: _currentClassId,
        classes: classOptions,
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
      byKey.putIfAbsent('${item.dayIndex}:${item.timeKey}', () => []).add(item);
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

  String _gardenVoiceWeekLabel(List<int> days) {
    final first = _dateOfDay(days.first);
    final last = _dateOfDay(days.last);
    String label(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    return '${label(first)}–${label(last)}';
  }
}

/* ======================= Widgets ======================= */

typedef _TimetableData = TimetableData;


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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.k.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
    final gardenVoice = context.k.isGardenVoice;
    final largeText = MediaQuery.textScalerOf(context).scale(14) >= 24;
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gardenVoice ? 2 : 3),
              child: InkWell(
                onTap: () => onPick(d),
                borderRadius: BorderRadius.circular(gardenVoice ? 18 : KRadii.control),
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: gardenVoice
                        ? (largeText ? 76 : 60)
                        : 64,
                  ),
                  decoration: BoxDecoration(
                    color: d == selected ? context.k.brand : context.k.surface,
                    borderRadius:
                        BorderRadius.circular(gardenVoice ? 18 : KRadii.control),
                    border: Border.all(color: d == selected ? context.k.brand : (d == todayIndex ? context.k.brand : context.k.line)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _dayShort[d],
                        style: TextStyle(
                          fontSize: gardenVoice ? 12 : 11,
                          fontWeight: gardenVoice ? FontWeight.w500 : FontWeight.w600,
                          color: d == selected
                              ? context.k.surface
                              : context.k.inkSoft,
                        ),
                      ),
                      Text(
                        '${dateOfDay(d).day}',
                        style: TextStyle(
                          fontSize: gardenVoice ? 18 : 16,
                          fontWeight: FontWeight.w700,
                          color: d == selected
                              ? context.k.surface
                              : context.k.ink,
                        ),
                      ),
                      if (!gardenVoice) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasItems(d)
                                ? (d == selected
                                    ? context.k.surface
                                    : context.k.brand)
                                : Colors.transparent,
                          ),
                        ),
                      ],
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
    if (context.k.isGardenVoice) return _buildGardenVoice(context);

    final Color color = _hexColor(item.subject?.colorCode) ?? context.k.brand;
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

  Widget _buildGardenVoice(BuildContext context) {
    final name = item.displayName;
    final teacher = item.teacherLabel;
    final room = item.roomLabel;
    final kind = _scheduleKind(item);
    final detail = (item.content?.trim().isNotEmpty ?? false)
        ? item.content!.trim()
        : [teacher, room].where((part) => part.isNotEmpty).join(' · ');
    final visual = _scheduleVisual(context, kind);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: context.k.ink,
                ),
              ),
            ),
            if (conflict) ...[
              const SizedBox(width: 4),
              Icon(Icons.warning_amber_rounded,
                  size: 14, color: context.k.warn),
            ],
          ],
        ),
        if (detail.isNotEmpty)
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: context.k.inkSoft,
            ),
          ),
        if (status == 'Đang diễn ra') ...[
          const SizedBox(height: 3),
          _ScheduleStatusPill(status: status!),
        ],
      ],
    );
    final icon = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(17),
      ),
      alignment: Alignment.center,
      child: Semantics(
        key: ValueKey('timetable-icon-${item.scheduleId}'),
        image: true,
        label: _scheduleKindLabel(kind),
        child: SvgPicture.asset(
          _teacherScheduleIcon(kind),
          width: 19,
          height: 19,
        ),
      ),
    );
    final row = compact
        ? Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(child: body),
              const SizedBox(width: 8),
              Text(
                item.startTime,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.k.inkSoft,
                ),
              ),
            ],
          )
        : Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  item.startTime,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: context.k.inkSoft,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              icon,
              const SizedBox(width: 10),
              Expanded(child: body),
            ],
          );

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 64 : 70),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: row,
        ),
      ),
    );
  }
}

class _ParentScheduleCard extends StatelessWidget {
  const _ParentScheduleCard({
    required this.item,
    required this.conflict,
    required this.onTap,
    this.status,
  });

  final ClassSchedule item;
  final bool conflict;
  final VoidCallback onTap;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final kind = _scheduleKind(item);
    final detail = (item.content?.trim().isNotEmpty ?? false)
        ? item.content!.trim()
        : [item.teacherLabel, item.roomLabel]
            .where((part) => part.isNotEmpty)
            .join(' · ');
    final current = status == 'Đang diễn ra';

    return Semantics(
      button: true,
      label: '${item.displayName}, ${item.startTime}',
      child: Material(
        color: current ? context.k.brandTint : context.k.reviewSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: BoxConstraints(minHeight: current ? 102 : 80),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.k.lineStrong),
              boxShadow: [
                BoxShadow(
                  color: context.k.ink.withValues(alpha: .05),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Semantics(
                    image: true,
                    label: _scheduleKindLabel(kind),
                    child: _ParentScheduleIcon(kind: kind),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: context.k.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.startTime,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: context.k.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            color: context.k.inkSoft,
                          ),
                        ),
                      if (conflict)
                        Text(
                          'Xung đột khung giờ',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: context.k.warnDeep,
                          ),
                        ),
                      if (status == 'Đang diễn ra') ...[
                        const SizedBox(height: 3),
                        _ScheduleStatusPill(status: status!),
                      ],
                    ],
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

enum _ScheduleKind { attendance, food, activity, outdoor, sleep, health }

String _scheduleKindLabel(_ScheduleKind kind) => switch (kind) {
      _ScheduleKind.attendance => 'Điểm danh',
      _ScheduleKind.food => 'Bữa ăn',
      _ScheduleKind.activity => 'Hoạt động sáng tạo',
      _ScheduleKind.outdoor => 'Hoạt động ngoài trời',
      _ScheduleKind.sleep => 'Giấc ngủ',
      _ScheduleKind.health => 'Sức khỏe',
    };

_ScheduleKind _scheduleKind(ClassSchedule item) {
  final text =
      '${item.displayName} ${item.subject?.name ?? ''} ${item.content ?? ''}'
          .toLowerCase();
  if ((text.contains('điểm danh') || text.contains('đón trẻ')) &&
      !text.contains('ăn')) {
    return _ScheduleKind.attendance;
  }
  if (text.contains('ngủ') || text.contains('nghỉ trưa')) {
    return _ScheduleKind.sleep;
  }
  if (text.contains('ngoài trời') || text.contains('vận động')) {
    return _ScheduleKind.outdoor;
  }
  if (text.contains('sức khỏe') || text.contains('y tế')) {
    return _ScheduleKind.health;
  }
  if (text.contains('ăn') || text.contains('bữa')) return _ScheduleKind.food;
  return _ScheduleKind.activity;
}

({Color background, Color foreground}) _scheduleVisual(
  BuildContext context,
  _ScheduleKind kind,
) =>
    switch (kind) {
      _ScheduleKind.attendance =>
        (
          background: context.k.activityRowTint,
          foreground: context.k.activityRowText
        ),
      _ScheduleKind.food => (
          background: context.k.foodRowTint,
          foreground: context.k.foodRowText
        ),
      _ScheduleKind.activity || _ScheduleKind.outdoor =>
        (
          background: context.k.activityRowTint,
          foreground: context.k.activityRowText
        ),
      _ScheduleKind.sleep => (
          background: context.k.sleepRowTint,
          foreground: context.k.sleepRowText
        ),
      _ScheduleKind.health => (
          background: context.k.badTint,
          foreground: context.k.badText
        ),
    };

String _teacherScheduleIcon(_ScheduleKind kind) => switch (kind) {
      _ScheduleKind.attendance => 'assets/garden_voice/timetable_users.svg',
      _ScheduleKind.food => 'assets/garden_voice/timetable_utensils.svg',
      _ScheduleKind.activity => 'assets/garden_voice/timetable_sparkles.svg',
      _ScheduleKind.outdoor => 'assets/garden_voice/timetable_leaf.svg',
      _ScheduleKind.sleep => 'assets/garden_voice/timetable_moon.svg',
      _ScheduleKind.health => 'assets/garden_voice/timetable_heart.svg',
    };

class _ParentScheduleIcon extends StatelessWidget {
  const _ParentScheduleIcon({required this.kind});
  final _ScheduleKind kind;

  @override
  Widget build(BuildContext context) {
    if (kind == _ScheduleKind.food) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          children: [
            Positioned(
              left: 23,
              top: 6,
              child: SvgPicture.asset(
                'assets/garden_voice/parent_spoon.svg',
                width: 10.0513,
                height: 16.3106,
              ),
            ),
            Positioned(
              left: 6,
              top: 19,
              child: SvgPicture.asset(
                'assets/garden_voice/parent_bowl.svg',
                width: 27.824,
                height: 13,
              ),
            ),
          ],
        ),
      );
    }
    final asset = kind == _ScheduleKind.sleep
        ? 'assets/garden_voice/parent_crescent_moon.svg'
        : 'assets/garden_voice/parent_artist_palette.svg';
    return Center(
      child: SvgPicture.asset(asset, width: 28, height: 28),
    );
  }
}

class _ScheduleStatusPill extends StatelessWidget {
  const _ScheduleStatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: context.k.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: context.k.ink,
          ),
        ),
      );
}


typedef _ScheduleEditorSheet = ScheduleEditorSheet;

/* ======================= Helpers ======================= */

Color? _hexColor(String? hex) {
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
