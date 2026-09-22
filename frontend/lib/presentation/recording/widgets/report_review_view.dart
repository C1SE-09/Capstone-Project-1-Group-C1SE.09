// frontend/lib/presentation/recording/widgets/report_review_view.dart
// ============================================================================
// Giao diện 2: Báo cáo hoạt động (Nguyễn Thị Nhím + "Chỉnh sửa" & "Gửi phụ huynh")
// ============================================================================

import 'package:flutter/material.dart';

class ReportReviewView extends StatelessWidget {
  const ReportReviewView({
    super.key,
    required this.childName,
    required this.childInitials,
    required this.classTeacherInfo,
    required this.formattedDate,
    required this.meals,
    required this.sleeping,
    required this.health,
    required this.activities,
    required this.mood,
    required this.notes,
    required this.onGoBackToEdit,
    required this.onOpenConfirmSheet,
  });

  final String childName;
  final String childInitials;
  final String classTeacherInfo;
  final String formattedDate;
  final String meals;
  final String sleeping;
  final String health;
  final String activities;
  final String mood;
  final String notes;
  final VoidCallback onGoBackToEdit;
  final VoidCallback onOpenConfirmSheet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
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
                onPressed: onGoBackToEdit,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Báo cáo hoạt động',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2522),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
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

        // Scrollable Review Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Child Profile Header Card
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFE2EFE9),
                      child: Text(
                        childInitials,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B6E60),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          childName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2522),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          classTeacherInfo,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF757B77),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 5 Structured Summary Cards Container
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8ECE9)),
                  ),
                  child: Column(
                    children: [
                      _buildReviewItem(
                        icon: Icons.flatware_outlined,
                        label: 'Ăn uống',
                        value: meals,
                        showDivider: true,
                      ),
                      _buildReviewItem(
                        icon: Icons.nightlight_round_outlined,
                        label: 'Giấc ngủ',
                        value: sleeping,
                        showDivider: true,
                      ),
                      _buildReviewItem(
                        icon: Icons.favorite_border_rounded,
                        label: 'Sức khỏe',
                        value: health,
                        showDivider: true,
                      ),
                      _buildReviewItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Hoạt động',
                        value: activities,
                        showDivider: true,
                      ),
                      _buildReviewItem(
                        icon: Icons.sentiment_satisfied_alt_outlined,
                        label: 'Tâm trạng',
                        value: mood,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Teacher Notes Card
                const Text(
                  'Ghi chú giáo viên',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B726E),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE8ECE9)),
                  ),
                  child: Text(
                    notes.isEmpty ? 'Không có vấn đề bất thường' : notes,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFF2C322E),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Bottom Action Bar: "Chỉnh sửa" & "Gửi phụ huynh"
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: const BoxDecoration(
            color: Color(0xFFF9F8F3),
            border: Border(top: BorderSide(color: Color(0xFFEFECE6))),
          ),
          child: Row(
            children: [
              // Button 1: Chỉnh sửa
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: onGoBackToEdit,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E2522),
                      side: const BorderSide(color: Color(0xFFDCE1DE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(
                      'Chỉnh sửa',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Button 2: Gửi phụ huynh
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onOpenConfirmSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D5C4D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.near_me_rounded, size: 18),
                    label: const Text(
                      'Gửi phụ huynh',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildReviewItem({
    required IconData icon,
    required String label,
    required String value,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF5E6560), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF757B77),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.isEmpty ? 'Bình thường' : value,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E2522),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF0F3F1),
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}
