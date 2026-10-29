import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'parent_medication_widgets.dart';
import 'parent_requests_widgets.dart';

class ParentMedicationSubmittedScreen extends StatelessWidget {
  const ParentMedicationSubmittedScreen({super.key, required this.result});
  final MedicationBatchCreateResult result;
  @override
  Widget build(BuildContext context) => ParentRequestLayout(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
                child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: context.k.ok, shape: BoxShape.circle),
                    child: const Text('✓',
                        style: TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)))),
            const SizedBox(height: 9),
            const Text('Đã tạo đơn dặn thuốc',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 9),
            Text(
                '${result.items.first.name ?? result.items.first.dosage} · '
                '${batchRange(MedicationBatch(result.batchId, result.items))}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: context.k.inkSoft)),
            const SizedBox(height: 13),
            MedicationCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      'Hệ thống đã tách thành ${result.items.length} đơn riêng:',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  for (final dose in result.items)
                    Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Row(children: [
                          Expanded(
                              child: Text(dose.timeSlot ?? '',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700))),
                          const SizedBox(width: 8),
                          Flexible(
                              child: MedicationBadge(doseStatus(dose.status),
                                  status: dose.status)),
                        ])),
                  const SizedBox(height: 9),
                  Text(
                      batchCreator(
                          MedicationBatch(result.batchId, result.items)),
                      style:
                          TextStyle(fontSize: 10.5, color: context.k.inkFaint)),
                ])),
            const SizedBox(height: 13),
            Text(
                'Cô giáo sẽ thấy các cữ này trong danh sách uống thuốc hôm nay theo buổi Sáng / Trưa / Chiều.',
                style: TextStyle(fontSize: 11.5, color: context.k.inkSoft)),
            const SizedBox(height: 13),
            MedicationAction(
                label: 'Xem danh sách đợt thuốc',
                onPressed: () => Navigator.pop(context)),
          ])));
}
