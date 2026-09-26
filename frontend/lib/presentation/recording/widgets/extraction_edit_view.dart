// frontend/lib/presentation/recording/widgets/extraction_edit_view.dart
// ============================================================================
// Giao diện 1: Thông tin đã nhận diện (6 form fields + "Tạo báo cáo")
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ExtractionEditView extends StatelessWidget {
  const ExtractionEditView({
    super.key,
    required this.transcriptController,
    required this.mealsController,
    required this.sleepingController,
    required this.healthController,
    required this.activitiesController,
    required this.moodController,
    required this.notesController,
    required this.onGoToReview,
    this.onReanalyze,
    this.hasAnalysis = false,
    this.onTranscriptChanged,
    this.isSubmitting = false,
    this.isReanalyzing = false,
  });

  final TextEditingController transcriptController;
  final TextEditingController mealsController;
  final TextEditingController sleepingController;
  final TextEditingController healthController;
  final TextEditingController activitiesController;
  final TextEditingController moodController;
  final TextEditingController notesController;
  final VoidCallback onGoToReview;

  /// Chạy lại model phân tích trên transcript đã chỉnh sửa.
  final VoidCallback? onReanalyze;
  final bool hasAnalysis;
  final VoidCallback? onTranscriptChanged;
  final bool isSubmitting;
  final bool isReanalyzing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Top Navigation Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  size: 28,
                  color: Color(0xFF2C322E),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.extractionResults,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2522),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.checkBeforeCreate,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF757B77),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Scrollable Input Fields
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF1B6E60),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.checkTranscript,
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

                // Transcript Field (read-only, raw PhoWhisper output)
                _buildInputField(
                  label: l10n.transcriptField,
                  icon: Icons.text_fields_rounded,
                  controller: transcriptController,
                  readOnly: true,
                  maxLines: 3,
                  hint: l10n.noTranscriptData,
                ),
                const SizedBox(height: 20),

                ...[
                  Text(
                    l10n.extractionTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF757B77),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. Ăn uống (kết quả model - chỉ đọc)
                  _buildInputField(
                    label: l10n.meals,
                    icon: Icons.flatware_outlined,
                    controller: mealsController,
                  ),
                  const SizedBox(height: 16),

                  // 2. Giấc ngủ
                  _buildInputField(
                    label: l10n.sleeping,
                    icon: Icons.nightlight_round_outlined,
                    controller: sleepingController,
                  ),
                  const SizedBox(height: 16),

                  // 3. Sức khỏe
                  _buildInputField(
                    label: l10n.health,
                    icon: Icons.favorite_border_rounded,
                    controller: healthController,
                  ),
                  const SizedBox(height: 16),

                  // 4. Hoạt động
                  _buildInputField(
                    label: l10n.activities,
                    icon: Icons.grid_view_rounded,
                    controller: activitiesController,
                  ),
                  const SizedBox(height: 16),

                  // 5. Tâm trạng
                  _buildInputField(
                    label: l10n.mood,
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    controller: moodController,
                  ),
                  const SizedBox(height: 16),

                  // 6. Ghi chú
                  _buildInputField(
                    label: l10n.notes,
                    icon: Icons.edit_note_rounded,
                    controller: notesController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),

        // Bottom Action Container: "Tạo báo cáo" & "Hủy báo cáo" (Placeholder)
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF9F8F3),
            border: Border(top: BorderSide(color: Color(0xFFEFECE6))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onGoToReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C4D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSubmitting
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    // Placeholder: Chức năng hủy báo cáo sẽ được triển khai sau
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFF5E6560),
                    side: const BorderSide(color: Color(0xFFDCE1DE)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.cancelReport,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    int maxLines = 1,
    String? hint,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
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
            if (readOnly) ...[
              const Spacer(),
              const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: Color(0xFFA0A6A2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : 1,
          readOnly: readOnly,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 15,
            color: readOnly ? const Color(0xFF5E6560) : const Color(0xFF1E2522),
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly ? const Color(0xFFF4F4F1) : Colors.white,
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFA0A6A2)),
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
              borderSide: BorderSide(
                color: readOnly
                    ? const Color(0xFFDCE1DE)
                    : const Color(0xFF0D5C4D),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
