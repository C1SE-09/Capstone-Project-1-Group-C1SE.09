import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:adark_frontend/core/utils/device_info_helper.dart';
import 'package:adark_frontend/data/repositories/http_bug_report_repository.dart';
import 'package:adark_frontend/domain/entities/bug_report/bug_report.dart';
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
  int _selectedTab = 0; // 0: Gửi báo cáo, 1: Lịch sử báo cáo

  // Form controllers & state
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  BugCategory _selectedCategory = BugCategory.ui;
  BugSeverity _selectedSeverity = BugSeverity.medium;
  final List<BugReportAttachmentDraft> _attachments = [];

  bool _isSubmitting = false;
  String? _formError;

  // History state
  bool _isLoadingHistory = false;
  List<BugReport> _myReports = [];
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadMyReports();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMyReports() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final res = await widget.repository.listMyReports(page: 1, pageSize: 50);
      if (mounted) {
        setState(() {
          _myReports = res.items;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _historyError = 'Không thể tải lịch sử báo lỗi. Vui lòng thử lại.';
        });
      }
    }
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
        category: _selectedCategory,
        severity: _selectedSeverity,
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
          content: Text('Báo cáo lỗi đã được gửi thành công! Cảm ơn đóng góp của bạn.'),
        ),
      );

      // Reset form
      _titleController.clear();
      _descriptionController.clear();
      _attachments.clear();
      _selectedCategory = BugCategory.ui;
      _selectedSeverity = BugSeverity.medium;

      // Reload history & switch to tab history
      _loadMyReports();
      setState(() {
        _isSubmitting = false;
        _selectedTab = 1;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _formError = e is BugReportException
              ? e.message
              : 'Gửi báo cáo thất bại. Vui lòng kiểm tra kết nối mạng và thử lại.';
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
                    child: Icon(Icons.bug_report_rounded, color: k.brand, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Báo cáo lỗi & Góp ý',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: k.ink,
                          ),
                        ),
                        Text(
                          'Phản hồi vấn đề kỹ thuật đến đội ngũ phát triển',
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

            // Tabs Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: k.surfaceSunken,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Gửi báo cáo',
                        icon: Icons.edit_note_rounded,
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: _myReports.isEmpty ? 'Lịch sử' : 'Lịch sử (${_myReports.length})',
                        icon: Icons.history_rounded,
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: k.line),

            // Body
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _selectedTab == 0 ? _buildFormTab() : _buildHistoryTab(),
              ),
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

            // Tiêu đề lỗi
            _buildFieldLabel('Tiêu đề sự cố *'),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Tóm tắt ngắn gọn vấn đề (ví dụ: Không xem được ảnh điểm danh)',
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
                  return 'Vui lòng nhập tiêu đề sự cố';
                }
                if (val.trim().length > 200) {
                  return 'Tiêu đề không được vượt quá 200 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phân loại (Category)
            _buildFieldLabel('Phân loại vấn đề'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BugCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat.label),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? k.brandStrong : k.inkSoft,
                  ),
                  selected: isSelected,
                  selectedColor: k.brandTint,
                  backgroundColor: k.surfaceSunken,
                  side: BorderSide(
                    color: isSelected ? k.brand : k.line,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Mức độ nghiêm trọng (Severity)
            _buildFieldLabel('Mức độ ảnh hưởng'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BugSeverity.values.map((sev) {
                final isSelected = _selectedSeverity == sev;
                final (color, bg) = _severityColors(sev, k);
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                      const SizedBox(width: 6),
                      Text(sev.label),
                    ],
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? color : k.inkSoft,
                  ),
                  selected: isSelected,
                  selectedColor: bg,
                  backgroundColor: k.surfaceSunken,
                  side: BorderSide(
                    color: isSelected ? color : k.line,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (val) {
                    if (val) setState(() => _selectedSeverity = sev);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Mô tả chi tiết
            _buildFieldLabel('Mô tả chi tiết *'),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Mô tả cụ thể các bước bạn đã làm trước khi lỗi xuất hiện, nội dung lỗi hiển thị...',
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
                _buildFieldLabel('Ảnh chụp màn hình (tối đa 5 ảnh)'),
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
                      'Hệ thống sẽ tự động đính kèm thông tin thiết bị và phiên bản ứng dụng để kỹ thuật viên xử lý nhanh hơn.',
                      style: TextStyle(fontSize: 11, color: k.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            KButton(
              label: _isSubmitting ? 'Đang gửi...' : 'Gửi báo cáo lỗi',
              icon: _isSubmitting ? null : Icons.send_rounded,
              large: true,
              onPressed: _isSubmitting ? null : _submitReport,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TAB 2: LỊCH SỬ BÁO CÁO CỦA TÔI
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHistoryTab() {
    final k = context.k;

    if (_isLoadingHistory) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: k.brand),
            const SizedBox(height: 12),
            Text('Đang tải lịch sử...', style: TextStyle(fontSize: 13, color: k.inkSoft)),
          ],
        ),
      );
    }

    if (_historyError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 36, color: k.warn),
            const SizedBox(height: 8),
            Text(_historyError!, style: TextStyle(fontSize: 13, color: k.inkSoft)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadMyReports,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_myReports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: k.surfaceSunken, shape: BoxShape.circle),
                child: Icon(Icons.playlist_add_check_rounded, size: 36, color: k.inkFaint),
              ),
              const SizedBox(height: 12),
              Text(
                'Chưa có báo cáo nào',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: k.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Các sự cố bạn báo cáo sẽ được hiển thị tại đây kèm trạng thái cập nhật từ ban quản trị.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: k.inkSoft),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyReports,
      color: k.brand,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _myReports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final report = _myReports[idx];
          return _ReportHistoryCard(report: report);
        },
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

  (Color, Color) _severityColors(BugSeverity sev, KPalette k) {
    return switch (sev) {
      BugSeverity.low => (k.inkSoft, k.surfaceSunken),
      BugSeverity.medium => (k.info, k.infoTint),
      BugSeverity.high => (k.warn, k.warnTint),
      BugSeverity.critical => (k.bad, k.badTint),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? k.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? k.brand : k.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? k.brand : k.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportHistoryCard extends StatefulWidget {
  const _ReportHistoryCard({required this.report});

  final BugReport report;

  @override
  State<_ReportHistoryCard> createState() => _ReportHistoryCardState();
}

class _ReportHistoryCardState extends State<_ReportHistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final r = widget.report;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(r.createdAt.toLocal());

    final (statusLabel, statusColor, statusBg) = switch (r.status) {
      BugStatus.open => ('Mới gửi', k.info, k.infoTint),
      BugStatus.inProgress => ('Đang xử lý', k.warn, k.warnTint),
      BugStatus.resolved => ('Đã sửa', k.ok, k.okTint),
      BugStatus.closed => ('Đã đóng', k.inkSoft, k.surfaceSunken),
      BugStatus.wontFix => ('Không sửa', k.bad, k.badTint),
    };

    return Container(
      decoration: BoxDecoration(
        color: k.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: k.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      r.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: k.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    r.category.label,
                    style: TextStyle(fontSize: 12, color: k.inkSoft, fontWeight: FontWeight.w500),
                  ),
                  Text(' • ', style: TextStyle(color: k.inkFaint)),
                  Text(
                    'Mức độ: ${r.severity.label}',
                    style: TextStyle(fontSize: 12, color: k.inkSoft),
                  ),
                  if (r.attachmentCount > 0) ...[
                    Text(' • ', style: TextStyle(color: k.inkFaint)),
                    Icon(Icons.attach_file, size: 14, color: k.inkSoft),
                    Text('${r.attachmentCount}', style: TextStyle(fontSize: 12, color: k.inkSoft)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dateStr,
                style: TextStyle(fontSize: 11, color: k.inkFaint),
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: k.line),
                const SizedBox(height: 10),
                Text(
                  'Chi tiết sự cố:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: k.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  r.description,
                  style: TextStyle(fontSize: 13, color: k.inkSoft, height: 1.4),
                ),
                if (r.teacher != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Giáo viên phụ trách: ${r.teacher!.fullName}',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: k.brand),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
