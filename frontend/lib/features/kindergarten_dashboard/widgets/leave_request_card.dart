// Thẻ22: mở/thu gọn, nội dung và ETA thật; không coi báo trễ là check-in.
import 'package:adark_frontend/core/utils/phone_utils.dart';
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class LeaveRequestCard extends StatefulWidget {
  const LeaveRequestCard(
      {super.key,
      required this.item,
      required this.onApprove,
      required this.onReject,
      this.onAttachment,
      this.processing = false,
      this.initiallyExpanded = true,
      this.className});
  final LeaveRequestEntity item;
  final VoidCallback onApprove, onReject;
  final VoidCallback? onAttachment;
  final bool processing, initiallyExpanded;
  final String? className;
  @override
  State<LeaveRequestCard> createState() => _LeaveRequestCardState();
}

class _LeaveRequestCardState extends State<LeaveRequestCard> {
  late bool _open = widget.initiallyExpanded;
  Future<void> _call() async {
    final uri = phoneCallUri(widget.item.contactPhone);
    if (uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {/* Giữ thông tin liên hệ trên thẻ để giáo viên thử lại. */}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được ứng dụng gọi điện.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item, k = context.k;
    final pending = item.status == LeaveStatus.pending;
    final late = item.requestType == LeaveRequestType.lateArrival;
    final name = item.childName ?? 'Chưa có tên học sinh';
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words.reversed
        .take(2)
        .toList()
        .reversed
        .map((word) => String.fromCharCode(word.runes.first))
        .join()
        .toUpperCase();
    return MedicationCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
          button: true,
          expanded: _open,
          label: 'Chi tiết đơn của $name',
          child: InkWell(
              onTap: () => setState(() {
                    _open = !_open;
                  }),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 21,
                        backgroundColor: k.brandTint,
                        backgroundImage: item.childAvatarUrl == null
                            ? null
                            : NetworkImage(item.childAvatarUrl!),
                        child: item.childAvatarUrl == null
                            ? Text(initials,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: k.brand))
                            : null),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(
                              '${widget.className == null ? '' : '${widget.className} · '}${requestTimestamp(item.createdAt)}',
                              style: TextStyle(fontSize: 11, color: k.inkSoft)),
                        ])),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          MedicationBadge(late ? 'Báo đi trễ' : 'Xin nghỉ',
                              status: late ? 'pending' : 'given'),
                          if (!pending) ...[
                            const SizedBox(height: 4),
                            ParentRequestStatus(item.status)
                          ],
                        ])),
                    const SizedBox(width: 4),
                    Icon(_open ? Icons.expand_less : Icons.chevron_right,
                        size: 18, color: k.inkFaint),
                  ])))),
      if (_open) ...[
        const SizedBox(height: 10),
        ParentRequestInfo(
            'Ngày',
            Text(
                late
                    ? '${requestDate(item.fromDate)} · Dự kiến đến ${item.expectedArrivalTime?.split(':').take(2).join(':') ?? 'Chưa cập nhật'}'
                    : requestRange(item),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12))),
        ParentRequestInfo(late ? 'Lý do đi trễ:' : 'Lý do xin nghỉ:',
            Text(item.reason, style: const TextStyle(fontSize: 12))),
        if (item.attachmentUrl != null)
          ParentRequestInfo(
              'Đính kèm',
              TextButton(
                  onPressed: widget.onAttachment,
                  child: const Text('Xem ảnh đính kèm',
                      style: TextStyle(fontSize: 12)))),
        ParentRequestInfo(
            'SĐT liên hệ',
            TextButton(
                onPressed:
                    phoneCallUri(item.contactPhone) == null ? null : _call,
                child: Text(maskedPhone(item.contactPhone),
                    style: const TextStyle(fontSize: 12)))),
        if (item.rejectReason?.isNotEmpty == true)
          Text('Lý do từ chối: ${item.rejectReason}',
              style: TextStyle(fontSize: 12, color: k.bad)),
        if (pending) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: widget.processing ? null : widget.onReject,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: k.bad,
                        side: BorderSide(color: k.bad),
                        minimumSize: const Size(0, 48),
                        shape: const StadiumBorder()),
                    child: const Text('Từ chối'))),
            const SizedBox(width: 8),
            Expanded(
                child: MedicationAction(
                    label: 'Duyệt đơn',
                    onPressed: widget.processing ? null : widget.onApprove)),
          ])
        ],
      ],
    ]));
  }
}
