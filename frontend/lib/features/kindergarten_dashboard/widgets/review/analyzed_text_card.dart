import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class AnalyzedTextCard extends StatefulWidget {
  const AnalyzedTextCard({
    super.key,
    required this.text,
    required this.matchedChildCount,
    this.onEdit,
  });

  final String text;
  final int matchedChildCount;
  final VoidCallback? onEdit;

  @override
  State<AnalyzedTextCard> createState() => _AnalyzedTextCardState();
}

class _AnalyzedTextCardState extends State<AnalyzedTextCard> {
  bool isExpanded = true;

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
      key: const ValueKey('analyzed-text-card'),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.k.reviewSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: context.k.ink.withValues(alpha: .055),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => isExpanded = !isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScaler = MediaQuery.textScalerOf(context);
                  final titleTextStyle =
                      DefaultTextStyle.of(context).style.merge(
                            TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.k.ink),
                          );
                  final badgeTextStyle =
                      DefaultTextStyle.of(context).style.merge(
                            TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: context.k.brandStrong),
                          );
                  final titleWidth = (TextPainter(
                    text: TextSpan(
                        text: 'Văn bản đã phân tích', style: titleTextStyle),
                    textDirection: Directionality.of(context),
                    textScaler: textScaler,
                  )..layout())
                      .width;
                  final badgeTextWidth = widget.matchedChildCount == 0
                      ? 0.0
                      : (TextPainter(
                          text: TextSpan(
                            text: 'Đã tách ${widget.matchedChildCount} bé',
                            style: badgeTextStyle,
                          ),
                          textDirection: Directionality.of(context),
                          textScaler: textScaler,
                        )..layout())
                          .width;
                  final compact = constraints.maxWidth < 300 ||
                      textScaler.scale(1) > 1.3 ||
                      titleWidth +
                              badgeTextWidth +
                              (widget.matchedChildCount == 0 ? 0 : 28) >
                          constraints.maxWidth;
                  final title =
                      Text('Văn bản đã phân tích', style: titleTextStyle);
                  final badge = widget.matchedChildCount == 0
                      ? const SizedBox.shrink()
                      : Container(
                          key: const ValueKey('analyzed-text-badge-pill'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.k.brandTint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 6,
                            children: [
                              Container(
                                key: const ValueKey('analyzed-text-badge-dot'),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: context.k.infoDot,
                                    shape: BoxShape.circle),
                              ),
                              Flexible(
                                child: Text(
                                  'Đã tách ${widget.matchedChildCount} bé',
                                  style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                      color: context.k.brandStrong),
                                ),
                              ),
                            ],
                          ),
                        );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        if (widget.matchedChildCount > 0) ...[
                          const SizedBox(height: 8),
                          badge,
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      title,
                      Expanded(
                        child: Divider(
                          key: const ValueKey('analyzed-text-divider'),
                          height: 1,
                          color: context.k.line,
                        ),
                      ),
                      badge,
                    ],
                  );
                },
              ),
            ),
          ),
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14, height: 1.4, color: context.k.inkSoft),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _copy,
                        style: TextButton.styleFrom(
                            foregroundColor: context.k.brand,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text('Sao chép',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (widget.onEdit != null) ...[
                        TextButton(
                          onPressed: widget.onEdit,
                          style: TextButton.styleFrom(
                              foregroundColor: context.k.brand,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: const Text('Sửa & Phân tích lại',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
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
