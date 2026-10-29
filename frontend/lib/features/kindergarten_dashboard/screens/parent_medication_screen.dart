import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_detail_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_form_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';

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
                              status: 'given')),
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
  Widget _batch(MedicationBatch batch) => MedicationCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MedicationBatchHeading(batch),
        if (batch.isLegacy) ...[
          const SizedBox(height: 9),
          const Text('Hồ sơ cũ theo buổi; không có giờ uống cụ thể.')
        ] else
          for (final dose in batch.doses.take(3)) ...[
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                  child: Text(doseWhen(dose),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700))),
              Flexible(
                  child: MedicationBadge(doseStatus(dose.status),
                      status: dose.status))
            ]),
            if (dose.isGiven)
              Text(
                  '${dose.givenByName ?? 'Chưa rõ người xác nhận'}${dose.givenAt == null ? '' : ' · ${requestTimestamp(dose.givenAt!)}'}',
                  style: TextStyle(fontSize: 11, color: context.k.inkSoft)),
          ],
        if (batch.doses.length > 3) ...[
          const SizedBox(height: 8),
          Text('Đợt có ${batch.doses.length} cữ; xem đầy đủ trong chi tiết.')
        ],
        const SizedBox(height: 12),
        MedicationAction(
            label: 'Xem chi tiết đợt', onPressed: () => _detail(batch)),
      ]));
}
