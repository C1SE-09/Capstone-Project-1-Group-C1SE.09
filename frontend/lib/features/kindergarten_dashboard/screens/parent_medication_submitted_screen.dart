import 'package:adark_frontend/domain/entities/health/medication_request.dart';
import 'package:flutter/material.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';

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
            const SizedBox(height: 13),
            MedicationCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  MedicationBatchHeading(
                      MedicationBatch(result.batchId, result.items)),
                  const SizedBox(height: 12),
                  Text('Hệ thống đã tạo ${result.items.length} cữ riêng:'),
                  for (final dose in result.items)
                    Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: Row(children: [
                          Expanded(
                              child: Text(doseWhen(dose),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          Flexible(
                              child: MedicationBadge(doseStatus(dose.status),
                                  status: dose.status)),
                        ])),
                ])),
            const SizedBox(height: 13),
            Text(
                'Giáo viên sẽ thấy các cữ theo ngày uống đã chọn. Bạn có thể theo dõi từng lần xác nhận trong chi tiết đợt thuốc.',
                style: TextStyle(fontSize: 11.5, color: context.k.inkSoft)),
            const SizedBox(height: 13),
            MedicationAction(
                label: 'Xem danh sách đợt thuốc',
                onPressed: () => Navigator.pop(context)),
          ])));
}
