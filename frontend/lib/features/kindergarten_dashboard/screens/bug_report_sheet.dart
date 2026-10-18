import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:adark_frontend/core/utils/device_info_helper.dart';
import 'package:adark_frontend/data/repositories/http_bug_report_repository.dart';
import 'package:adark_frontend/domain/entities/bug_report/enums.dart';
import 'package:adark_frontend/domain/repositories/bug_report_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

/// Helper function hiển thị Modal Bottom Sheet Báo cáo lỗi & Góp ý.
Future<void> showBugReportBottomSheet(
  BuildContext context, {
  BugReportRepository? repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BugReportBottomSheet(
      repository: repository ?? HttpBugReportRepository(),
    ),
  );
}

class BugReportBottomSheet extends StatefulWidget {
  const BugReportBottomSheet({
    super.key,
    required this.repository,
  });

  final BugReportRepository repository;

  @override
  State<BugReportBottomSheet> createState() => _BugReportBottomSheetState();
}

class _BugReportBottomSheetState extends State<BugReportBottomSheet> {
  // Form controllers & state
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<BugReportAttachmentDraft> _attachments = [];

  bool _isSubmitting = false;
  String? _formError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }



  Future<void> _pickImages() async {
    if (_attachments.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chỉ có thể đính kèm tối đa 5 ảnh.')),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      final remaining = 5 - _attachments.length;
      final toAdd = pickedFiles.take(remaining);

      for (final file in toAdd) {
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File ${file.name} vượt quá 5MB cho phép.')),
            );
          }
          continue;
        }

        final mime = file.mimeType ?? 'image/jpeg';
        _attachments.add(
          BugReportAttachmentDraft(
            bytes: bytes,
            fileName: file.name,
            mimeType: mime,
          ),
        );
      }

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể chọn ảnh từ thiết bị.')),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    setState(() => _formError = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final info = await DeviceInfoHelper.collect();
      final payload = BugReportCreatePayload(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: BugCategory.other,
        severity: BugSeverity.medium,
        appVersion: info.appVersion,
        buildNumber: info.buildNumber,
        osVersion: info.osVersion,
        deviceModel: info.deviceModel,
        networkType: info.networkType,
        attachments: List.unmodifiable(_attachments),
      );

      await widget.repository.create(payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF16665A),
          content: Text('Góp ý của bạn đã được gửi thành công! Cảm ơn bạn đã đóng góp cải thiện ứng dụng.'),
        ),
      );

      // Reset form
      _titleController.clear();
      _descriptionController.clear();
      _attachments.clear();

      setState(() => _isSubmitting = false);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _formError = e is BugReportException
              ? e.message
              : 'Gửi góp ý thất bại. Vui lòng kiểm tra kết nối mạng và thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle bar
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: k.lineStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: k.brandTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.rate_review_outlined, color: k.brand, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Góp ý & Cải thiện ứng dụng',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: k.ink,
                          ),
                        ),
                        Text(
                          'Chia sẻ ý kiến đóng góp hoặc sự cố để KinderLog ngày càng tốt hơn',
                          style: TextStyle(fontSize: 12, color: k.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: k.inkSoft),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            const SizedBox(height: 12),
            Divider(height: 1, color: k.line),

            // Body
            Expanded(
              child: _buildFormTab(),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 1: FORM GỬI BÁO CÁO LỖI
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildFormTab() {
    final k = context.k;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_formError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: k.badTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: k.bad.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: k.bad, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formError!,
                        style: TextStyle(fontSize: 13, color: k.bad, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tiêu đề góp ý
            _buildFieldLabel('Tiêu đề góp ý / vấn đề *'),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Tóm tắt ngắn gọn góp ý hoặc vấn đề (ví dụ: Gợi ý thêm tính năng lưu ảnh...)',
                hintStyle: TextStyle(color: k.inkFaint, fontSize: 13),
                filled: true,
                fillColor: k.surfaceSunken,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: k.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: k.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: k.brand, width: 1.5),
                ),
              ),
              style: TextStyle(fontSize: 14, color: k.ink),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập tiêu đề góp ý hoặc vấn đề';
                }
                if (val.trim().length > 200) {
                  return 'Tiêu đề không được vượt quá 200 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),


            // Mô tả chi tiết
            _buildFieldLabel('Mô tả chi tiết *'),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Mô tả chi tiết ý kiến cải thiện hoặc sự cố gặp phải để đội ngũ hỗ trợ tốt nhất...',
                hintStyle: TextStyle(color: k.inkFaint, fontSize: 13),
                filled: true,
                fillColor: k.surfaceSunken,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: k.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: k.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: k.brand, width: 1.5),
                ),
              ),
              style: TextStyle(fontSize: 14, color: k.ink),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập mô tả chi tiết';
                }
                if (val.trim().length > 4000) {
                  return 'Mô tả không được vượt quá 4000 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Ảnh đính kèm
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFieldLabel('Ảnh minh họa (tối đa 5 ảnh)'),
                Text('${_attachments.length}/5', style: TextStyle(fontSize: 12, color: k.inkSoft)),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._attachments.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final att = entry.value;
                    return Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: k.line),
                        image: DecorationImage(
                          image: MemoryImage(att.bytes),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => _removeAttachment(idx),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_attachments.length < 5)
                    InkWell(
                      onTap: _pickImages,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: k.surfaceSunken,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: k.line, style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: k.inkSoft, size: 24),
                            const SizedBox(height: 4),
                            Text('Thêm ảnh', style: TextStyle(fontSize: 11, color: k.inkSoft)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Thông tin thiết bị tự động đính kèm
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: k.surfaceSunken,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: k.inkSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hệ thống sẽ tự động đính kèm thông tin thiết bị và phiên bản ứng dụng để hỗ trợ cải thiện trải nghiệm tốt hơn.',
                      style: TextStyle(fontSize: 11, color: k.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            KButton(
              label: _isSubmitting ? 'Đang gửi...' : 'Gửi góp ý cải thiện',
              icon: _isSubmitting ? null : Icons.send_rounded,
              large: true,
              onPressed: _isSubmitting ? null : _submitReport,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.k.ink,
        ),
      ),
    );
  }
}
