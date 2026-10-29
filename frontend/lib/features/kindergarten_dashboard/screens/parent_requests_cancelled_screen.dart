import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:flutter/material.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';

/// Chỉ mở sau response đã xác minh ID và trạng thái cancelled; không bịa giờ hủy.
class ParentRequestsCancelledScreen extends StatelessWidget {
  const ParentRequestsCancelledScreen(
      {super.key,
      required this.result,
      required this.request,
      required this.child,
      required this.className});
  final LeaveRequestCancelResult result;
  final LeaveRequestEntity request;
  final Child child;
  final String className;

  @override
  Widget build(BuildContext context) => ParentRequestLayout(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(Icons.check_circle, size: 64, color: context.k.brand),
            const SizedBox(height: 14),
            const Text('Đã hủy đơn',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ParentRequestCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${child.fullName} · $className',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 9),
                  Text(
                      '${requestTypeLabel(request.requestType)} · ${requestRange(request)}'),
                  const SizedBox(height: 9),
                  Text(request.reason),
                  const SizedBox(height: 9),
                  const MedicationBadge('Đã hủy', status: 'cancelled'),
                ])),
            const SizedBox(height: 14),
            Text(
                result.rollbackedAttendance
                    ? 'Đã hoàn tác điểm danh nghỉ do đơn này tạo khi chưa check-in. Điểm danh thực tế được giữ nguyên.'
                    : 'Đã ghi nhận hủy đơn. Điểm danh thực tế được giữ nguyên; không có bản ghi tự tạo phù hợp cần hoàn tác.',
                style: TextStyle(fontSize: 12, color: context.k.inkSoft)),
            const SizedBox(height: 14),
            MedicationAction(
                label: 'Về lịch sử đơn',
                onPressed: () => Navigator.maybePop(context)),
          ])));
}
