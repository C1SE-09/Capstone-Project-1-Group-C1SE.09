// frontend/lib/features/kindergarten_dashboard/screens/admin_management_screen.dart
// ==============================================================================
// Màn hình Quản trị Dữ liệu (Admin Management Screen)
// Kết nối trực tiếp API Backend (/api/admin) để lấy dữ liệu THẬT:
// - Giáo viên (Teachers): có Dropdown chọn Lớp từ DB
// - Phụ huynh (Parents): có Dropdown chọn Học sinh liên kết từ DB
// - Học sinh (Children): có Dropdown chọn Lớp từ DB, ghi chú mặc định để trống
// - Lịch sinh hoạt (Schedules): có thanh chọn Thứ 2 -> Thứ 6

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/data/repositories/http_admin_repository.dart';
import 'package:adark_frontend/data/repositories/http_schedule_repository.dart';
import 'package:adark_frontend/domain/entities/timetable/class_schedule.dart';
import 'package:adark_frontend/domain/entities/timetable/subject.dart';
import 'package:adark_frontend/domain/entities/timetable/time_slot.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/timetable_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

enum AdminCategory {
  teachers('Giáo viên'),
  parents('Phụ huynh'),
  students('Học sinh'),
  schedules('Thời khóa biểu');

  const AdminCategory(this.label);
  final String label;
}

class AdminItem {
  AdminItem({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    this.phone,
    this.email,
    this.timeRange,
    this.location,
    this.note,
    this.classId,
    this.childId,
    this.classIds = const [],
    this.childIds = const [],
    this.slotId,
    this.startTime,
    this.endTime,
    this.dayOfWeek,
  });

  final String id;
  final AdminCategory category;
  String title;
  String subtitle;
  String? phone;
  String? email;
  String? timeRange;
  String? location;
  String? note;
  String? classId;
  String? childId;
  List<String> classIds;
  List<String> childIds;
  String? slotId;
  String? startTime;
  String? endTime;
  int? dayOfWeek;
}

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({
    super.key,
    required this.onLogout,
    this.repository,
    this.initialCategory,
    this.embedded = false,
  });

  final VoidCallback onLogout;
  final HttpAdminRepository? repository;
  final AdminCategory? initialCategory;
  final bool embedded;

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  late final HttpAdminRepository _repo = widget.repository ?? HttpAdminRepository();
  late AdminCategory _selectedCategory = widget.initialCategory ?? AdminCategory.parents;
  int _selectedDayOfWeek = 2; // 2: Thứ 2, 3: Thứ 3, ..., 6: Thứ 6
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoading = false;
  String? _errorMessage;
  List<AdminItem> _items = [];

  // Danh sách Lớp, Học sinh và Khung giờ chuẩn từ DB để nạp vào Dropdown
  List<AdminClassDto> _classes = [];
  List<AdminChildDto> _childrenList = [];
  List<AdminTimeSlotDto> _timeSlots = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant AdminManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != null && widget.initialCategory != _selectedCategory) {
      setState(() {
        _selectedCategory = widget.initialCategory!;
        _searchController.clear();
        _searchQuery = '';
      });
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadDropdownResources();
    await _loadData();
  }

  Future<void> _loadDropdownResources() async {
    try {
      final results = await Future.wait([
        _repo.getClasses(),
        _repo.getChildren(),
        _repo.getTimeSlots(),
      ]);
      if (mounted) {
        setState(() {
          _classes = results[0] as List<AdminClassDto>;
          _childrenList = results[1] as List<AdminChildDto>;
          _timeSlots = results[2] as List<AdminTimeSlotDto>;
        });
      }
    } catch (_) {
      // Bỏ qua lỗi âm thầm nếu đang khởi tạo
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<AdminItem> loaded = [];
      switch (_selectedCategory) {
        case AdminCategory.teachers:
          final res = await _repo.getTeachers();
          loaded = res.map((t) => AdminItem(
            id: t.id,
            category: AdminCategory.teachers,
            title: t.fullName,
            subtitle: 'Lớp: ${t.className}',
            phone: t.phone,
            email: t.email,
            classId: t.classId,
            classIds: t.classIds,
          )).toList();
          break;

        case AdminCategory.parents:
          final res = await _repo.getParents();
          loaded = res.map((p) => AdminItem(
            id: p.id,
            category: AdminCategory.parents,
            title: p.fullName,
            subtitle: p.childrenSummary.replaceFirst('BN: ', 'Bé: '),
            phone: p.phone,
            email: p.email.isNotEmpty ? p.email : null,
            childId: p.childId,
            childIds: p.childIds,
          )).toList();
          break;

        case AdminCategory.students:
          final res = await _repo.getChildren();
          // Cập nhật lại cache childrenList
          _childrenList = res;
          loaded = res.map((c) => AdminItem(
            id: c.id,
            category: AdminCategory.students,
            title: c.fullName,
            subtitle: '${c.nickname.isNotEmpty ? "Bé ${c.nickname} · " : ""}${c.className}',
            note: c.note.trim().isNotEmpty ? c.note.trim() : null,
            phone: c.parentPhone,
            classId: c.classId,
          )).toList();
          break;

        case AdminCategory.schedules:
          final res = await _repo.getSchedules(dayOfWeek: _selectedDayOfWeek);
          loaded = res.map((s) => AdminItem(
            id: s.id,
            category: AdminCategory.schedules,
            title: s.activityName,
            subtitle: s.content.isNotEmpty ? s.content : 'Hoạt động theo kế hoạch',
            timeRange: s.timeRange,
            location: s.roomName,
            slotId: s.slotId,
            startTime: s.startTime,
            endTime: s.endTime,
            dayOfWeek: s.dayOfWeek,
          )).toList();
          break;
      }

      if (mounted) {
        setState(() {
          _items = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối máy chủ: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _getInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return 'AD';
    if (words.length == 1) return words[0].substring(0, 1).toUpperCase();
    return (words[words.length - 2].substring(0, 1) + words[words.length - 1].substring(0, 1)).toUpperCase();
  }

  List<AdminItem> get _filteredItems {
    return _items.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final matchTitle = item.title.toLowerCase().contains(q);
      final matchSubtitle = item.subtitle.toLowerCase().contains(q);
      final matchPhone = item.phone?.toLowerCase().contains(q) ?? false;
      final matchEmail = item.email?.toLowerCase().contains(q) ?? false;
      return matchTitle || matchSubtitle || matchPhone || matchEmail;
    }).toList();
  }

  int? _timeToMinutes(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return null;
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  int? _parseFlexibleTime(String text) {
    text = text.trim();
    if (text.contains(':')) {
      final parts = text.split(':');
      final h = int.tryParse(parts[0].replaceAll(RegExp(r'\D'), ''));
      final m = int.tryParse(parts[1].replaceAll(RegExp(r'\D'), ''));
      if (h != null && m != null) return h * 60 + m;
    } else if (text.contains('h')) {
      final parts = text.split('h');
      final h = int.tryParse(parts[0].replaceAll(RegExp(r'\D'), ''));
      final m = int.tryParse(parts[1].replaceAll(RegExp(r'\D'), ''));
      if (h != null) return h * 60 + (m ?? 0);
    }
    return null;
  }

  Future<void> _pickTime({
    required BuildContext context,
    required String initial,
    required ValueChanged<String> onSelected,
  }) async {
    final parts = initial.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (pickerCtx, child) {
        return MediaQuery(
          data: MediaQuery.of(pickerCtx).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      onSelected('$h:$m');
    }
  }

  void _showErrorPopup(
    BuildContext ctx, {
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.k.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadii.card)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: context.k.bad, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: context.k.ink),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(height: 1.4, fontSize: 14, color: context.k.inkSoft),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.k.brand,
              foregroundColor: context.k.canvas,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadii.control)),
            ),
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showTimeConflictPopup(
    BuildContext ctx, {
    required String targetTimeRange,
    required AdminItem conflict,
  }) {
    showDialog<void>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.k.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadii.card)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.k.bad.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, color: context.k.bad, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Trùng khung giờ!',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.k.ink,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Khung giờ bạn chọn đã bị trùng hoặc đè lên một hoạt động khác trong ngày:',
              style: TextStyle(color: context.k.inkSoft, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.k.canvas,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.k.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: context.k.bad),
                      const SizedBox(width: 6),
                      Text(
                        'Khung giờ mới: $targetTimeRange',
                        style: TextStyle(fontWeight: FontWeight.w700, color: context.k.bad, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.event_busy, size: 16, color: context.k.inkSoft),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Bị đè lên: "${conflict.title}"',
                          style: TextStyle(fontWeight: FontWeight.w600, color: context.k.ink, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thời gian: ${conflict.timeRange ?? 'Chưa rõ'} (${conflict.location ?? 'Phòng học'})',
                    style: TextStyle(color: context.k.inkSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Vui lòng chọn khung giờ khác không bị giao thoa với các hoạt động hiện có.',
              style: TextStyle(color: context.k.inkSoft, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.k.brand,
              foregroundColor: context.k.canvas,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadii.control)),
            ),
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Đã hiểu & Điều chỉnh lại'),
          ),
        ],
      ),
    );
  }

  void _openAddDialog() {
    _showItemFormDialog(item: null);
  }

  void _openEditDialog(AdminItem item) {
    _showItemFormDialog(item: item);
  }

  void _confirmDelete(AdminItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.k.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadii.card),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: context.k.bad, size: 24),
            const SizedBox(width: 8),
            Text(
              'Xác nhận xóa',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.k.ink,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${item.title}" khỏi cơ sở dữ liệu không?\nThao tác này không thể hoàn tác.',
          style: TextStyle(color: context.k.inkSoft, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Hủy', style: TextStyle(color: context.k.inkSoft)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.k.bad,
              foregroundColor: context.k.canvas,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KRadii.control),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                switch (_selectedCategory) {
                  case AdminCategory.teachers:
                    await _repo.deleteTeacher(item.id);
                    break;
                  case AdminCategory.parents:
                    await _repo.deleteParent(item.id);
                    break;
                  case AdminCategory.students:
                    await _repo.deleteChild(item.id);
                    break;
                  case AdminCategory.schedules:
                    await _repo.deleteSchedule(item.id);
                    break;
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa thành công: ${item.title}'),
                    backgroundColor: context.k.bad,
                  ),
                );
                _loadData();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi khi xóa: $e'),
                    backgroundColor: context.k.bad,
                  ),
                );
              }
            },
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _openScheduleEditorSheet({AdminItem? item}) async {
    try {
      final scheduleRepo = HttpScheduleRepository();
      String currentClassId = item?.classId ?? (_classes.isNotEmpty ? _classes.first.id : '');
      if (currentClassId.isEmpty && _classes.isNotEmpty) {
        currentClassId = _classes.first.id;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final results = await Future.wait([
        scheduleRepo.getTimeSlots(),
        scheduleRepo.getSubjects(),
        currentClassId.isNotEmpty ? scheduleRepo.getClassSchedule(currentClassId) : Future.value(<ClassSchedule>[]),
      ]);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      final slots = results[0] as List<TimeSlot>;
      final subjects = results[1] as List<Subject>;
      final scheduleItems = results[2] as List<ClassSchedule>;

      ClassSchedule? existingSchedule;
      if (item != null) {
        for (final s in scheduleItems) {
          if (s.scheduleId == item.id) {
            existingSchedule = s;
            break;
          }
        }
        if (existingSchedule == null) {
          Subject? matchedSubject;
          for (final s in subjects) {
            if (s.name.toLowerCase() == item.title.toLowerCase()) {
              matchedSubject = s;
              break;
            }
          }
          TimeSlot? matchedSlot;
          for (final sl in slots) {
            if (sl.startTime == item.startTime && sl.endTime == item.endTime) {
              matchedSlot = sl;
              break;
            }
          }
          existingSchedule = ClassSchedule(
            scheduleId: item.id,
            classId: item.classId ?? currentClassId,
            subjectId: matchedSubject?.subjectId ?? (subjects.isNotEmpty ? subjects.first.subjectId : ''),
            slotId: matchedSlot?.slotId ?? (slots.isNotEmpty ? slots.first.slotId : ''),
            dayOfWeek: _selectedDayOfWeek,
            activityName: item.title,
            roomName: item.location,
            subject: matchedSubject,
            timeSlot: matchedSlot,
          );
        }
      }

      final timetableData = TimetableData(
        items: scheduleItems,
        slots: slots,
        subjects: subjects,
      );

      final classOptions = _classes.map((c) => {'id': c.id, 'name': c.name}).toList();

      if (!mounted) return;

      showKSheet(
        context,
        ScheduleEditorSheet(
          data: timetableData,
          classId: currentClassId,
          classes: classOptions,
          repository: scheduleRepo,
          existing: existingSchedule,
          onSaved: (message, savedDay) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: context.k.brand),
            );
            setState(() {
              _selectedDayOfWeek = savedDay + 2;
            });
            _loadData();
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        _showErrorPopup(context, title: 'Thông báo lỗi', message: 'Không thể mở chỉnh sửa thời khóa biểu: ${getFriendlyErrorMessage(e)}');
      }
    }
  }

  void _showItemFormDialog({AdminItem? item}) {
    if (_selectedCategory == AdminCategory.schedules) {
      _openScheduleEditorSheet(item: item);
      return;
    }
    final isEdit = item != null;
    final titleController = TextEditingController(text: item?.title ?? '');
    final subtitleController = TextEditingController(
      text: item == null
          ? ''
          : _selectedCategory == AdminCategory.students
              ? (item.subtitle.contains('Bé ') ? item.subtitle.split(' · ')[0].replaceFirst('Bé ', '') : '')
              : item.subtitle,
    );
    final phoneController = TextEditingController(text: item?.phone ?? '');
    final emailController = TextEditingController(text: item?.email ?? '');
    final locationController = TextEditingController(text: item?.location ?? '');
    final noteController = TextEditingController(text: item?.note ?? '');

    // State cho Dropdown chọn Lớp cho Học sinh
    String? selectedClassId = item?.classId;
    if (selectedClassId == null && _classes.isNotEmpty) {
      selectedClassId = _classes.first.id;
    }

    // State danh sách Lớp cho Giáo viên
    List<String> selectedClassIds = List<String>.from(
      item?.classIds.isNotEmpty == true
          ? item!.classIds
          : (item?.classId != null ? [item!.classId!] : []),
    );
    String? classToAdd;

    // State danh sách Con cho Phụ huynh
    List<String> selectedChildIds = List<String>.from(
      item?.childIds.isNotEmpty == true
          ? item!.childIds
          : (item?.childId != null ? [item!.childId!] : []),
    );
    String? childToAdd;

    // State cho Thời khóa biểu
    bool isCustomTime = false;
    String? selectedSlotId;
    String customStartTime = '08:00';
    String customEndTime = '08:30';

    if (_selectedCategory == AdminCategory.schedules) {
      if (item != null) {
        customStartTime = item.startTime ?? '08:00';
        customEndTime = item.endTime ?? '08:30';
        final hasMatch = _timeSlots.any((s) => s.id == item.slotId);
        if (hasMatch) {
          selectedSlotId = item.slotId;
          isCustomTime = false;
        } else {
          isCustomTime = true;
          selectedSlotId = _timeSlots.isNotEmpty ? _timeSlots.first.id : null;
        }
      } else {
        selectedSlotId = _timeSlots.isNotEmpty ? _timeSlots.first.id : null;
        isCustomTime = false;
      }
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: context.k.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KRadii.card),
          ),
          title: Text(
            isEdit ? 'Chỉnh sửa ${_selectedCategory.label}' : 'Thêm ${_selectedCategory.label} mới',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.k.ink,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: _selectedCategory == AdminCategory.schedules ? 'Tên hoạt động' : 'Họ và tên',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. FORM GIÁO VIÊN: Danh sách các Lớp phụ trách (có nút xóa) + Thêm lớp + SĐT + Email
                  if (_selectedCategory == AdminCategory.teachers) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Các lớp phụ trách (${selectedClassIds.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: context.k.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: context.k.canvas,
                        borderRadius: BorderRadius.circular(KRadii.control),
                        border: Border.all(color: context.k.line),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (selectedClassIds.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Text(
                                'Chưa phân công lớp nào. Hãy chọn lớp và nhấn "Thêm" bên dưới.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.k.inkSoft,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            ...selectedClassIds.map((cId) {
                              final matchingClasses = _classes.where((c) => c.id == cId);
                              final cls = matchingClasses.isNotEmpty ? matchingClasses.first : null;
                              final clsName = cls?.name ?? 'Lớp ($cId)';
                              final grade = cls != null && cls.gradeLabel.isNotEmpty ? ' · ${cls.gradeLabel}' : '';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: context.k.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.k.line.withAlpha(120)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.meeting_room_outlined, size: 18, color: context.k.brand),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$clsName$grade',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: context.k.ink,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          selectedClassIds.remove(cId);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(Icons.delete_outline_rounded, size: 18, color: context.k.bad),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 4),
                          Builder(
                            builder: (ctx) {
                              final availableClasses = _classes.where((c) => !selectedClassIds.contains(c.id)).toList();
                              if (availableClasses.isEmpty) {
                                return Text(
                                  _classes.isEmpty ? 'Chưa có lớp nào trong hệ thống.' : 'Đã chọn tất cả các lớp hiện có.',
                                  style: TextStyle(fontSize: 12, color: context.k.inkSoft, fontStyle: FontStyle.italic),
                                );
                              }
                              final effectiveClassToAdd = (classToAdd != null && availableClasses.any((c) => c.id == classToAdd))
                                  ? classToAdd
                                  : availableClasses.first.id;

                              return Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      key: ValueKey('cls_$effectiveClassToAdd'),
                                      initialValue: effectiveClassToAdd,
                                      isDense: true,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(KRadii.control)),
                                        labelText: 'Chọn lớp để thêm',
                                      ),
                                      items: availableClasses.map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                                      )).toList(),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          classToAdd = val;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: context.k.brand,
                                      foregroundColor: context.k.canvas,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadii.control)),
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Thêm', style: TextStyle(fontSize: 13)),
                                    onPressed: () {
                                      final toAdd = classToAdd ?? (availableClasses.isNotEmpty ? availableClasses.first.id : null);
                                      if (toAdd != null) {
                                        setDialogState(() {
                                          if (!selectedClassIds.contains(toAdd)) {
                                            selectedClassIds.add(toAdd);
                                          }
                                          classToAdd = null;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Số điện thoại *', counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email liên hệ * (Gmail)'),
                    ),
                  ]

                  // 2. FORM PHỤ HUYNH: Danh sách con (Học sinh liên kết có nút xóa) + Thêm con + SĐT + Email
                  else if (_selectedCategory == AdminCategory.parents) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Danh sách con (Học sinh liên kết) (${selectedChildIds.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: context.k.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: context.k.canvas,
                        borderRadius: BorderRadius.circular(KRadii.control),
                        border: Border.all(color: context.k.line),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (selectedChildIds.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Text(
                                'Chưa liên kết học sinh nào. Chọn học sinh và nhấn "Thêm" bên dưới.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.k.inkSoft,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            ...selectedChildIds.map((chId) {
                              final matchingChildren = _childrenList.where((c) => c.id == chId);
                              final ch = matchingChildren.isNotEmpty ? matchingChildren.first : null;
                              final chName = ch?.fullName ?? 'Học sinh ($chId)';
                              final cls = ch != null && ch.className.isNotEmpty ? ' · Lớp: ${ch.className}' : '';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: context.k.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.k.line.withAlpha(120)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.child_care_rounded, size: 18, color: context.k.brand),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: context.k.ink,
                                            ),
                                          ),
                                          if (cls.isNotEmpty)
                                            Text(
                                              cls.replaceFirst(' · ', ''),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: context.k.inkSoft,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          selectedChildIds.remove(chId);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(Icons.delete_outline_rounded, size: 18, color: context.k.bad),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 4),
                          Builder(
                            builder: (ctx) {
                              final availableChildren = _childrenList.where((c) => !selectedChildIds.contains(c.id)).toList();
                              if (availableChildren.isEmpty) {
                                return Text(
                                  _childrenList.isEmpty ? 'Chưa có học sinh trong hệ thống.' : 'Đã chọn tất cả học sinh hiện có.',
                                  style: TextStyle(fontSize: 12, color: context.k.inkSoft, fontStyle: FontStyle.italic),
                                );
                              }
                              final effectiveChildToAdd = (childToAdd != null && availableChildren.any((c) => c.id == childToAdd))
                                  ? childToAdd
                                  : availableChildren.first.id;

                              return Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      key: ValueKey('ch_$effectiveChildToAdd'),
                                      initialValue: effectiveChildToAdd,
                                      isDense: true,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(KRadii.control)),
                                        labelText: 'Chọn học sinh để thêm',
                                      ),
                                      items: availableChildren.map((ch) => DropdownMenuItem(
                                        value: ch.id,
                                        child: Text('${ch.fullName} (${ch.className})', overflow: TextOverflow.ellipsis),
                                      )).toList(),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          childToAdd = val;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: context.k.brand,
                                      foregroundColor: context.k.canvas,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadii.control)),
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Thêm', style: TextStyle(fontSize: 13)),
                                    onPressed: () {
                                      final toAdd = childToAdd ?? (availableChildren.isNotEmpty ? availableChildren.first.id : null);
                                      if (toAdd != null) {
                                        setDialogState(() {
                                          if (!selectedChildIds.contains(toAdd)) {
                                            selectedChildIds.add(toAdd);
                                          }
                                          childToAdd = null;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Số điện thoại *', counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email (tùy chọn, định dạng Gmail)'),
                    ),
                  ]

                  // 3. FORM HỌC SINH: Dropdown chọn Lớp + Biệt danh + Ghi chú (mặc định trống)
                  else if (_selectedCategory == AdminCategory.students) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey('std_cls_$selectedClassId'),
                      initialValue: selectedClassId,
                      decoration: const InputDecoration(labelText: 'Lớp học'),
                      items: _classes.map((cls) => DropdownMenuItem(
                        value: cls.id,
                        child: Text(cls.name),
                      )).toList(),
                      onChanged: (val) => setDialogState(() => selectedClassId = val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subtitleController,
                      decoration: const InputDecoration(labelText: 'Biệt danh (Tên gọi ở nhà)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (tùy chọn, mặc định để trống)',
                        hintText: 'Nhập ghi chú cho bé...',
                      ),
                    ),
                  ]

                  // 4. FORM THỜI KHÓA BIỂU
                  else if (_selectedCategory == AdminCategory.schedules) ...[
                    TextField(
                      controller: subtitleController,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung chi tiết',
                        hintText: 'Mô tả chi tiết hoạt động...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Phòng học / Địa điểm',
                        hintText: 'VD: Phòng Mầm A, Sân cỏ...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Khung giờ hoạt động',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: context.k.ink,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Thanh chọn chế độ: Khung giờ chuẩn vs Khung giờ khác (Tùy chỉnh)
                    Container(
                      decoration: BoxDecoration(
                        color: context.k.canvas,
                        borderRadius: BorderRadius.circular(KRadii.control),
                        border: Border.all(color: context.k.line),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => isCustomTime = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isCustomTime ? context.k.brand : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Khung giờ chuẩn',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: !isCustomTime ? context.k.canvas : context.k.inkSoft,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => isCustomTime = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isCustomTime ? context.k.brand : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Khung giờ khác',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isCustomTime ? context.k.canvas : context.k.inkSoft,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (!isCustomTime) ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey('slot_$selectedSlotId'),
                        initialValue: selectedSlotId,
                        decoration: const InputDecoration(
                          labelText: 'Chọn khung giờ cố định',
                          prefixIcon: Icon(Icons.schedule, size: 20),
                        ),
                        items: _timeSlots.map((slot) => DropdownMenuItem(
                          value: slot.id,
                          child: Text('${slot.name} (${slot.startTime} - ${slot.endTime})'),
                        )).toList(),
                        onChanged: (val) => setDialogState(() => selectedSlotId = val),
                      ),
                    ] else ...[
                      // Khung giờ khác (Tùy chỉnh giờ bắt đầu & giờ kết thúc)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                await _pickTime(
                                  context: ctx,
                                  initial: customStartTime,
                                  onSelected: (time) => setDialogState(() => customStartTime = time),
                                );
                              },
                              borderRadius: BorderRadius.circular(KRadii.control),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Giờ bắt đầu',
                                  prefixIcon: Icon(Icons.play_circle_outline, size: 20),
                                ),
                                child: Text(
                                  customStartTime,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: context.k.brand,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                await _pickTime(
                                  context: ctx,
                                  initial: customEndTime,
                                  onSelected: (time) => setDialogState(() => customEndTime = time),
                                );
                              },
                              borderRadius: BorderRadius.circular(KRadii.control),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Giờ kết thúc',
                                  prefixIcon: Icon(Icons.stop_circle_outlined, size: 20),
                                ),
                                child: Text(
                                  customEndTime,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: context.k.brand,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Chạm vào từng ô để mở đồng hồ chọn giờ chính xác.',
                        style: TextStyle(fontSize: 12, color: context.k.inkSoft, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Hủy', style: TextStyle(color: context.k.inkSoft)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.k.brand,
                foregroundColor: context.k.canvas,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KRadii.control),
                ),
              ),
              onPressed: () async {
                final newTitle = titleController.text.trim();
                if (newTitle.isEmpty) return;

                // Chuẩn bị biến thời gian nếu là Thời khóa biểu
                String? schedStartTime;
                String? schedEndTime;
                String? schedSlotId;
                String? schedDisplayRange;

                if (_selectedCategory == AdminCategory.schedules) {
                  if (!isCustomTime) {
                    final slot = _timeSlots.firstWhere(
                      (s) => s.id == selectedSlotId,
                      orElse: () => _timeSlots.isNotEmpty
                          ? _timeSlots.first
                          : AdminTimeSlotDto(
                              id: '',
                              name: '08:00 - 08:30',
                              startTime: '08:00',
                              endTime: '08:30',
                              orderIndex: 0,
                            ),
                    );
                    schedStartTime = slot.startTime;
                    schedEndTime = slot.endTime;
                    schedSlotId = slot.id.isNotEmpty ? slot.id : null;
                    schedDisplayRange = slot.name;
                  } else {
                    schedStartTime = customStartTime;
                    schedEndTime = customEndTime;
                    schedSlotId = null;
                    schedDisplayRange = '$customStartTime - $customEndTime';
                  }

                  final startMin = _timeToMinutes(schedStartTime);
                  final endMin = _timeToMinutes(schedEndTime);

                  if (startMin == null || endMin == null) {
                    _showErrorPopup(
                      ctx,
                      title: 'Khung giờ không hợp lệ',
                      message: 'Vui lòng chọn thời gian bắt đầu và kết thúc đầy đủ.',
                    );
                    return;
                  }

                  if (endMin <= startMin) {
                    _showErrorPopup(
                      ctx,
                      title: 'Khung giờ không hợp lệ',
                      message: 'Giờ kết thúc ($schedEndTime) phải diễn ra sau Giờ bắt đầu ($schedStartTime).\nVui lòng điều chỉnh lại.',
                    );
                    return;
                  }

                  // KIỂM TRA TRÙNG / ĐÈ LÊN GIỜ KHÁC TRONG NGÀY
                  AdminItem? conflictingSchedule;
                  for (final existing in _items) {
                    if (isEdit && existing.id == item.id) continue;

                    int? existStartMin = _timeToMinutes(existing.startTime);
                    int? existEndMin = _timeToMinutes(existing.endTime);

                    if (existStartMin == null || existEndMin == null) {
                      if (existing.timeRange != null && existing.timeRange!.contains('-')) {
                        final p = existing.timeRange!.split('-');
                        existStartMin = _parseFlexibleTime(p[0]);
                        existEndMin = _parseFlexibleTime(p[1]);
                      }
                    }

                    if (existStartMin != null && existEndMin != null) {
                      // Trùng / đè nhau: startMin < existEndMin && endMin > existStartMin
                      if (startMin < existEndMin && endMin > existStartMin) {
                        conflictingSchedule = existing;
                        break;
                      }
                    }
                  }

                  if (conflictingSchedule != null) {
                    // THẢ POPUP THÔNG BÁO LỖI TRÙNG / ĐÈ LÊN GIỜ KHÁC
                    _showTimeConflictPopup(
                      ctx,
                      targetTimeRange: schedDisplayRange,
                      conflict: conflictingSchedule,
                    );
                    return; // GIỮ NGUYÊN FORM ĐỂ NGƯỜI DÙNG SỬA
                  }
                }

                if (_selectedCategory == AdminCategory.teachers) {
                  final phoneVal = phoneController.text.trim();
                  if (phoneVal.isEmpty || !RegExp(r'^0\d{9}$').hasMatch(phoneVal)) {
                    _showErrorPopup(
                      ctx,
                      title: 'Số điện thoại không hợp lệ',
                      message: 'Số điện thoại phải gồm đúng 10 chữ số (bắt đầu bằng số 0).',
                    );
                    return;
                  }
                  final emailVal = emailController.text.trim();
                  if (emailVal.isEmpty || !RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$', caseSensitive: false).hasMatch(emailVal)) {
                    _showErrorPopup(
                      ctx,
                      title: 'Email không hợp lệ',
                      message: 'Email phải có định dạng @gmail.com (ví dụ: gv@gmail.com).',
                    );
                    return;
                  }
                } else if (_selectedCategory == AdminCategory.parents) {
                  final phoneVal = phoneController.text.trim();
                  if (phoneVal.isEmpty || !RegExp(r'^0\d{9}$').hasMatch(phoneVal)) {
                    _showErrorPopup(
                      ctx,
                      title: 'Số điện thoại không hợp lệ',
                      message: 'Số điện thoại phải gồm đúng 10 chữ số (bắt đầu bằng số 0).',
                    );
                    return;
                  }
                  final emailVal = emailController.text.trim();
                  if (emailVal.isNotEmpty && !RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$', caseSensitive: false).hasMatch(emailVal)) {
                    _showErrorPopup(
                      ctx,
                      title: 'Email không hợp lệ',
                      message: 'Email phải có định dạng @gmail.com (ví dụ: ph@gmail.com).',
                    );
                    return;
                  }
                }

                Navigator.of(ctx).pop();

                try {
                  if (isEdit) {
                    switch (_selectedCategory) {
                      case AdminCategory.teachers:
                        await _repo.updateTeacher(
                          item.id,
                          fullName: newTitle,
                          email: emailController.text.trim(),
                          phone: phoneController.text.trim(),
                          classId: selectedClassIds.isNotEmpty ? selectedClassIds.first : null,
                          classIds: selectedClassIds,
                        );
                        break;
                      case AdminCategory.parents:
                        await _repo.updateParent(
                          item.id,
                          fullName: newTitle,
                          phone: phoneController.text.trim(),
                          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                          childId: selectedChildIds.isNotEmpty ? selectedChildIds.first : null,
                          childIds: selectedChildIds,
                        );
                        break;
                      case AdminCategory.students:
                        await _repo.updateChild(
                          item.id,
                          fullName: newTitle,
                          nickname: subtitleController.text.trim().isEmpty ? null : subtitleController.text.trim(),
                          classId: selectedClassId,
                          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        );
                        break;
                      case AdminCategory.schedules:
                        await _repo.updateSchedule(
                          item.id,
                          activityName: newTitle,
                          content: subtitleController.text.trim().isEmpty ? null : subtitleController.text.trim(),
                          roomName: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                          slotId: schedSlotId,
                          startTime: schedStartTime,
                          endTime: schedEndTime,
                          dayOfWeek: _selectedDayOfWeek,
                        );
                        break;
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã cập nhật: $newTitle'), backgroundColor: context.k.brand),
                    );
                  } else {
                    switch (_selectedCategory) {
                      case AdminCategory.teachers:
                        await _repo.createTeacher(
                          fullName: newTitle,
                          email: emailController.text.trim().isEmpty ? 'teacher@kinderlog.edu.vn' : emailController.text.trim(),
                          phone: phoneController.text.trim().isEmpty ? '0900000000' : phoneController.text.trim(),
                          classId: selectedClassIds.isNotEmpty ? selectedClassIds.first : null,
                          classIds: selectedClassIds,
                        );
                        break;
                      case AdminCategory.parents:
                        await _repo.createParent(
                          fullName: newTitle,
                          phone: phoneController.text.trim().isEmpty ? '0910000000' : phoneController.text.trim(),
                          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                          childId: selectedChildIds.isNotEmpty ? selectedChildIds.first : null,
                          childIds: selectedChildIds,
                        );
                        break;
                      case AdminCategory.students:
                        await _repo.createChild(
                          fullName: newTitle,
                          nickname: subtitleController.text.trim().isEmpty ? null : subtitleController.text.trim(),
                          classId: selectedClassId,
                          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        );
                        break;
                      case AdminCategory.schedules:
                        await _repo.createSchedule(
                          activityName: newTitle,
                          content: subtitleController.text.trim().isEmpty ? null : subtitleController.text.trim(),
                          roomName: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                          slotId: schedSlotId,
                          startTime: schedStartTime,
                          endTime: schedEndTime,
                          dayOfWeek: _selectedDayOfWeek,
                        );
                        break;
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã thêm mới: $newTitle'), backgroundColor: context.k.brand),
                    );
                  }
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  final errMsg = getFriendlyErrorMessage(e);
                  _showErrorPopup(context, title: 'Thông báo lỗi', message: errMsg);
                }
              },
              child: Text(isEdit ? 'Lưu thay đổi' : 'Thêm mới'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: context.k.canvas,
      appBar: widget.embedded
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
        backgroundColor: context.k.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: context.k.line)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.k.ink),
          tooltip: 'Đăng xuất / Quay lại',
          onPressed: widget.onLogout,
        ),
        title: Text(
          'Quản trị hệ thống',
          style: TextStyle(
            color: context.k.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.k.ink),
            tooltip: 'Làm mới dữ liệu',
            onPressed: () {
              _loadDropdownResources();
              _loadData();
            },
          ),
          IconButton(
            icon: Icon(Icons.account_circle_outlined, color: context.k.ink),
            tooltip: 'Tài khoản Admin',
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: context.k.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const CircleAvatar(child: Text('AD')),
                          title: const Text('Quản trị viên (Admin)'),
                          subtitle: const Text('admin@kinderlog.edu.vn'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: Icon(Icons.logout, color: context.k.bad),
                          title: Text('Đăng xuất', style: TextStyle(color: context.k.bad)),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            widget.onLogout();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Segmented Category Tabs
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: context.k.surfaceSunken,
                  borderRadius: BorderRadius.circular(KRadii.card),
                  border: Border.all(color: context.k.line),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: AdminCategory.values.map((cat) {
                    final isSelected = cat == _selectedCategory;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_selectedCategory == cat) return;
                          setState(() {
                            _selectedCategory = cat;
                            _searchController.clear();
                            _searchQuery = '';
                          });
                          _loadData();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected ? context.k.brand : Colors.transparent,
                            borderRadius: BorderRadius.circular(KRadii.control),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cat.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white : context.k.ink,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Day Selector Bar (chỉ hiển thị khi chọn tab Lịch sinh hoạt)
            if (_selectedCategory == AdminCategory.schedules)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    for (final dayEntry in [
                      (2, 'Thứ 2'),
                      (3, 'Thứ 3'),
                      (4, 'Thứ 4'),
                      (5, 'Thứ 5'),
                      (6, 'Thứ 6'),
                    ]) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_selectedDayOfWeek == dayEntry.$1) return;
                            setState(() {
                              _selectedDayOfWeek = dayEntry.$1;
                            });
                            _loadData();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedDayOfWeek == dayEntry.$1
                                  ? context.k.brandTint
                                  : context.k.surface,
                              borderRadius: BorderRadius.circular(KRadii.control),
                              border: Border.all(
                                color: _selectedDayOfWeek == dayEntry.$1
                                    ? context.k.brand
                                    : context.k.line,
                                width: _selectedDayOfWeek == dayEntry.$1 ? 1.5 : 1.0,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              dayEntry.$2,
                              style: TextStyle(
                                color: _selectedDayOfWeek == dayEntry.$1
                                    ? context.k.brandStrong
                                    : context.k.inkSoft,
                                fontWeight: _selectedDayOfWeek == dayEntry.$1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (dayEntry.$1 != 6) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),

            // 2. Toolbar: Search Bar + Add Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm ${_selectedCategory.label.toLowerCase()}...',
                          prefixIcon: Icon(Icons.search, size: 20, color: context.k.inkSoft),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: context.k.brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KRadii.control),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Thêm mới',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      onPressed: _openAddDialog,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Data Cards List / Loading / Error
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off_outlined, size: 48, color: context.k.bad),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: context.k.inkSoft, fontSize: 13),
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 48, color: context.k.inkFaint),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'Chưa có ${_selectedCategory.label.toLowerCase()} nào'
                                        : 'Không tìm thấy kết quả phù hợp',
                                    style: TextStyle(color: context.k.inkSoft, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return _buildItemCard(item);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(AdminItem item) {
    final initials = _getInitials(item.title);

    return KCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.k.surfaceSunken,
              shape: BoxShape.circle,
              border: Border.all(color: context.k.line),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: context.k.ink,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Main Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: context.k.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: context.k.inkSoft,
                    fontSize: 12,
                  ),
                ),
                if (item.phone != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 14, color: context.k.inkSoft),
                      const SizedBox(width: 6),
                      Text(
                        item.phone!,
                        style: TextStyle(color: context.k.ink, fontSize: 12),
                      ),
                    ],
                  ),
                ],
                if (item.email != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 14, color: context.k.inkSoft),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.email!,
                          style: TextStyle(color: context.k.ink, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.timeRange != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: context.k.brand),
                      const SizedBox(width: 6),
                      Text(
                        item.timeRange!,
                        style: TextStyle(
                          color: context.k.brand,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.location != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: context.k.inkSoft),
                      const SizedBox(width: 6),
                      Text(
                        item.location!,
                        style: TextStyle(color: context.k.inkSoft, fontSize: 12),
                      ),
                    ],
                  ),
                ],
                // Hiển thị Ghi chú (chỉ hiển thị nếu có ghi chú và không rỗng)
                if (item.note != null && item.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.notes_rounded, size: 14, color: context.k.inkSoft),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Ghi chú: ${item.note!}',
                          style: TextStyle(
                            color: context.k.inkSoft,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Action Buttons: Sửa and Xóa
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nút Sửa
              SizedBox(
                height: 34,
                width: 78,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.k.brand),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KRadii.control),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  icon: Icon(Icons.edit_outlined, size: 15, color: context.k.brand),
                  label: Text(
                    'Sửa',
                    style: TextStyle(
                      color: context.k.brand,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _openEditDialog(item),
                ),
              ),
              const SizedBox(height: 8),

              // Nút Xóa
              SizedBox(
                height: 34,
                width: 78,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.k.bad,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KRadii.control),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text(
                    'Xóa',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _confirmDelete(item),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
