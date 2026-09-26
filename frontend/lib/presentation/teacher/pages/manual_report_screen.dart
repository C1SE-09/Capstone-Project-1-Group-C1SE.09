// ============================================================================
// ManualReportScreen (Task #83 - Manual Report Creation Form)
// ============================================================================

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/presentation/recording/pages/extraction_results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
        SnackBar(
          content: Text(l10n.enterAtLeastOne),
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
            initialStep: ScreenStep.review,
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
          : l10n.cannotCreateManual;

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
    final l10n = AppLocalizations.of(context)!;
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
        title: Text(
          l10n.manualReport,
          style: const TextStyle(
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
                    _buildChildHeaderCard(l10n),
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
                              l10n.manualReportHint(widget.child.displayName),
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
                      label: l10n.meals,
                      icon: Icons.flatware_outlined,
                      controller: _mealsController,
                      hintText: l10n.mealsHint,
                    ),
                    const SizedBox(height: 16),

                    // 2. Giấc ngủ
                    _buildInputField(
                      label: l10n.sleeping,
                      icon: Icons.nightlight_round_outlined,
                      controller: _sleepingController,
                      hintText: l10n.sleepingHint,
                    ),
                    const SizedBox(height: 16),

                    // 3. Sức khỏe
                    _buildInputField(
                      label: l10n.health,
                      icon: Icons.favorite_border_rounded,
                      controller: _healthController,
                      hintText: l10n.healthHint,
                    ),
                    const SizedBox(height: 16),

                    // 4. Hoạt động
                    _buildInputField(
                      label: l10n.activities,
                      icon: Icons.grid_view_rounded,
                      controller: _activitiesController,
                      hintText: l10n.activitiesHint,
                    ),
                    const SizedBox(height: 16),

                    // 5. Tâm trạng
                    _buildInputField(
                      label: l10n.mood,
                      icon: Icons.sentiment_satisfied_alt_outlined,
                      controller: _moodController,
                      hintText: l10n.moodHint,
                    ),
                    const SizedBox(height: 16),

                    // 6. Ghi chú
                    _buildInputField(
                      label: l10n.teacherNotes,
                      icon: Icons.edit_note_rounded,
                      controller: _notesController,
                      hintText: l10n.notesHint,
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
                      : Text(
                          l10n.createReport,
                          style: const TextStyle(
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

  Widget _buildChildHeaderCard(AppLocalizations l10n) {
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
                Text(
                  l10n.manualReportChildHeader,
                  style: const TextStyle(
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
