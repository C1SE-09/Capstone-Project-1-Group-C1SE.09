// frontend/lib/presentation/recording/widgets/report_sent_success_view.dart
// ============================================================================
// Giao diện 4: Đã gửi báo cáo thành công
// ============================================================================

import 'package:flutter/material.dart';

class ReportSentSuccessView extends StatelessWidget {
  const ReportSentSuccessView({
    super.key,
    required this.childName,
    required this.formattedDate,
    required this.onBackToHome,
  });

  final String childName;
  final String formattedDate;
  final VoidCallback onBackToHome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Big Success Checkmark Icon
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFFE5F2EC),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.check_rounded,
                size: 54,
                color: Color(0xFF1B6E60),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Main Heading
          const Text(
            'Đã gửi báo cáo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2522),
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle text
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14.5,
                color: Color(0xFF5E6560),
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Phụ huynh của '),
                TextSpan(
                  text: childName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2522),
                  ),
                ),
                TextSpan(
                  text: ' đã được thông báo về báo cáo ngày $formattedDate.',
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom Button: "Về trang chủ"
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onBackToHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C4D),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Về trang chủ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
