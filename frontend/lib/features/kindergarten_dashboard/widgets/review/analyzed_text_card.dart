import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class AnalyzedTextCard extends StatefulWidget {
  const AnalyzedTextCard({
    super.key,
    required this.text,
    this.onEdit,
  });

  final String text;
  final VoidCallback? onEdit;

  @override
  State<AnalyzedTextCard> createState() => _AnalyzedTextCardState();
}

class _AnalyzedTextCardState extends State<AnalyzedTextCard> {
  bool isExpanded = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép nội dung văn bản đã phân tích.'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.k.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.k.brand.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: context.k.brand.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => isExpanded = !isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.k.brandTint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.text_snippet_outlined,
                        color: context.k.brand, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xem lại text đã phân tích',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.k.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isExpanded
                              ? 'Chạm để thu gọn'
                              : 'Chạm để xem lại toàn bộ text đã ghi âm',
                          style: TextStyle(
                              fontSize: 11, color: context.k.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: context.k.inkSoft,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.k.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.k.line),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.text,
                        style: TextStyle(
                            fontSize: 13, height: 1.55, color: context.k.ink),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.onEdit != null) ...[
                        OutlinedButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text('Sửa & Phân tích lại',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton.tonalIcon(
                        onPressed: _copy,
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text('Sao chép',
                            style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
