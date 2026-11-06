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
  Widget build(BuildContext context) {
    final k = context.k;
    return ParentRequestLayout(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: k.surfaceSunken, shape: BoxShape.circle),
                          child:
                              Icon(Icons.check, size: 30, color: k.inkSoft))),
                  const SizedBox(height: 14),
                  Text('Đã hủy đơn',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: k.ink)),
                  const SizedBox(height: 6),
                  Text(
                      '${request.requestType == LeaveRequestType.absence ? 'Đơn nghỉ' : 'Đơn báo trễ'} ${requestDate(request.fromDate)} · ${child.fullName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: k.inkSoft)),
                  const SizedBox(height: 14),
                  ParentRequestCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                                color: k.surfaceSunken,
                                borderRadius: BorderRadius.circular(999)),
                            child: Text('ĐÃ HỦY',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: k.inkSoft))),
                        const SizedBox(height: 10),
                        ParentRequestInfo(
                            'Loại đơn',
                            Text(
                                '${requestTypeLabel(request.requestType)} · ${request.totalDays == 1 ? '1 ngày' : '${request.totalDays} ngày'}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                        ParentRequestInfo(
                            'Ngày nghỉ',
                            Text(requestRange(request),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                      ])),
                  const SizedBox(height: 14),
                  ParentRequestCard(
                      color: k.brandTint,
                      child: Text(
                          result.rollbackedAttendance
                              ? 'Đã hoàn tác điểm danh nghỉ do đơn này tạo khi chưa check-in. Điểm danh thực tế được giữ nguyên.'
                              : 'Đã ghi nhận hủy đơn. Điểm danh thực tế được giữ nguyên; không có bản ghi tự tạo phù hợp cần hoàn tác.',
                          style: TextStyle(fontSize: 12, color: k.ink))),
                  const SizedBox(height: 14),
                  MedicationAction(
                      label: 'Về danh sách đơn',
                      onPressed: () => Navigator.maybePop(context)),
                ])));
  }
}
