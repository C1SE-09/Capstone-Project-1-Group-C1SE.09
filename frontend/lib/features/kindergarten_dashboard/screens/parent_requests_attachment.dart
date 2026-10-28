import 'dart:typed_data';

import 'package:adark_frontend/data/repositories/http_leave_request_repository.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'parent_requests_widgets.dart';

class ParentRequestAttachment extends StatefulWidget {
  const ParentRequestAttachment(
      {super.key, required this.path, required this.repository});
  final String path;
  final HttpLeaveRequestRepository repository;

  @override
  State<ParentRequestAttachment> createState() =>
      _ParentRequestAttachmentState();
}

class _ParentRequestAttachmentState extends State<ParentRequestAttachment> {
  late Future<Uint8List> _image;

  @override
  void initState() {
    super.initState();
    _image = widget.repository.getAttachmentBytes(widget.path);
  }

  @override
  void didUpdateWidget(covariant ParentRequestAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.repository != widget.repository) {
      _image = widget.repository.getAttachmentBytes(widget.path);
    }
  }

  void _retry() => setState(() {
        _image = widget.repository.getAttachmentBytes(widget.path);
      });

  @override
  Widget build(BuildContext context) => ParentRequestCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ảnh giấy khám / đơn thuốc',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        FutureBuilder<Uint8List>(
            future: _image,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            semanticsLabel: 'Đang tải ảnh y tế')));
              }
              if (snapshot.hasError || snapshot.data == null) {
                return ParentRequestError(
                    'Không thể tải ảnh đính kèm. Vui lòng thử lại.',
                    onRetry: _retry);
              }
              return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(snapshot.data!,
                      fit: BoxFit.contain,
                      semanticLabel: 'Ảnh y tế đính kèm đơn',
                      errorBuilder: (_, __, ___) => ParentRequestError(
                          'Không thể hiển thị ảnh đính kèm.',
                          onRetry: _retry)));
            }),
        const SizedBox(height: 8),
        Text('Ảnh y tế riêng tư, chỉ người có quyền xem đơn được truy cập.',
            style: TextStyle(fontSize: 11, color: context.k.inkSoft)),
      ]));
}
