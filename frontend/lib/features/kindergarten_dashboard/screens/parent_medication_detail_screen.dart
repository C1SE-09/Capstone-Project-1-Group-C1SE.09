import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'parent_medication_widgets.dart';
import 'parent_requests_widgets.dart';

class ParentMedicationDetailScreen extends StatefulWidget {
  const ParentMedicationDetailScreen(
      {super.key,
      required this.child,
      required this.className,
      required this.batchId,
      this.repository});
  final Child child;
  final String className, batchId;
  final HttpMedicationRepository? repository;
  @override
  State<ParentMedicationDetailScreen> createState() =>
      _ParentMedicationDetailScreenState();
}

class _ParentMedicationDetailScreenState
    extends State<ParentMedicationDetailScreen> {
  late HttpMedicationRepository _repo;
  late Future<List<MedicationDose>> _rows;
  bool _busy = false, _dialog = false;
  int _version = 0;
  String? _error, _confirmed;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _version++;
    _busy = false;
    _dialog = false;
    _repo = widget.repository ?? HttpMedicationRepository();
    _error = null;
    _confirmed = null;
    _rows = _repo.getMedicationRequests(
        childId: widget.child.childId, batchId: widget.batchId);
  }

  @override
  void didUpdateWidget(covariant ParentMedicationDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.childId != widget.child.childId ||
        oldWidget.batchId != widget.batchId ||
        oldWidget.repository != widget.repository) {
      _reset();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _rows = _repo.getMedicationRequests(
          childId: widget.child.childId, batchId: widget.batchId);
    });
    try {
      await _rows;
    } catch (_) {/* FutureBuilder cho phép tải lại. */}
  }

  Future<void> _cancel(MedicationDose dose) async {
    if (_busy || _dialog || !dose.canCancel) return;
    final version = _version;
    _dialog = true;
    final agreed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Hủy cữ thuốc ${dose.timeSlot}?'),
                content: Text(
                    'Cữ ${dose.name ?? 'thuốc'} lúc ${dose.timeSlot} ngày ${requestDate(dose.requestDate!)} của bé ${widget.child.fullName} sẽ bị hủy khỏi danh sách chờ uống của cô.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Giữ lại')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: context.k.bad),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Hủy cữ'))
                ]));
    _dialog = false;
    if (agreed != true || !mounted || version != _version) return;
    setState(() {
      _busy = true;
      _error = null;
      _confirmed = null;
    });
    try {
      await _repo.cancelMedicationRequest(dose.id);
      if (!mounted || version != _version) return;
      setState(() => _confirmed = 'Đã hủy cữ thuốc ${dose.timeSlot}.');
      await _reload();
    } catch (error) {
      if (mounted && version == _version) {
        setState(() => _error = medicationError(error));
        if (error is MedicationRequestException &&
            {400, 409}.contains(error.statusCode)) {
          await _reload();
        }
      }
    } finally {
      if (mounted && version == _version) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ParentRequestLayout(
      title: 'Chi tiết đợt thuốc',
      child: FutureBuilder<List<MedicationDose>>(
          future: _rows,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Đang tải cữ thuốc'));
            }
            if (snapshot.hasError) {
              return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_confirmed != null) ...[
                          Semantics(liveRegion: true, child: Text(_confirmed!)),
                          const SizedBox(height: 13)
                        ],
                        ParentRequestError(medicationError(snapshot.error!),
                            onRetry: _reload),
                      ]));
            }
            final doses = snapshot.data ?? [];
            if (doses.isEmpty) {
              return const Center(
                  child: Text('Không tìm thấy đợt thuốc của bé.'));
            }
            final batch = MedicationBatch(widget.batchId, doses);
            return RefreshIndicator(
                onRefresh: _reload,
                child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MedicationCard(child: MedicationBatchHeading(batch)),
                          const SizedBox(height: 13),
                          if (_error != null) ...[
                            Semantics(
                                liveRegion: true,
                                child: Text(_error!,
                                    style: TextStyle(color: context.k.bad))),
                            const SizedBox(height: 13)
                          ],
                          if (doses.first.imageUrl != null) ...[
                            MedicationPrivateImage(
                                path: doses.first.imageUrl!, repository: _repo),
                            const SizedBox(height: 13)
                          ],
                          for (final dose in batch.doses) ...[
                            MedicationCard(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(doseWhen(dose),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700))),
                                    Flexible(
                                        child: MedicationBadge(
                                            doseStatus(dose.status),
                                            status: dose.status))
                                  ]),
                                  const SizedBox(height: 9),
                                  if (dose.isGiven)
                                    Text(
                                        '${dose.givenByName ?? 'Chưa rõ người xác nhận'} đã cho uống'
                                        '${dose.givenAt == null ? ' · chưa có thời điểm trong hồ sơ' : ' lúc ${requestTimestamp(dose.givenAt!)}'}',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: context.k.inkSoft)),
                                  if (dose.isLegacy)
                                    Text(
                                        'Buổi: ${dose.sessions.join(', ')}. Lịch cũ không ghi giờ cụ thể; liên hệ giáo viên khi cần thay đổi.'),
                                  if (!dose.isLegacy) ...[
                                    const SizedBox(height: 9),
                                    MedicationAction(
                                        label: 'Hủy cữ này',
                                        danger: true,
                                        busy: _busy && dose.canCancel,
                                        onPressed: !_busy && dose.canCancel
                                            ? () => _cancel(dose)
                                            : null),
                                    const SizedBox(height: 9),
                                    Text(
                                        dose.isGiven
                                            ? 'Đã cho uống — không thể hủy cữ đã được xác nhận.'
                                            : dose.status == 'cancelled'
                                                ? 'Cữ đã được hủy.'
                                                : 'Chỉ hủy được khi cô chưa xác nhận cho uống.',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: dose.isGiven
                                                ? context.k.bad
                                                : context.k.inkSoft))
                                  ],
                                ])),
                            const SizedBox(height: 13),
                          ],
                        ])));
          }));
}
