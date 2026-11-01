// Màn23 giữ hợp đồng trả lý do; không tự điền lý do mẫu của thiết kế.
import 'package:adark_frontend/domain/entities/leave_request.dart';
import 'package:flutter/material.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_medication_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_requests_widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class RejectReasonDialog extends StatefulWidget {
  const RejectReasonDialog(
      {super.key,
      required this.childName,
      this.initialReason = '',
      this.request});
  final String childName, initialReason;
  final LeaveRequestEntity? request;
  static Future<String?> show(BuildContext context,
          {required String childName,
          String initialReason = '',
          LeaveRequestEntity? request}) =>
      showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => RejectReasonDialog(
              childName: childName,
              initialReason: initialReason,
              request: request));
  @override
  State<RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<RejectReasonDialog> {
  late final _reason = TextEditingController(text: widget.initialReason);
  bool _closed = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _close(String? result) {
    if (_closed) return;
    _closed = true;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final count = _reason.text.trim().runes.length;
    return Dialog.fullscreen(
        backgroundColor: context.k.canvas,
        child: ParentRequestLayout(
            title: 'Từ chối đơn',
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MedicationCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(widget.childName,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700)),
                            if (widget.request != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                  '${requestTypeLabel(widget.request!.requestType)} · ${requestRange(widget.request!)}',
                                  style: TextStyle(
                                      fontSize: 11, color: context.k.inkSoft))
                            ],
                          ])),
                      const SizedBox(height: 14),
                      const Text('Lý do từ chối *',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      TextField(
                          controller: _reason,
                          maxLines: 3,
                          enabled: !_closed,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                              hintText:
                                  'Nhập lý do cụ thể để phụ huynh nắm thông tin',
                              filled: true,
                              fillColor: context.k.surface,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: context.k.bad)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: context.k.bad)))),
                      const SizedBox(height: 6),
                      Text('$count/500',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontSize: 10.5, color: context.k.inkFaint)),
                      const SizedBox(height: 14),
                      Text(
                          'Bắt buộc nhập lý do (2–500 ký tự). Phụ huynh xem lý do trong chi tiết đơn của bé.',
                          style: TextStyle(
                              fontSize: 11.5, color: context.k.warnDeep)),
                      const SizedBox(height: 14),
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                                onPressed: () => _close(null),
                                style: OutlinedButton.styleFrom(
                                    shape: const StadiumBorder(),
                                    minimumSize: const Size(140, 48)),
                                child: const Text('Quay lại')),
                            FilledButton(
                                onPressed: count < 2 || count > 500 || _closed
                                    ? null
                                    : () => _close(_reason.text.trim()),
                                style: FilledButton.styleFrom(
                                    backgroundColor: context.k.bad,
                                    shape: const StadiumBorder(),
                                    minimumSize: const Size(140, 48)),
                                child: const Text('Gửi từ chối')),
                          ]),
                    ]))));
  }
}
