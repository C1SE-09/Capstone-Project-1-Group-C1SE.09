import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/core/notifications/emergency_siren_service.dart';
import 'package:adark_frontend/core/utils/phone_utils.dart';
import 'package:adark_frontend/domain/entities/health/emergency_alert_data.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/requests/parent_requests_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart'
    show KButton;

class EmergencyAlertSummaryScreen extends StatefulWidget {
  const EmergencyAlertSummaryScreen({
    super.key,
    required this.alert,
    this.onDismiss,
  });

  final EmergencyAlertData alert;
  final VoidCallback? onDismiss;

  static Future<void> showModal(
    BuildContext context,
    EmergencyAlertData alert,
  ) async {
    EmergencySirenService.instance.playSiren();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Emergency Alert',
      barrierColor: context.k.ink.withValues(alpha: 0.75),
      pageBuilder: (dialogContext, _, __) => PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: GardenVoiceScope(
            child: EmergencyAlertSummaryScreen(
              alert: alert,
              onDismiss: () => Navigator.of(
                dialogContext,
                rootNavigator: true,
              ).pop(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<EmergencyAlertSummaryScreen> createState() =>
      _EmergencyAlertSummaryScreenState();
}

class _EmergencyAlertSummaryScreenState
    extends State<EmergencyAlertSummaryScreen> {
  @override
  void initState() {
    super.initState();
    EmergencySirenService.instance.playSiren();
  }

  Future<void> _callTeacher() async {
    final phone = widget.alert.teacherPhone.trim();
    final uri = phoneCallUri(phone);
    if (uri == null) return;

    await EmergencySirenService.instance.stopSiren();
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Giữ thông tin liên hệ để phụ huynh có thể sao chép nếu OS từ chối mở.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n?.cannotOpenPhoneCallApp ??
            'Không thể mở ứng dụng gọi điện.'),
        backgroundColor: context.k.bad,
        action: SnackBarAction(
          label: context.l10n?.copyAction ?? 'Sao chép',
          textColor: context.k.surface,
          onPressed: () => Clipboard.setData(ClipboardData(text: phone)),
        ),
      ),
    );
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
    final phone = phoneCallUri(alert.teacherPhone);
    final date = alert.createdAt;
    final time = date == null
        ? (context.l10n?.noTimeAvailable ?? 'Chưa có thời điểm')
        : DateFormat('HH:mm').format(
            date.toUtc().add(const Duration(hours: 7)),
          );
    final description = alert.description?.trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleDismiss();
      },
      child: ParentRequestLayout(
        title: context.l10n?.emergencyAlertTitle ?? 'Cảnh báo khẩn',
        gardenVoice: true,
        onBack: _handleDismiss,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(time,
                  style: TextStyle(fontSize: 12, color: context.k.inkSoft)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: context.k.badTint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.childName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.k.badText,
                        )),
                    Text(alert.incidentType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.k.bad,
                        )),
                    const SizedBox(height: 4),
                    Text(
                        context.l10n
                                ?.teacherSentIncidentNotice(alert.teacherName) ??
                            '${alert.teacherName} vừa gửi thông báo sự cố.',
                        style: const TextStyle(fontSize: 15, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: context.k.surfaceSunken,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        context.l10n?.teacherContentHeader ??
                            'Nội dung từ giáo viên',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.k.brand,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      description == null || description.isEmpty
                          ? (context.l10n?.noTeacherDescription ??
                              'Chưa có mô tả từ giáo viên.')
                          : description,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                    if (alert.temperature?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                          context.l10n?.temperatureDegrees(
                                  alert.temperature!) ??
                              'Nhiệt độ · ${alert.temperature}°C',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.k.inkSoft,
                          )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              KButton(
                label: context.l10n?.callTeacherAction(alert.teacherName) ??
                    'Gọi cho ${alert.teacherName}',
                onPressed: phone == null ? null : _callTeacher,
              ),
              if (phone == null) ...[
                const SizedBox(height: 6),
                Text(
                    context.l10n?.noValidPhoneNumberInContacts ??
                        'Chưa có số điện thoại hợp lệ',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: context.k.inkSoft)),
              ],
              const SizedBox(height: 10),
              KButton(
                label: context.l10n?.acknowledgedDismissSiren ??
                    'Đã nắm thông tin · Tắt chuông',
                secondary: true,
                onPressed: _handleDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
