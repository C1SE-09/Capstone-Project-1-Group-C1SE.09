import 'dart:typed_data';

import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'parent_requests_widgets.dart';

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

class MedicationCard extends StatelessWidget {
  const MedicationCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: context.k.surface, borderRadius: BorderRadius.circular(16)),
      child: child);
}

class MedicationBadge extends StatelessWidget {
  const MedicationBadge(this.label, {super.key, required this.status});
  final String label, status;
  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final (ink, tint) = switch (status) {
      'given' => (k.brand, k.brandTint),
      'pending' => (k.warnDeep, k.warnTint),
      _ => (k.inkSoft, k.surfaceSunken)
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: tint, borderRadius: BorderRadius.circular(30)),
        child: Text(label,
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
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                  fontFamily: 'BeVietnamPro',
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
  const MedicationBatchHeading(this.batch, {super.key});
  final MedicationBatch batch;
  @override
  Widget build(BuildContext context) {
    final first = batch.doses.first;
    final status = batch.doses.any((d) => d.status == 'pending')
        ? 'pending'
        : batch.doses.any((d) => d.isGiven)
            ? 'given'
            : 'cancelled';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text('${first.name ?? 'Thuốc theo hồ sơ'} · ${first.dosage}',
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Flexible(
            child: MedicationBadge(
                batch.statusLabel(medicationDateInVietnam(DateTime.now())),
                status: status)),
      ]),
      const SizedBox(height: 9),
      Text(
          batch.fromDate == null || batch.toDate == null
              ? 'Chưa có đầy đủ ngày trong hồ sơ'
              : '${requestDate(batch.fromDate!)} → ${requestDate(batch.toDate!)}',
          style: TextStyle(fontSize: 11.5, color: context.k.inkSoft)),
      if (first.notes?.isNotEmpty == true) ...[
        const SizedBox(height: 6),
        Text(first.notes!,
            style: TextStyle(fontSize: 11.5, color: context.k.inkSoft))
      ],
      const SizedBox(height: 9),
      Text(
          '${first.creatorName == null ? 'Chưa có thông tin người tạo' : 'Tạo bởi ${first.creatorName}'}'
          '${first.createdAt == null ? '' : ' · ${requestTimestamp(first.createdAt!)}'}',
          style: TextStyle(fontSize: 10.5, color: context.k.inkFaint)),
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
