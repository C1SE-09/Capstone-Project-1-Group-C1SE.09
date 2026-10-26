// frontend/lib/features/kindergarten_dashboard/widgets/schedule_editor_sheet.dart
// ==============================================================================
// Sheet thêm / chỉnh sửa hoạt động tiết học (ScheduleEditorSheet)

import 'package:flutter/material.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/data/repositories/http_schedule_repository.dart';
import 'package:adark_frontend/domain/entities/timetable/class_schedule.dart';
import 'package:adark_frontend/domain/entities/timetable/subject.dart';
import 'package:adark_frontend/domain/entities/timetable/time_slot.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/timetable_models_and_helpers.dart';

class ScheduleEditorSheet extends StatefulWidget {
  const ScheduleEditorSheet({
    super.key,
    required this.data,
    required this.classId,
    required this.repository,
    required this.onSaved,
    this.existing,
    this.classes,
    this.onClassChanged,
  });

  final TimetableData data;
  final String classId;
  final ScheduleRepository repository;
  final void Function(String message, int savedDay) onSaved;
  final ClassSchedule? existing;
  final List<Map<String, String>>? classes;
  final ValueChanged<String>? onClassChanged;

  @override
  State<ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<ScheduleEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _roomController;
  late final ScrollController _subjectScrollController = ScrollController();
  late final ScrollController _slotScrollController = ScrollController();
  Subject? _subject;
  TimeSlot? _slot;
  late int _day;
  late String _selectedClassId;
  bool _saving = false;
  String? _error;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _selectedClassId = widget.classId;
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
          classId: _selectedClassId.isNotEmpty ? _selectedClassId : widget.classId,
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
        setState(() => _error = getFriendlyErrorMessage(e, fallback: 'Không thể lưu hoạt động. Vui lòng thử lại.'));
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
          Text(widget.existing == null ? 'Thêm hoạt động' : 'Chỉnh sửa hoạt động',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (widget.classes != null && widget.classes!.isNotEmpty) ...[
            _fieldLabel(context, 'Lớp học'),
            DropdownButtonFormField<String>(
              initialValue: _selectedClassId.isNotEmpty && widget.classes!.any((c) => c['id'] == _selectedClassId)
                  ? _selectedClassId
                  : widget.classes!.first['id'],
              decoration: _inputDecoration(context, hint: 'Chọn lớp học'),
              items: widget.classes!.map((c) => DropdownMenuItem(
                value: c['id'],
                child: Text(c['name'] ?? ''),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedClassId = val);
                  widget.onClassChanged?.call(val);
                }
              },
            ),
            const SizedBox(height: 14),
          ],
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
                  label: kTimetableDayShort[d],
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
                      'Khung giờ này đã có "${clashes.first.displayName}" trong ngày ${kTimetableDayShort[_day]}.',
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
            style: TextStyle(fontSize: 12, color: context.k.inkSoft)),
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
                final Color color = timetableHexColor(s.colorCode) ?? itemCtx.k.brand;
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
                            child: Icon(timetableIconForSubject(s.name), size: 14, color: color),
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
            style: TextStyle(fontSize: 12, color: context.k.inkSoft)),
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
                                  fontSize: 12,
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
                              fontSize: 11,
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
