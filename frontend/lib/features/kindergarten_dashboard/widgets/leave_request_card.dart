// frontend/lib/features/kindergarten_dashboard/widgets/leave_request_card.dart
// ============================================================================
// Thẻ hiển thị thông tin đơn xin nghỉ học của học sinh.

import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';

class LeaveRequestCard extends StatelessWidget {
  const LeaveRequestCard({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onReject,
  });

  final LeaveRequestEntity item;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final isPending = item.status == LeaveStatus.pending;
    final isApproved = item.status == LeaveStatus.approved;

    return Container(
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(KRadii.card),
        border: Border.all(color: k.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(KSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Tên + Thời gian nộp + Badge trạng thái
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: k.brandTint,
                backgroundImage: item.childAvatarUrl != null
                    ? NetworkImage(item.childAvatarUrl!)
                    : null,
                child: item.childAvatarUrl == null
                    ? Icon(Icons.person, color: k.brand)
                    : null,
              ),
              const SizedBox(width: KSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.childName ?? 'Học sinh',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: k.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phụ huynh: ${item.parentName ?? "Gia đình"} • Gửi lúc ${_formatDate(item.createdAt)}',
                      style: TextStyle(fontSize: 12, color: k.inkFaint),
                    ),
                  ],
                ),
              ),
              if (!isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isApproved ? k.okTint : k.badTint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isApproved ? 'Đã duyệt' : 'Đã từ chối',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isApproved ? k.ok : k.bad,
                    ),
                  ),
                ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpace.x2),
            child: Divider(color: k.line, height: 1),
          ),

          // Thời gian nghỉ
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: k.brand),
              const SizedBox(width: 8),
              Text(
                'Thời gian: ${_formatDate(item.fromDate)} - ${_formatDate(item.toDate)} (${item.totalDays} ngày)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: k.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Khối lý do
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KSpace.x3),
            decoration: BoxDecoration(
              color: k.surfaceSunken,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lý do xin nghỉ:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: k.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.reason,
                  style: TextStyle(fontSize: 13, color: k.ink),
                ),
                if (!isPending &&
                    item.rejectReason != null &&
                    item.rejectReason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Lý do từ chối: ${item.rejectReason}',
                    style: TextStyle(
                      fontSize: 12,
                      color: k.bad,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Hàng nút hành động nếu đang Chờ duyệt
          if (isPending) ...[
            const SizedBox(height: KSpace.x4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: k.bad,
                      side: BorderSide(color: k.bad),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: KSpace.x3),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: k.ok,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Duyệt đơn', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
