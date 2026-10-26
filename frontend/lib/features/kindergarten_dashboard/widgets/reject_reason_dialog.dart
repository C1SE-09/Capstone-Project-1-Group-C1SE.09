// frontend/lib/features/kindergarten_dashboard/widgets/reject_reason_dialog.dart
// ==============================================================================
// Dialog nhập lý do từ chối đơn xin nghỉ học (Bắt buộc nhập lý do).

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';

class RejectReasonDialog extends StatefulWidget {
  const RejectReasonDialog({
    super.key,
    required this.childName,
  });

  final String childName;

  static Future<String?> show(BuildContext context, {required String childName}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RejectReasonDialog(childName: childName),
    );
  }

  @override
  State<RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<RejectReasonDialog> {
  late final TextEditingController _reasonController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final isValid = _reasonController.text.trim().isNotEmpty;

    return AlertDialog(
      backgroundColor: k.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadii.card),
      ),
      title: Row(
        children: [
          Icon(Icons.cancel_outlined, color: k.bad, size: 24),
          const SizedBox(width: 8),
          Text(
            'Từ chối đơn xin nghỉ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: k.ink),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bé: ${widget.childName}',
              style: TextStyle(fontWeight: FontWeight.w600, color: k.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Vui lòng nhập lý do từ chối để gửi phản hồi giải thích đến phụ huynh (Bắt buộc):',
              style: TextStyle(fontSize: 13, color: k.inkSoft),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              autofocus: true,
              style: TextStyle(color: k.ink),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Nhập lý do từ chối cụ thể...',
                hintStyle: TextStyle(fontSize: 13, color: k.inkFaint),
                filled: true,
                fillColor: k.surfaceSunken,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: k.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: k.bad),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(null),
          child: Text('Hủy bỏ', style: TextStyle(color: k.inkSoft)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: k.bad,
            foregroundColor: Colors.white,
            disabledBackgroundColor: k.line,
            disabledForegroundColor: k.inkFaint,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: (!isValid || _isSubmitting)
              ? null
              : () {
                  setState(() => _isSubmitting = true);
                  Navigator.of(context).pop(_reasonController.text.trim());
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Xác nhận từ chối'),
        ),
      ],
    );
  }
}
