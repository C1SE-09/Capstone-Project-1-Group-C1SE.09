import 'dart:typed_data';

import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';

String medicationError(Object error) => error is MedicationRequestException
    ? error.message
    : 'Không thể tải dữ liệu thuốc. Vui lòng thử lại.';
String doseStatus(String status) => switch (status) {
      'pending' => 'Chờ uống',
      'given' => 'Đã uống',
      'cancelled' => 'Đã hủy',
      'active' => 'Lịch theo buổi',
      'completed' => 'Đã kết thúc',
      _ => 'Chưa rõ trạng thái'
    };
String doseWhen(MedicationDose dose) => dose.isLegacy
    ? 'Lịch theo buổi'
    : '${requestDate(dose.requestDate!)} · ${dose.timeSlot}';

/// Giờ Việt Nam, không lấy múi giờ máy phụ huynh.
String medicationClock(DateTime value) =>
    DateFormat('HH:mm').format(value.toUtc().add(const Duration(hours: 7)));

/// Chip cữ thuốc kèm người xác nhận và giờ, đúng mẫu Figma M1/M7.
String doseBadgeLabel(MedicationDose dose) {
  if (!dose.isGiven) return doseStatus(dose.status);
  final tail = [
    dose.givenByName,
    if (dose.givenAt != null) medicationClock(dose.givenAt!)
  ].whereType<String>().join(' ');
  return tail.isEmpty ? '✓ Đã uống' : '✓ Đã uống · $tail';
}

String batchRange(MedicationBatch batch) => batch.fromDate == null ||
        batch.toDate == null
    ? 'Chưa có đầy đủ ngày trong hồ sơ'
    : '${DateFormat('dd/MM').format(batch.fromDate!)} – ${DateFormat('dd/MM').format(batch.toDate!)}';

String batchCreator(MedicationBatch batch) {
  final first = batch.doses.first;
  final name = first.creatorName;
  final at = first.createdAt;
  // Figma xếp giờ trước ngày: "Tạo bởi Mẹ · 07:02, 28/10/2026".
  final stamp = at == null
      ? null
      : DateFormat('HH:mm, dd/MM/yyyy')
          .format(at.toUtc().add(const Duration(hours: 7)));
  return '${name == null ? 'Chưa có thông tin người tạo' : 'Tạo bởi $name'}'
      '${stamp == null ? '' : ' · $stamp'}';
}

/// Nhãn ngày theo giọng nói thường ngày, dùng cho tiêu đề cữ và hộp thoại hủy.
String medicationDay(DateTime? date) {
  if (date == null) return '';
  final today = medicationDateInVietnam(DateTime.now());
  final diff = DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(today.year, today.month, today.day))
      .inDays;
  return switch (diff) {
    0 => 'hôm nay',
    1 => 'ngày mai',
    -1 => 'hôm qua',
    _ => 'ngày ${DateFormat('dd/MM').format(date)}'
  };
}

/// "08:30 hôm nay" — đúng mẫu tiêu đề cữ trong Figma M4.
String doseTitle(MedicationDose dose) => dose.isLegacy || dose.timeSlot == null
    ? doseWhen(dose)
    : '${dose.timeSlot} ${medicationDay(dose.requestDate)}'.trim();

enum MedicationTone { brand, ok, warn, neutral }

class MedicationCard extends StatelessWidget {
  const MedicationCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.radius = 16,
  });
  final Widget child;
  final Color? color, borderColor;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: color ?? context.k.surface,
          borderRadius: BorderRadius.circular(radius),
          border: borderColor == null ? null : Border.all(color: borderColor!)),
      child: child);
}

class MedicationBadge extends StatelessWidget {
  const MedicationBadge(this.label,
      {super.key, this.status, this.tone, this.showDot = false});
  final String label;
  final String? status;
  final MedicationTone? tone;
  final bool showDot;

  MedicationTone get _tone =>
      tone ??
      switch (status) {
        'given' => MedicationTone.ok,
        'pending' => MedicationTone.warn,
        _ => MedicationTone.neutral
      };

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (ink, tint) = switch (_tone) {
      MedicationTone.brand => (k.brand, k.brandTint),
      MedicationTone.ok => (k.ok, k.okTint),
      MedicationTone.warn => (k.warn, k.warnTint),
      MedicationTone.neutral => (k.inkSoft, k.surfaceSunken)
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: tint, borderRadius: BorderRadius.circular(999)),
        child: showDot
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    key: const ValueKey('medication-status-dot'),
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: ink, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: ink)),
              ])
            : Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: ink)));
  }
}

class MedicationAction extends StatelessWidget {
  const MedicationAction(
      {super.key,
      required this.label,
      required this.onPressed,
      this.danger = false,
      this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool danger, busy;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
              backgroundColor: danger ? context.k.bad : context.k.brand,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              disabledBackgroundColor: context.k.surfaceSunken,
              disabledForegroundColor: context.k.inkSoft,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: const StadiumBorder(),
              textStyle: TextStyle(
                  fontFamily:
                      context.k.isGardenVoice ? 'Nunito' : 'BeVietnamPro',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700)),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, semanticsLabel: 'Đang xử lý'))
              : Text(label, textAlign: TextAlign.center)));
}

class MedicationBatchHeading extends StatelessWidget {
  const MedicationBatchHeading(this.batch, {super.key, this.showRange = true});
  final MedicationBatch batch;
  final bool showRange;

  @override
  Widget build(BuildContext context) {
    final first = batch.doses.first;
    final label = batch.statusLabel(medicationDateInVietnam(DateTime.now()));
    final tone = switch (label) {
      'Đang uống' || 'Chờ bắt đầu' => MedicationTone.brand,
      'Chưa hoàn tất' ||
      'Lịch theo buổi' ||
      'Chưa rõ trạng thái' =>
        MedicationTone.warn,
      _ => MedicationTone.neutral
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text('${first.name ?? 'Thuốc theo hồ sơ'} · ${first.dosage}',
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Flexible(child: MedicationBadge(label, tone: tone)),
      ]),
      if (showRange) ...[
        const SizedBox(height: 9),
        Text(
            '${batchRange(batch)}'
            '${first.notes?.isNotEmpty == true ? ' · ${first.notes}' : ''}',
            style: TextStyle(fontSize: 11.5, color: context.k.inkSoft)),
      ],
    ]);
  }
}

class MedicationPrivateImage extends StatefulWidget {
  const MedicationPrivateImage(
      {super.key, required this.path, required this.repository});
  final String path;
  final HttpMedicationRepository repository;
  @override
  State<MedicationPrivateImage> createState() => _MedicationPrivateImageState();
}

class _MedicationPrivateImageState extends State<MedicationPrivateImage> {
  Future<Uint8List>? _image;
  @override
  void didUpdateWidget(covariant MedicationPrivateImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.repository != widget.repository) {
      _image = null;
    }
  }

  void _load() => setState(() {
        _image = widget.repository.getPrescriptionBytes(widget.path);
      });
  @override
  Widget build(BuildContext context) => _image == null
      ? TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Xem ảnh đơn thuốc'))
      : FutureBuilder<Uint8List>(
          future: _image,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: CircularProgressIndicator(
                          semanticsLabel: 'Đang tải ảnh riêng tư')));
            }
            if (snapshot.hasError || snapshot.data == null) {
              return ParentRequestError(
                  snapshot.error == null
                      ? 'Không thể tải ảnh.'
                      : medicationError(snapshot.error!),
                  onRetry: _load);
            }
            return Image.memory(snapshot.data!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
                cacheWidth: 900,
                semanticLabel: 'Ảnh đơn thuốc riêng tư',
                errorBuilder: (context, error, stackTrace) =>
                    ParentRequestError('Không mở được ảnh. Vui lòng thử lại.',
                        onRetry: _load));
          });
}
