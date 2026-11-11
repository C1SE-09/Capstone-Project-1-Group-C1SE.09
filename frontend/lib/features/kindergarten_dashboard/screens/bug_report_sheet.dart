import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final size = MediaQuery.sizeOf(context);
    final sheetHeight = math.max(
      0.0,
      math.min(size.height * 0.56, size.height - viewInsets.bottom),
    );

    return GardenVoiceScope(
      child: Builder(
        builder: (context) {
          final k = context.k;
          return Container(
            height: sheetHeight,
            decoration: BoxDecoration(
              color: k.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Báo lỗi & góp ý',
                              style: TextStyle(
                                color: k.ink,
                                fontSize: 16,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Đóng',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            icon: SvgPicture.asset(
                              'assets/garden_voice/parent_report_close.svg',
                              width: 44,
                              height: 44,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: _buildFormTab(context)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 1: FORM GỬI BÁO CÁO LỖI
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildFormTab(BuildContext context) {
    final k = context.k;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
            _buildFieldLabel('Tiêu đề', context),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Tóm tắt ngắn gọn góp ý hoặc vấn đề…',
                hintStyle: TextStyle(color: k.inkSoft, fontSize: 14),
                filled: true,
                fillColor: k.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: k.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: k.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
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
            _buildFieldLabel('Mô tả chi tiết', context),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Mô tả chi tiết ý kiến cải thiện hoặc sự cố gặp phải để đội ngũ hỗ trợ tốt nhất...',
                hintStyle: TextStyle(color: k.inkSoft, fontSize: 14),
                filled: true,
                fillColor: k.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: k.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: k.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 14),

            // Ảnh đính kèm
            _buildFieldLabel(
              'Ảnh đính kèm · tối đa 5 ảnh, mỗi ảnh ≤ 5MB',
              context,
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._attachments.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final att = entry.value;
                    return Container(
                      width: 64,
                      height: 64,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(12),
                      child: SvgPicture.asset(
                        'assets/garden_voice/bug_report_add.svg',
                        width: 64,
                        height: 64,
                        semanticsLabel: 'Thêm ảnh',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Submit Button
            SizedBox(
              height: 48,
              child: KButton(
                label: _isSubmitting ? 'Đang gửi...' : 'Gửi góp ý',
                onPressed: _isSubmitting ? null : _submitReport,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: context.k.ink,
        ),
      ),
    );
  }
}
