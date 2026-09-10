// frontend/lib/presentation/screens/extraction_results_screen.dart
// ============================================================================
// Task #55: ExtractionResultsScreen
//
// Features:
//   - Displays AI-extracted structured data with 5 fields:
//       1. Meals (Bữa ăn)
//       2. Sleeping (Giấc ngủ)
//       3. Health (Sức khỏe)
//       4. Activities (Hoạt động)
//       5. Mood (Tâm trạng)
//   - Visual indicators (emojis, badges, colored icons)
//   - Edit mode to correct values before confirming
//   - "Xác nhận" -> calls /api/teacher/reports/draft to create draft report
//   - "Ghi âm lại" -> pops back to recording
// ============================================================================

import 'package:adark_frontend/data/repositories/teacher_repository.dart';
import 'package:flutter/material.dart';

class ExtractionResultsScreen extends StatefulWidget {
  const ExtractionResultsScreen({
    super.key,
    required this.voiceId,
    required this.teacherId,
    TeacherRepositoryBase? repository,
  }) : _repository = repository;

  final String voiceId;
  final String teacherId;
  final TeacherRepositoryBase? _repository;

  @override
  State<ExtractionResultsScreen> createState() =>
      _ExtractionResultsScreenState();
}

class _ExtractionResultsScreenState extends State<ExtractionResultsScreen> {
  late final TeacherRepositoryBase _repo;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isEditing = false;
  String? _errorMessage;

  // Controllers for the 5 structured fields
  late final TextEditingController _mealsController;
  late final TextEditingController _sleepingController;
  late final TextEditingController _healthController;
  late final TextEditingController _activitiesController;
  late final TextEditingController _moodController;

  @override
  void initState() {
    super.initState();
    _repo = widget._repository ?? TeacherRepository();

    _mealsController = TextEditingController();
    _sleepingController = TextEditingController();
    _healthController = TextEditingController();
    _activitiesController = TextEditingController();
    _moodController = TextEditingController();

    _fetchExtraction();
  }

  @override
  void dispose() {
    _mealsController.dispose();
    _sleepingController.dispose();
    _healthController.dispose();
    _activitiesController.dispose();
    _moodController.dispose();
    super.dispose();
  }

  Future<void> _fetchExtraction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final extraction = await _repo.extractVoice(
        voiceId: widget.voiceId,
        teacherId: widget.teacherId,
      );

      if (!mounted) return;
      setState(() {
        _mealsController.text = extraction.meals ?? 'Không có thông tin';
        _sleepingController.text = extraction.sleeping ?? 'Không có thông tin';
        _healthController.text = extraction.health ?? 'Bình thường';
        _activitiesController.text = extraction.activities ?? 'Không có thông tin';
        _moodController.text = extraction.mood ?? 'Vui vẻ';
        _isLoading = false;
      });
    } on TeacherRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndCreateDraft() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final editedExtraction = ExtractionData(
        meals: _mealsController.text.trim(),
        sleeping: _sleepingController.text.trim(),
        health: _healthController.text.trim(),
        activities: _activitiesController.text.trim(),
        mood: _moodController.text.trim(),
      );

      await _repo.createDraftReport(
        voiceId: widget.voiceId,
        teacherId: widget.teacherId,
        editedExtraction: editedExtraction,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Đã gửi thông báo cho phụ huynh thành công!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Return back to teacher dashboard / home
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on TeacherRepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tạo báo cáo thất bại: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Kết quả trích xuất AI'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        actions: [
          if (!_isLoading && _errorMessage == null)
            IconButton(
              icon: Icon(
                _isEditing ? Icons.check_circle : Icons.edit_note_rounded,
                color: _isEditing ? colorScheme.primary : colorScheme.onSurface,
              ),
              tooltip: _isEditing ? 'Hoàn tất sửa' : 'Chỉnh sửa kết quả',
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState(colorScheme, textTheme)
            : _errorMessage != null
                ? _buildErrorState(colorScheme, textTheme)
                : _buildContentState(colorScheme, textTheme),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AI đang trích xuất thông tin...',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Phân tích 5 hạng mục: Ăn, Ngủ, Sức khỏe, Hoạt động, Tâm trạng',
            style: tt.bodySmall?.copyWith(
              color: cs.onSurface.withAlpha((0.6 * 255).round()),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 72, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'Trích xuất thất bại',
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Lỗi không xác định.',
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _fetchExtraction,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentState(ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withAlpha((0.5 * 255).round()),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.secondary.withAlpha((0.3 * 255).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: cs.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isEditing
                              ? 'Chế độ chỉnh sửa đang bật. Bạn có thể sửa trực tiếp các thông tin bên dưới.'
                              : 'Kết quả được trích xuất tự động từ AI. Nhấn biểu tượng ✏️ ở góc trên nếu cần chỉnh sửa.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Field 1: Meals
                _buildFieldCard(
                  title: 'Bữa ăn',
                  emoji: '🍱',
                  icon: Icons.restaurant_rounded,
                  iconColor: Colors.orange,
                  controller: _mealsController,
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 16),

                // Field 2: Sleeping
                _buildFieldCard(
                  title: 'Giấc ngủ',
                  emoji: '😴',
                  icon: Icons.bedtime_rounded,
                  iconColor: Colors.indigo,
                  controller: _sleepingController,
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 16),

                // Field 3: Health
                _buildFieldCard(
                  title: 'Sức khỏe',
                  emoji: '🩺',
                  icon: Icons.health_and_safety_rounded,
                  iconColor: Colors.redAccent,
                  controller: _healthController,
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 16),

                // Field 4: Activities
                _buildFieldCard(
                  title: 'Hoạt động & Trò chơi',
                  emoji: '🎨',
                  icon: Icons.sports_esports_rounded,
                  iconColor: Colors.teal,
                  controller: _activitiesController,
                  cs: cs,
                  tt: tt,
                ),
                const SizedBox(height: 16),

                // Field 5: Mood
                _buildFieldCard(
                  title: 'Tâm trạng & Cảm xúc',
                  emoji: '😊',
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  iconColor: Colors.amber.shade800,
                  controller: _moodController,
                  cs: cs,
                  tt: tt,
                ),
              ],
            ),
          ),
        ),

        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.05 * 255).round()),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main Confirm Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _confirmAndCreateDraft,
                  icon: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isSubmitting
                        ? 'Đang gửi báo cáo...'
                        : 'Gửi báo cáo cho phụ huynh',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Re-record Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Ghi âm lại'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldCard({
    required String title,
    required String emoji,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEditing
              ? cs.primary.withAlpha((0.5 * 255).round())
              : cs.outlineVariant.withAlpha((0.4 * 255).round()),
          width: _isEditing ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                '$emoji $title',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Editable or Read-only Field
          TextFormField(
            controller: controller,
            enabled: _isEditing,
            maxLines: null,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _isEditing
                  ? cs.surfaceContainerHighest.withAlpha((0.5 * 255).round())
                  : Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: _isEditing
                    ? BorderSide(color: cs.primary)
                    : BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
              disabledBorder: InputBorder.none,
              contentPadding: _isEditing
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                  : EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
