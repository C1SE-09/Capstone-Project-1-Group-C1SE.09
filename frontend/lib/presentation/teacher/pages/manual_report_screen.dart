// frontend/lib/presentation/teacher/pages/manual_report_screen.dart
// ============================================================================
// ManualReportScreen (Task #83 - Manual Report Creation Form)
// ============================================================================

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/presentation/recording/pages/extraction_results_screen.dart';
import 'package:flutter/material.dart';

class ManualReportScreen extends StatefulWidget {
  const ManualReportScreen({
    super.key,
    required this.child,
    this.teacherId,
    this.classId,
    TeacherRepositoryBase? repository,
  }) : _repository = repository;

  final Child child;
  final String? teacherId;
  final String? classId;
  final TeacherRepositoryBase? _repository;

  @override
  State<ManualReportScreen> createState() => _ManualReportScreenState();
}

class _ManualReportScreenState extends State<ManualReportScreen> {
  late final TeacherRepositoryBase _repo;
  bool _isSubmitting = false;

  late final TextEditingController _mealsController;
  late final TextEditingController _sleepingController;
  late final TextEditingController _healthController;
  late final TextEditingController _activitiesController;
  late final TextEditingController _moodController;
  late final TextEditingController _notesController;

  String get _effectiveTeacherId =>
      widget.teacherId ?? 'bbbbbbbb-0000-0000-0000-000000000001';

  @override
  void initState() {
    super.initState();
    _repo = widget._repository ?? TeacherRepository();

    _mealsController = TextEditingController();
    _sleepingController = TextEditingController();
    _healthController = TextEditingController();
    _activitiesController = TextEditingController();
    _moodController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _mealsController.dispose();
    _sleepingController.dispose();
    _healthController.dispose();
    _activitiesController.dispose();
    _moodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitManualReport() async {
    if (_isSubmitting) return;

    final meals = _mealsController.text.trim();
    final sleeping = _sleepingController.text.trim();
    final health = _healthController.text.trim();
    final activities = _activitiesController.text.trim();
    final mood = _moodController.text.trim();
    final notes = _notesController.text.trim();

    if (meals.isEmpty &&
        sleeping.isEmpty &&
        health.isEmpty &&
        activities.isEmpty &&
        mood.isEmpty &&
        notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập ít nhất một mục nội dung báo cáo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _repo.createManualReport(
        teacherId: _effectiveTeacherId,
        childId: widget.child.childId,
        eating: meals.isNotEmpty ? meals : null,
        sleeping: sleeping.isNotEmpty ? sleeping : null,
        health: health.isNotEmpty ? health : null,
        activities: activities.isNotEmpty ? activities : null,
        mood: mood.isNotEmpty ? mood : null,
        teacherNote: notes.isNotEmpty ? notes : null,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Chuyển sang ExtractionResultsScreen để rà soát bản nháp và gửi phụ huynh
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ExtractionResultsScreen(
            voiceId: 'manual-report',
            teacherId: _effectiveTeacherId,
            childId: widget.child.childId,
            childName: widget.child.fullName,
            childInitials: _initials(widget.child.fullName),
            classTeacherInfo: 'Lớp Mầm A · Cô Mai',
            initialMeals: meals,
            initialSleeping: sleeping,
            initialHealth: health,
            initialActivities: activities,
            initialMood: mood,
            initialNotes: notes,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final errorMessage = e is TeacherRepositoryException
          ? e.message
          : 'Không thể tạo báo cáo thủ công. Vui lòng thử lại.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF9F8F3);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E2522)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tạo báo cáo thủ công',
          style: TextStyle(
            color: Color(0xFF1E2522),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header thẻ học sinh được chọn
                    _buildChildHeaderCard(),
                    const SizedBox(height: 16),

                    // Notice Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.edit_document,
                            color: Color(0xFF1B6E60),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nhập trực tiếp các thông tin nhật ký hoạt động cho ${widget.child.displayName}.',
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF47544C),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 1. Ăn uống
                    _buildInputField(
                      label: 'Ăn uống',
                      icon: Icons.flatware_outlined,
                      controller: _mealsController,
                      hintText: 'Ví dụ: Ăn hết suất, ăn ngoan...',
                    ),
                    const SizedBox(height: 16),

                    // 2. Giấc ngủ
                    _buildInputField(
                      label: 'Giấc ngủ',
                      icon: Icons.nightlight_round_outlined,
                      controller: _sleepingController,
                      hintText: 'Ví dụ: Ngủ 2 tiếng, ngủ ngon...',
                    ),
                    const SizedBox(height: 16),

                    // 3. Sức khỏe
                    _buildInputField(
                      label: 'Sức khỏe',
                      icon: Icons.favorite_border_rounded,
                      controller: _healthController,
                      hintText: 'Ví dụ: Sức khỏe bình thường...',
                    ),
                    const SizedBox(height: 16),

                    // 4. Hoạt động
                    _buildInputField(
                      label: 'Hoạt động',
                      icon: Icons.grid_view_rounded,
                      controller: _activitiesController,
                      hintText: 'Ví dụ: Chơi ngoan với các bạn...',
                    ),
                    const SizedBox(height: 16),

                    // 5. Tâm trạng
                    _buildInputField(
                      label: 'Tâm trạng',
                      icon: Icons.sentiment_satisfied_alt_outlined,
                      controller: _moodController,
                      hintText: 'Ví dụ: Vui vẻ, hào hứng...',
                    ),
                    const SizedBox(height: 16),

                    // 6. Ghi chú
                    _buildInputField(
                      label: 'Ghi chú giáo viên',
                      icon: Icons.edit_note_rounded,
                      controller: _notesController,
                      hintText: 'Ví dụ: Lời nhắn dành cho phụ huynh...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Action Container
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF9F8F3),
                border: Border(top: BorderSide(color: Color(0xFFEFECE6))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitManualReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C4D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Tạo báo cáo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE1DE)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              _initials(widget.child.fullName),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.child.fullName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Lớp Mầm 1 · Tạo báo cáo thủ công',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF5E6560)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF434A45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : 1,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1E2522),
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFFA0A6A2),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDCE1DE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF0D5C4D),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
