// frontend/lib/features/kindergarten_dashboard/screens/emergency_alert_summary_screen.dart
// ==============================================================================
// Màn hình & Dialog hiển thị tóm tắt sự cố khẩn cấp dành cho Phụ huynh (Task #294).
// - Phát chuông cảnh báo khẩn cấp (Siren).
// - Hiển thị chi tiết sự cố: Bé, loại sự cố, thời gian, mô tả của giáo viên.
// - Nút bấm 1 chạm gọi điện thoại trực tiếp (SIM) tới giáo viên phụ trách.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:adark_frontend/core/notifications/emergency_siren_service.dart';
import 'package:adark_frontend/domain/entities/health/emergency_alert_data.dart';

class EmergencyAlertSummaryScreen extends StatefulWidget {
  const EmergencyAlertSummaryScreen({
    super.key,
    required this.alert,
    this.onDismiss,
  });

  final EmergencyAlertData alert;
  final VoidCallback? onDismiss;

  /// Hiển thị popup khẩn cấp đè lên giao diện khi app đang mở ở foreground.
  static Future<void> showModal(
    BuildContext context,
    EmergencyAlertData alert,
  ) async {
    // Phát còi hú báo động ngay khi mở dialog
    EmergencySirenService.instance.playSiren();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Emergency Alert',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (dialogContext, _, __) {
        return PopScope(
          canPop: false,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: EmergencyAlertSummaryScreen(
              alert: alert,
              onDismiss: () {
                EmergencySirenService.instance.stopSiren();
                Navigator.of(dialogContext, rootNavigator: true).pop();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  State<EmergencyAlertSummaryScreen> createState() => _EmergencyAlertSummaryScreenState();
}

class _EmergencyAlertSummaryScreenState extends State<EmergencyAlertSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Bật siren khi màn hình mount
    EmergencySirenService.instance.playSiren();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _callTeacher() async {
    // Tắt còi hú để phụ huynh đàm thoại rõ ràng
    await EmergencySirenService.instance.stopSiren();

    final phone = widget.alert.teacherPhone.trim();
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy số điện thoại của giáo viên.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tự động gọi tới $phone: $e'),
            action: SnackBarAction(
              label: 'Sao chép',
              textColor: Colors.white,
              onPressed: () => Clipboard.setData(ClipboardData(text: phone)),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleDismiss() {
    EmergencySirenService.instance.stopSiren();
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final timeFormatted = alert.createdAt != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format(alert.createdAt!)
        : 'Vừa xong';

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // ── Header cảnh báo khẩn cấp (Màu đỏ cảnh báo) ────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'CẢNH BÁO SỰ CỐ KHẨN CẤP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trường Mầm Non phát thông báo khẩn cấp lúc $timeFormatted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // ── Thân nội dung chi tiết ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thẻ thông tin bé & sự cố
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFA39E)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFFF4D4F),
                        child: Text(
                          alert.childName.isNotEmpty ? alert.childName[0].toUpperCase() : 'B',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.childName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F1F1F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4D4F),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                alert.incidentType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (alert.temperature != null && alert.temperature!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFF7875)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.thermostat, color: Color(0xFFCF1322), size: 18),
                              Text(
                                '${alert.temperature}°C',
                                style: const TextStyle(
                                  color: Color(0xFFCF1322),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Ghi chú từ giáo viên
                const Text(
                  'Diễn biến sự cố từ giáo viên:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF595959),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    (alert.description != null && alert.description!.isNotEmpty)
                        ? alert.description!
                        : 'Bé gặp sự cố sức khỏe cần phối hợp xử lý khẩn cấp.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF262626),
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Người phụ trách sơ cứu
                Row(
                  children: [
                    const Icon(Icons.person_pin, color: Color(0xFF595959), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cô giáo xử lý: ${alert.teacherName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF595959),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Nút hành động khẩn cấp ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Nút gọi điện thoại trực tiếp cho cô giáo (SIM Call)
                ElevatedButton.icon(
                  onPressed: _callTeacher,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF389E0D), // Xanh lá nổi bật
                    foregroundColor: Colors.white,
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.phone_in_talk, size: 24),
                  label: Text(
                    alert.teacherPhone.isNotEmpty
                        ? 'GỌI CHO CÔ GIÁO: ${alert.teacherPhone}'
                        : 'GỌI CHO CÔ GIÁO NGAY',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 2. Nút tắt còi báo động & đóng
                OutlinedButton.icon(
                  onPressed: _handleDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF595959),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFD9D9D9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.volume_off, size: 20),
                  label: const Text(
                    'Đã nắm thông tin & Tắt chuông',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
