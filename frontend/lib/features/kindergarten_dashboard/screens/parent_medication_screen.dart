import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';
import 'parent_medication_detail_screen.dart';
import 'parent_medication_form_screen.dart';
import 'parent_medication_widgets.dart';
import 'parent_requests_widgets.dart';

class ParentMedicationScreen extends StatefulWidget {
  const ParentMedicationScreen(
      {super.key,
      required this.child,
      required this.className,
      this.repository,
      this.imagePicker});
  final Child child;
  final String className;
  final HttpMedicationRepository? repository;
  final ImagePicker? imagePicker;
  @override
  State<ParentMedicationScreen> createState() => _ParentMedicationScreenState();
}

class _ParentMedicationScreenState extends State<ParentMedicationScreen> {
  late HttpMedicationRepository _repository;
  late Future<List<MedicationDose>> _rows;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _repository = widget.repository ?? HttpMedicationRepository();
    _rows = _repository.getMedicationRequests(childId: widget.child.childId);
  }

  @override
  void didUpdateWidget(covariant ParentMedicationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.childId != widget.child.childId ||
        oldWidget.repository != widget.repository) {
      _reset();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _rows = _repository.getMedicationRequests(childId: widget.child.childId);
    });
    try {
      await _rows;
    } catch (_) {/* Hiển thị lỗi qua FutureBuilder. */}
  }

  Future<void> _create() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => ParentMedicationFormScreen(
            child: widget.child,
            className: widget.className,
            repository: _repository,
            imagePicker: widget.imagePicker)));
    if (mounted) await _reload();
  }

  Future<void> _detail(MedicationBatch batch) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => ParentMedicationDetailScreen(
            child: widget.child,
            className: widget.className,
            batchId: batch.id,
            repository: _repository)));
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) => ParentRequestLayout(
      title: 'Dặn dò uống thuốc',
      child: FutureBuilder<List<MedicationDose>>(
          future: _rows,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Đang tải đợt thuốc'));
            }
            final groups = <String, List<MedicationDose>>{};
            for (final row in snapshot.data ?? <MedicationDose>[]) {
              groups.putIfAbsent(row.batchId ?? row.id, () => []).add(row);
            }
            return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Align(
                          alignment: Alignment.centerLeft,
                          child: MedicationBadge(
                              'Bé ${widget.child.fullName} · ${widget.className}',
                              tone: MedicationTone.brand)),
                      const SizedBox(height: 13),
                      if (snapshot.hasError)
                        ParentRequestError(medicationError(snapshot.error!),
                            onRetry: _reload)
                      else if (groups.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('Chưa có đợt thuốc của bé.')),
                      if (!snapshot.hasError)
                        for (final entry in groups.entries) ...[
                          _batch(MedicationBatch(entry.key, entry.value)),
                          const SizedBox(height: 13)
                        ],
                      MedicationAction(
                          label: '+ Tạo đơn dặn thuốc mới', onPressed: _create),
                      const SizedBox(height: 13),
                      Text(
                          'Mỗi khung giờ là một cữ riêng để cô xác nhận độc lập. Không tự suy ra đã uống từ ngày kết thúc.',
                          style: TextStyle(
                              fontSize: 11, color: context.k.inkSoft)),
                    ]));
          }));
  Widget _batch(MedicationBatch batch) {
    // Đợt đã xong: Figma chỉ hiện một dòng ngày · người tạo, không có cữ/nút.
    final done = !batch.isLegacy && !batch.doses.any((d) => d.canCancel);
    if (done) {
      return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _detail(batch),
          child: MedicationCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                MedicationBatchHeading(batch, showRange: false),
                const SizedBox(height: 9),
                Text('${batchRange(batch)} · ${batchCreator(batch)}',
                    style: TextStyle(fontSize: 11, color: context.k.inkSoft)),
              ])));
    }
    return MedicationCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MedicationBatchHeading(batch),
      if (batch.isLegacy) ...[
        const SizedBox(height: 9),
        Text('Hồ sơ cũ theo buổi; không có giờ uống cụ thể.',
            style: TextStyle(fontSize: 11.5, color: context.k.inkSoft))
      ] else
        for (final dose in batch.doses.take(3)) ...[
          const SizedBox(height: 9),
          Row(children: [
            Expanded(
                child: Text(dose.timeSlot ?? '',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Flexible(
                child:
                    MedicationBadge(doseBadgeLabel(dose), status: dose.status))
          ]),
        ],
      if (batch.doses.length > 3) ...[
        const SizedBox(height: 8),
        Text('Đợt có ${batch.doses.length} cữ; xem đầy đủ trong chi tiết.',
            style: TextStyle(fontSize: 11, color: context.k.inkSoft))
      ],
      const SizedBox(height: 9),
      Text(batchCreator(batch),
          style: TextStyle(fontSize: 10.5, color: context.k.inkFaint)),
      const SizedBox(height: 9),
      MedicationAction(
          label: 'Xem chi tiết đợt', onPressed: () => _detail(batch)),
    ]));
  }
}
