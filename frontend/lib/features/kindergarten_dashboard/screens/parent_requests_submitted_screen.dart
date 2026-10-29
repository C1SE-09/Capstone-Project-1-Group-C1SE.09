import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:flutter/material.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';

class ParentRequestSubmittedScreen extends StatelessWidget {
  const ParentRequestSubmittedScreen({super.key, required this.request});
  final LeaveRequestEntity request;

  @override
  Widget build(BuildContext context) => PopScope<ParentRequestDestination>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            Navigator.of(context).pop(ParentRequestDestination.history);
          }
        },
        child: ParentRequestLayout(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 80, 18, 24),
          children: [
            Center(
                child: CircleAvatar(
                    radius: 36,
                    backgroundColor: context.k.brand,
                    child: Icon(Icons.check,
                        size: 44,
                        color: Theme.of(context).colorScheme.onPrimary))),
            const SizedBox(height: 16),
            const Text('Đã gửi đơn thành công',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ParentRequestCard(
                child: Column(children: [
              ParentRequestInfo(
                  'Loại đơn',
                  Text(requestTypeLabel(request.requestType),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              ParentRequestInfo(
                  'Thời gian',
                  Text(requestRange(request),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              if (request.expectedArrivalTime != null)
                ParentRequestInfo('Giờ đến dự kiến',
                    Text(request.expectedArrivalTime!.substring(0, 5))),
              ParentRequestInfo(
                  'Trạng thái', ParentRequestStatus(request.status)),
            ])),
            const SizedBox(height: 12),
            Text(
                request.status == LeaveStatus.pending
                    ? 'Đơn đã được gửi, chưa được duyệt. Bạn có thể xem kết quả mới nhất trong lịch sử đơn.'
                    : 'Đơn đã được gửi. Xem lịch sử đơn để theo dõi kết quả xử lý mới nhất.',
                style: TextStyle(fontSize: 12, color: context.k.inkSoft)),
            const SizedBox(height: 12),
            ParentRequestButton(
                label: 'XEM ĐƠN CỦA TÔI',
                onPressed: () => Navigator.of(context)
                    .pop(ParentRequestDestination.history)),
            TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(ParentRequestDestination.home),
                child: Text('Về trang chủ',
                    style: TextStyle(color: context.k.brand, fontSize: 13))),
          ],
        )),
      );
}
