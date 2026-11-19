// about_kinderlog_screen.dart
// =========================================================
// Màn hình / Bottom Sheet "Về KinderLog" dùng chung cho cả
// Phụ huynh và Giáo viên (Garden Voice Design System 1:1)

import 'package:flutter/material.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

/// Hiển thị Bottom Sheet "Về KinderLog"
Future<void> showAboutKinderLogSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const AboutKinderLogBottomSheet(),
  );
}

class AboutKinderLogBottomSheet extends StatelessWidget {
  const AboutKinderLogBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final size = MediaQuery.sizeOf(context);

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.88),
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: k.lineStrong,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 6),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        context.l10n?.accountAbout ?? 'Về KinderLog',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: k.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: k.brandTint,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: k.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n?.commonClose ?? 'Đóng',
                  icon: Icon(Icons.close, color: k.inkSoft, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: k.line),

          // Content body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App branding
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                k.brand,
                                const Color(0xFF5CB89D),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: k.brand.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '🌱',
                              style: TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'KinderLog',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: k.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n?.aboutAppTagline ?? 'Sổ liên lạc & Báo cáo mầm non thông minh',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: k.brand,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${context.l10n?.aboutVersionLabel ?? 'Phiên bản'} 1.0.0 (Build 2026.11)',
                          style: TextStyle(
                            fontSize: 11,
                            color: k.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // School & School Year Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: k.canvas,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: k.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🏫', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n?.aboutSchoolDefault ?? 'Trường Mầm Non Họa Mi',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: k.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n?.aboutAppDescription ?? 'Hệ thống quản trị và kết nối số toàn diện giữa Nhà trường · Giáo viên · Phụ huynh.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: k.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: k.brandTint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${context.l10n?.aboutSchoolYear ?? 'Niên khóa'}: 2026 – 2027',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: k.brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Key Features
                  Text(
                    context.l10n?.aboutKeyFeatures ?? 'TÍNH NĂNG NỔI BẬT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: k.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildFeatureTile(
                    context,
                    icon: '🎙️',
                    title: context.l10n?.aboutFeatureVoiceTitle ?? 'Giọng nói AI rảnh tay',
                    desc: context.l10n?.aboutFeatureVoiceDesc ??
                        'Giáo viên tạo báo cáo nhật ký ngày bằng giọng nói, tự động chuyển đổi văn bản và phân loại hoạt động ăn, ngủ, học.',
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureTile(
                    context,
                    icon: '📋',
                    title: context.l10n?.aboutFeatureContactBookTitle ?? 'Sổ liên lạc điện tử',
                    desc: context.l10n?.aboutFeatureContactBookDesc ??
                        'Cập nhật hoạt động từng bé theo thời gian thực; phụ huynh theo dõi và phản hồi nhận xét của cô giáo ngay trong ngày.',
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureTile(
                    context,
                    icon: '🩺',
                    title: context.l10n?.aboutFeatureHealthTitle ?? 'Hồ sơ sức khỏe & Dị ứng',
                    desc: context.l10n?.aboutFeatureHealthDesc ??
                        'Quản lý dị ứng, lịch sử khám sức khỏe định kỳ, theo dõi cân nặng, chiều cao và tự động tính toán thể trạng BMI.',
                  ),
                  const SizedBox(height: 8),
                  _buildFeatureTile(
                    context,
                    icon: '🗓️',
                    title: context.l10n?.aboutFeatureTimetableTitle ?? 'Thời khóa biểu & Xin nghỉ',
                    desc: context.l10n?.aboutFeatureTimetableDesc ??
                        'Xem lịch học tuần theo từng lớp, gửi đơn xin nghỉ trực tuyến và nhận xác nhận từ giáo viên nhanh chóng.',
                  ),
                  const SizedBox(height: 20),

                  // About & Legal links Card
                  Container(
                    decoration: BoxDecoration(
                      color: k.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: k.line),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          context,
                          label: context.l10n?.aboutDevTeam ?? 'Đội ngũ phát triển',
                          value: 'Capstone Group C1SE.09',
                        ),
                        Divider(height: 1, thickness: 1, color: k.line),
                        _buildInfoRow(
                          context,
                          label: context.l10n?.aboutTechSupport ?? 'Hỗ trợ kỹ thuật',
                          value: 'support@kinderlog.vn',
                          highlight: true,
                        ),
                        Divider(height: 1, thickness: 1, color: k.line),
                        _buildInfoRow(
                          context,
                          label: context.l10n?.aboutPrivacyPolicy ?? 'Chính sách quyền riêng tư',
                          value: context.l10n?.aboutProtected ?? 'Được bảo vệ',
                        ),
                        Divider(height: 1, thickness: 1, color: k.line),
                        _buildInfoRow(
                          context,
                          label: context.l10n?.aboutTermsOfService ?? 'Điều khoản dịch vụ',
                          value: context.l10n?.aboutCompliant ?? 'Tuân thủ quy định',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Copyright
                  Center(
                    child: Text(
                      '© 2026 KinderLog. All rights reserved.',
                      style: TextStyle(
                        fontSize: 11,
                        color: k.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required String icon,
    required String title,
    required String desc,
  }) {
    final k = context.k;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: k.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: k.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: k.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: k.line),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: k.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: k.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    bool highlight = false,
  }) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: k.ink,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: highlight ? k.brand : k.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

