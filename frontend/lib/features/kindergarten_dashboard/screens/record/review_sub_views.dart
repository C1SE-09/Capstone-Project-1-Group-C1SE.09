
import 'package:flutter/material.dart';
import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/models.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/review/review_common_widgets.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/screens/record/record_models.dart';


class ClasswideDoneScreen extends StatelessWidget {
  const ClasswideDoneScreen({super.key, 
    required this.classLabel,
    required this.onBack,
  });

  final String classLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => GardenVoiceScope(
        child: Builder(
          builder: (context) {
            final k = context.k;
            final name = classLabel.startsWith('Lớp ')
                ? classLabel.substring(4)
                : classLabel;
            return Scaffold(
              backgroundColor: k.canvas,
              appBar: KAppBar(
                title: context.l10n?.sttReportSentSuccessTitle ?? 'Đã gửi báo cáo',
                onBack: onBack,
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Báo cáo ngày đã được gửi đến phụ huynh của từng bé trong lớp $name.',
                        style: TextStyle(
                          color: k.inkSoft,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      KButton(
                        label: context.l10n?.sttBackToClassOverview ?? 'Về tổng quan lớp',
                        onPressed: onBack,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class ObservationTile extends StatelessWidget {
  const ObservationTile({super.key, 
    required this.card,
    required this.className,
    required this.showSegmentPreview,
    required this.onToggleApprove,
    required this.onUnapprove,
    required this.onDiscard,
    required this.onRestore,
    required this.onAssign,
    this.onEdit,
    this.isApproving = false,
    this.summaryStyle = false,
    this.showApproveAction = false,
    this.summaryLabel,
  });

  final ObservationItem card;
  final String className;
  final bool showSegmentPreview;
  final VoidCallback onToggleApprove;
  final VoidCallback onUnapprove;
  final VoidCallback onDiscard;
  final VoidCallback onRestore;
  final VoidCallback onAssign;
  final VoidCallback? onEdit;
  final bool isApproving;
  final bool summaryStyle;
  final bool showApproveAction;
  final String? summaryLabel;

  @override
  Widget build(BuildContext context) {
    if (summaryStyle) {
      final k = context.k;
      final summary = [
        card.eating,
        card.sleep,
        card.activities,
        card.mood,
        card.health,
        card.note,
      ].where((value) => value.trim().isNotEmpty).join('. ');
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: k.surfaceSunken,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summaryLabel ??
                  (card.kind == ObservationKind.classwide
                      ? (LocaleController.instance.isEnglish
                          ? 'Apply to entire class'
                          : 'Áp dụng cho cả lớp')
                      : card.fullNameWithNickname),
              style: TextStyle(
                color: k.brandStrong,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              summary.isEmpty
                  ? (LocaleController.instance.isEnglish
                      ? 'No detailed information recorded'
                      : 'Không có thông tin chi tiết được ghi nhận')
                  : summary,
              style: TextStyle(
                color: k.ink,
                fontSize: 17,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showApproveAction &&
                card.decision != ObservationDecision.approved)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isApproving ? null : onToggleApprove,
                  child: Text(context.l10n?.leaveRequestApprove ?? 'Duyệt'),
                ),
              ),
          ],
        ),
      );
    }

    if (card.decision == ObservationDecision.discarded) {
      return SurfaceBox(
        color: context.k.canvas,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${context.l10n?.discardItem ?? 'Đã loại bỏ'} · ${card.fullNameWithNickname}',
                style: TextStyle(fontSize: 12, color: context.k.inkFaint),
              ),
            ),
            TextButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.undo_rounded, size: 15),
              label: Text(context.l10n?.sttUndo ?? 'Hoàn tác'),
            ),
          ],
        ),
      );
    }

    final isUnmatched = card.kind == ObservationKind.unmatched;
    final isSegmentPreview = showSegmentPreview && !isUnmatched;
    final segmentSummary = [
      card.eating,
      card.sleep,
      card.activities,
      card.mood,
      card.health,
      card.note,
    ].where((value) => value.trim().isNotEmpty).join('. ');
    final nameParts = card.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final avatarText = nameParts.length > 1
        ? '${nameParts[nameParts.length - 2][0]}${nameParts.last[0]}'
        : (nameParts.firstOrNull ?? '?')[0].toUpperCase();

    return SurfaceBox(
      color: isUnmatched
          ? context.k.surface
          : isSegmentPreview
              ? context.k.surfaceSunken
              : context.k.reviewSurface,
      borderColor: isUnmatched
          ? context.k.bad.withValues(alpha: .52)
          : isSegmentPreview
              ? Colors.transparent
              : context.k.lineStrong,
      padding: isUnmatched
          ? const EdgeInsets.all(15)
          : const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUnmatched)
            Text(context.l10n?.unidentifiedChild ?? 'Chưa xác định bé',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.k.brandStrong))
          else if (isSegmentPreview)
            Text('${context.l10n?.approvedStatus ?? 'Đã nhận ra'} · ${card.fullNameWithNickname}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.k.brandStrong))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: context.k.accentTint,
                  child: Text(avatarText.toUpperCase(),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.k.accentDeep)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.fullNameWithNickname,
                          style: TextStyle(
                              fontSize: 14,
                              color: context.k.ink,
                              fontWeight: FontWeight.w700)),
                      Text(
                          LocaleController.instance.isEnglish
                              ? (className.replaceFirst(RegExp(r'^(Lớp|Class)\s*', caseSensitive: false), '').isEmpty
                                  ? 'Class'
                                  : 'Class ${className.replaceFirst(RegExp(r'^(Lớp|Class)\s*', caseSensitive: false), '')}')
                              : (className.startsWith('Lớp ')
                                  ? className
                                  : 'Lớp $className'),
                          style: TextStyle(
                              fontSize: 11, color: context.k.inkFaint)),
                    ],
                  ),
                ),
                if (card.decision == ObservationDecision.approved)
                  Container(
                    key: const ValueKey('review-approved-pill'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.k.okTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Container(
                          key: const ValueKey('review-approved-dot'),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: context.k.okDot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(context.l10n?.approvedStatus ?? 'Đã duyệt',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: context.k.ok)),
                      ],
                    ),
                  ),
              ],
            ),
          if (isUnmatched) ...[
            const SizedBox(height: 4),
            Text(
              '“${card.snippet.isNotEmpty ? card.snippet : (context.l10n?.unidentifiedChild ?? 'Chưa nhận diện chính xác được bé trong lớp.')}”',
              style: TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: context.k.ink),
            ),
          ] else if (isSegmentPreview) ...[
            const SizedBox(height: 4),
            Text(segmentSummary,
                style: TextStyle(
                    fontSize: 17,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: context.k.ink)),
          ] else ...[
            const SizedBox(height: 10),
            if (card.eating.isNotEmpty)
              _buildReportLine(context, 'eating', context.l10n?.categoryEating ?? 'Ăn uống', card.eating),
            if (card.sleep.isNotEmpty)
              _buildReportLine(context, 'sleep', context.l10n?.categorySleep ?? 'Giấc ngủ', card.sleep),
            if (card.activities.isNotEmpty)
              _buildReportLine(context, 'activity', context.l10n?.categoryActivity ?? 'Hoạt động', card.activities),
            if (card.mood.isNotEmpty)
              _buildReportLine(context, 'mood', context.l10n?.categoryMood ?? 'Tâm trạng', card.mood),
            if (card.health.isNotEmpty)
              _buildReportLine(context, 'health', context.l10n?.categoryHealth ?? 'Sức khỏe', card.health),
            if (card.note.trim().isNotEmpty)
              _buildReportLine(context, 'note', context.l10n?.categoryNote ?? 'Ghi chú', card.note.trim()),
            if (card.eating.isEmpty &&
                card.sleep.isEmpty &&
                card.activities.isEmpty &&
                card.mood.isEmpty &&
                card.health.isEmpty &&
                card.note.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  context.l10n?.noDetailInfoRecorded ?? 'Không có thông tin chi tiết được ghi nhận',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: context.k.inkFaint),
                ),
              ),
          ],
          if (!isSegmentPreview &&
              card.decision != ObservationDecision.approved)
            isUnmatched
                ? const SizedBox(height: 14)
                : const Divider(height: 20),
          if (isUnmatched) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAssign,
                style: FilledButton.styleFrom(
                  backgroundColor: context.k.brand,
                  foregroundColor: context.k.surface,
                  minimumSize: const Size(double.infinity, 48),
                  shape: const StadiumBorder(),
                ),
                child: Text(context.l10n?.assignThisSegment ?? 'Gán đoạn này'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDiscard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.k.brand,
                  side: BorderSide(color: context.k.line),
                  minimumSize: const Size(double.infinity, 48),
                  shape: const StadiumBorder(),
                ),
                child: Text(context.l10n?.skipThisSegment ?? 'Bỏ qua đoạn này'),
              ),
            ),
          ] else if (!isSegmentPreview &&
              card.decision == ObservationDecision.approved)
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 22,
              runSpacing: 0,
              children: [
                if (onEdit != null)
                  TextButton(
                    onPressed: isApproving ? null : onEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: context.k.brand,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(context.l10n?.editActivityTitle ?? 'Chỉnh sửa',
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w700)),
                  ),
                TextButton(
                  onPressed: isApproving ? null : onDiscard,
                  style: TextButton.styleFrom(
                    foregroundColor: context.k.badText,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(context.l10n?.discardItem ?? 'Loại bỏ',
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: isApproving ? null : onUnapprove,
                  style: TextButton.styleFrom(
                    foregroundColor: context.k.warn,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(context.l10n?.unapprovedStatus ?? 'Bỏ duyệt',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            )
          else if (!isSegmentPreview)
            Wrap(
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 0,
              children: [
                if (onEdit != null) ...[
                  TextButton(
                    onPressed: isApproving ? null : onEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: context.k.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(context.l10n?.editActivityTitle ?? 'Chỉnh sửa'),
                  ),
                ],
                TextButton(
                  onPressed: isApproving ? null : onDiscard,
                  style: TextButton.styleFrom(
                    foregroundColor: context.k.badText,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(context.l10n?.discardItem ?? 'Loại bỏ'),
                ),
                if (isApproving)
                  // Đang approve → hiện spinner (block cả Loại bỏ để tránh race)
                  const SizedBox(
                    height: 32,
                    width: 32,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (card.decision == ObservationDecision.approved) ...[
                  OutlinedButton.icon(
                    onPressed: onUnapprove,
                    icon: Icon(Icons.undo_rounded,
                        size: 15, color: context.k.warn),
                    label: Text(
                      context.l10n?.unapprovedStatus ?? 'Bỏ duyệt',
                      style: TextStyle(
                          color: context.k.warn, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.k.warn, width: 1.2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KRadii.control)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onToggleApprove,
                    borderRadius: BorderRadius.circular(KRadii.control),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: context.k.okTint,
                        borderRadius: BorderRadius.circular(KRadii.control),
                        border: Border.all(
                            color: context.k.ok.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 15, color: context.k.ok),
                          const SizedBox(width: 5),
                          Text(
                            context.l10n?.approvedStatus ?? 'Đã duyệt',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.k.ok),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  TextButton(
                    onPressed: onToggleApprove,
                    style: TextButton.styleFrom(
                      foregroundColor: context.k.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(context.l10n?.leaveRequestApprove ?? 'Duyệt'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReportLine(
      BuildContext context, String type, String label, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    final (background, foreground, asset) = switch (type) {
      'eating' => (
          context.k.foodRowTint,
          context.k.foodRowText,
          'food',
        ),
      'sleep' => (
          context.k.sleepRowTint,
          context.k.sleepRowText,
          'sleep',
        ),
      'activity' => (
          context.k.activityRowTint,
          context.k.activityRowText,
          'activity',
        ),
      _ => (context.k.brandTint, context.k.brand, ''),
    };
    final icon = switch (asset) {
      'food' => Stack(
          children: [
            Positioned(
              left: 15,
              top: 4,
              child: SvgPicture.asset('assets/garden_voice/review_spoon.svg'),
            ),
            Positioned(
              left: 4,
              top: 12,
              child: SvgPicture.asset('assets/garden_voice/review_bowl.svg'),
            ),
          ],
        ),
      'sleep' => Padding(
          padding: const EdgeInsets.all(4),
          child: SvgPicture.asset('assets/garden_voice/review_moon.svg'),
        ),
      'activity' => Padding(
          padding: const EdgeInsets.all(4),
          child:
              SvgPicture.asset('assets/garden_voice/review_artist_palette.svg'),
        ),
      _ => Icon(Icons.favorite_outline, size: 18, color: foreground),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            SizedBox(width: 26, height: 26, child: icon),
            const SizedBox(width: 6),
            SizedBox(
              width: 65,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: foreground)),
            ),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.k.ink)),
            ),
          ],
        ),
      ),
    );
  }
}



class AssignChildScreen extends StatefulWidget {
  const AssignChildScreen({super.key, 
    required this.card,
    required this.roster,
    required this.className,
    required this.onAssignClass,
  });

  final ObservationItem card;
  final List<Child> roster;
  final String className;
  final VoidCallback onAssignClass;

  @override
  State<AssignChildScreen> createState() => AssignChildScreenState();
}

class AssignChildScreenState extends State<AssignChildScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.roster
        .where((c) =>
            query.isEmpty ||
            c.fullNameWithNickname
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            (c.nickname ?? '')
                .toLowerCase()
                .contains(query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.l10n?.commonBack ?? 'Quay lại',
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    icon: SvgPicture.asset('assets/notifications/back_44.svg'),
                  ),
                  const SizedBox(width: 4),
                  Text(context.l10n?.assignSegmentTitle ?? 'Gán đoạn ghi',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF24313D))),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    '“${widget.card.snippet}”',
                    style: const TextStyle(
                        fontSize: 14, height: 1.4, color: Color(0xFF65727D)),
                  ),
                  if (widget.roster.length > 4) ...[
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (value) => setState(() => query = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: context.l10n?.sttSearchChildNameOrNick ?? 'Tìm tên bé hoặc biệt danh',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  for (final child in list) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, child),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF087F70),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(child.fullNameWithNickname),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton(
                    onPressed: () {
                      widget.onAssignClass();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF087F70),
                      side: const BorderSide(color: Color(0xFFE5E8EB)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                        'Cả lớp ${widget.className.replaceFirst(RegExp(r'^Lớp\s+'), '')}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

