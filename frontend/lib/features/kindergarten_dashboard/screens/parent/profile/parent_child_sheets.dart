import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/core/utils/phone_utils.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/profile/parent_health_profile_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/profile/parent_child_edit_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/parent_profile_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/profile/parent_account_formatters.dart';

class ParentChildInfoSheet extends StatefulWidget {
  const ParentChildInfoSheet({super.key, 
    required this.overview,
    required this.parentId,
    required this.repository,
    required this.onChildUpdated,
    required this.onHealthUpdated,
    this.allChildren,
    this.onSwitchChild,
  });

  final ChildOverview overview;
  final String parentId;
  final HttpDashboardRepository? repository;
  final List<ChildOverview>? allChildren;
  final VoidCallback? onSwitchChild;
  final ValueChanged<Child>? onChildUpdated;
  final ValueChanged<Child>? onHealthUpdated;

  @override
  State<ParentChildInfoSheet> createState() => ParentChildInfoSheetState();
}

class ParentChildInfoSheetState extends State<ParentChildInfoSheet> {
  late Child _child = widget.overview.child;

  void _editChild() {
    showParentChildEditScreen(
      context,
      child: _child,
      parentId: widget.parentId,
      repository: widget.repository,
      onSaved: (updated) {
        if (!mounted) return;
        setState(() => _child = updated);
        widget.onChildUpdated?.call(updated);
      },
    );
  }

  String _healthSummary(Child child) => switch (child.allergyStatus) {
        'present' => (child.medicalAllergies ?? '').trim().isNotEmpty
            ? 'Dị ứng · ${(child.medicalAllergies ?? '').trim()}'
            : 'Có dị ứng',
        'none' => 'Không ghi nhận dị ứng',
        _ => 'Chưa khai báo dị ứng',
      };

  Future<void> _callTeacher(BuildContext context) async {
    final phone = phoneCallUri(widget.overview.teacherPhone ?? '');
    if (phone == null) return;
    try {
      if (await launchUrl(phone, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Giữ số liên hệ trong hồ sơ nếu thiết bị không mở được ứng dụng gọi.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được ứng dụng gọi điện.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _child;
    final overview = widget.overview;
    final phoneAvailable = phoneCallUri(overview.teacherPhone ?? '') != null;
    final dateOfBirth = child.dateOfBirth;
    final className = overview.className.trim();
    final isEn = LocaleController.instance.isEnglish;
    final classDisplay = className.isEmpty
        ? ''
        : LocaleController.formatClassName(className, isEn: isEn);
    final teacherDisplay = overview.teacherName.trim().isEmpty
        ? ''
        : LocaleController.formatTeacherName(overview.teacherName, isEn: isEn);

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.allChildren != null && widget.allChildren!.length > 1) ...[
                Semantics(
                  button: true,
                  label: context.l10n?.switchChildLabel ?? 'Đổi sang bé khác',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSwitchChild?.call();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded,
                              size: 14, color: context.k.brand),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n?.switchChild ?? 'Đổi bé',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.k.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(context.l10n?.childInfoSheetTitle ?? 'Thông tin bé',
                    style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: context.k.ink)),
              ),
              IconButton(
                tooltip: context.l10n?.childEditInfo ?? 'Chỉnh sửa thông tin bé',
                onPressed: _editChild,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: context.l10n?.commonClose ?? 'Đóng',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.k.brandTint,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.k.brand,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            childInitials(child.fullName),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.k.surface),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(child.fullNameWithNickname,
                            style: TextStyle(
                                fontSize: 16,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: context.k.ink)),
                        Text(
                          [
                            if ((child.nickname ?? '').trim().isNotEmpty)
                              'Biệt danh: ${child.nickname!.trim()}',
                            if (classDisplay.isNotEmpty) classDisplay,
                          ].join(' · '),
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: context.k.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.k.reviewSurface,
                      border: Border.all(color: context.k.lineStrong),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        if (dateOfBirth != null)
                          KInfoRow(
                            label: context.l10n?.parentDateOfBirth ?? 'Ngày sinh',
                            value:
                                '${kDateLabel(dateOfBirth)}${formatChildAge(dateOfBirth).isEmpty ? '' : ' · ${formatChildAge(dateOfBirth)}'}',
                          ),
                        if (teacherDisplay.isNotEmpty)
                          KInfoRow(
                              label: context.l10n?.accountTeacherInCharge ?? 'Giáo viên chủ nhiệm',
                              value: teacherDisplay),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  KCard(
                    color: context.k.accentTint,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    onTap: () => showParentHealthProfile(
                      context,
                      child: child,
                      className: overview.className,
                      repository:
                          widget.repository ?? HttpDashboardRepository(),
                      onSaved: (updated) {
                        if (!mounted) return;
                        setState(() => _child = updated);
                        widget.onHealthUpdated?.call(updated);
                      },
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n?.accountHealthNotes ?? 'Hồ sơ sức khỏe',
                                  style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: FontWeight.w700,
                                      color: context.k.ink)),
                              Text(_healthSummary(child),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12, color: context.k.inkSoft)),
                            ],
                          ),
                        ),
                        Text(context.l10n?.parentViewDetail ?? 'Xem ›',
                            style: TextStyle(
                                fontSize: 12, color: context.k.accentDeep)),
                      ],
                    ),
                  ),
                  if (phoneAvailable) ...[
                    const SizedBox(height: 12),
                    KButton(
                      label: context.l10n?.callHeadTeacher ?? 'Gọi giáo viên chủ nhiệm',
                      onPressed: () => _callTeacher(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet hiển thị danh sách các bé để phụ huynh chọn (khi có > 1 bé).
class ParentChildSelectionSheet extends StatelessWidget {
  const ParentChildSelectionSheet({super.key, 
    required this.children,
    required this.currentChildId,
    required this.onSelectChild,
  });

  final List<ChildOverview> children;
  final String currentChildId;
  final ValueChanged<ChildOverview> onSelectChild;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n?.parentSelectChild ?? 'Chọn thông tin bé',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: k.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n?.parentFamilySummary(children.length) ?? 'Gia đình có ${children.length} bé đang theo học',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: k.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n?.commonClose ?? 'Đóng',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final isEn = LocaleController.instance.isEnglish;
                final item = children[index];
                final child = item.child;
                final isCurrent = child.childId == currentChildId;
                final className = item.className.trim();
                final classDisplay = className.isEmpty
                    ? ''
                    : LocaleController.formatClassName(className, isEn: isEn);
                final teacherDisplay = item.teacherName.trim().isEmpty
                    ? ''
                    : LocaleController.formatTeacherName(item.teacherName, isEn: isEn);

                return Material(
                  color: isCurrent
                      ? k.brandTint.withValues(alpha: 0.45)
                      : k.surfaceSunken,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.pop(context);
                      onSelectChild(item);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isCurrent ? k.brand : k.line,
                          width: isCurrent ? 1.5 : 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: k.brand,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              childInitials(child.fullName),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: k.surface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        child.fullNameWithNickname,
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.3,
                                          fontWeight: FontWeight.w700,
                                          color: k.ink,
                                        ),
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: k.brand,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          context.l10n?.parentSelected ?? 'Đang chọn',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: k.surface,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    if ((child.nickname ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      'Biệt danh: ${child.nickname!.trim()}',
                                    if (classDisplay.isNotEmpty) classDisplay,
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: k.inkSoft,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    if (teacherDisplay.isNotEmpty) ...[
                                      Icon(Icons.person_outline,
                                          size: 14, color: k.inkFaint),
                                      const SizedBox(width: 3),
                                      Text(
                                        teacherDisplay,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: k.inkFaint,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: child.allergyStatus == 'present'
                                            ? k.badTint
                                            : k.okTint,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        child.allergyStatus == 'present'
                                            ? (context.l10n?.healthAllergyYes ?? 'Có dị ứng')
                                            : (context.l10n?.healthGood ?? 'Sức khỏe tốt'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              child.allergyStatus == 'present'
                                                  ? k.badText
                                                  : k.ok,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 22,
                            color: k.inkSoft,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Giữ alias tương thích nếu có component gọi showParentPhoneSheet.
Future<void> showParentPhoneSheet(
  BuildContext context, {
  required Parent parent,
  required ValueChanged<String> onSaved,
  HttpDashboardRepository? repository,
}) {
  return showParentProfileSheet(
    context,
    parent: parent,
    repository: repository,
    onSaved: (phone, _, __) => onSaved(phone),
  );
}

/// Giữ tương thích tên gọi cũ; trình sửa bé hiện mở thành trang riêng.
Future<void> showParentChildEditSheet(
  BuildContext context, {
  required Child child,
  required String parentId,
  required HttpDashboardRepository? repository,
  required ValueChanged<Child> onSaved,
}) =>
    showParentChildEditScreen(
      context,
      child: child,
      parentId: parentId,
      repository: repository,
      onSaved: onSaved,
    );

/// Sheet xác nhận đăng xuất ("Ở lại" / "Đăng xuất").
Future<void> showParentLogoutSheet(
  BuildContext context, {
  required VoidCallback onLogout,
}) {
  return showKSheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.l10n?.parentLogoutConfirmTitle ?? 'Bạn có muốn đăng xuất không ?',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: KButton(
                label: context.l10n?.commonCancel ?? 'Hủy',
                secondary: true,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KButton(
                label: context.l10n?.accountLogout ?? 'Đăng xuất',
                icon: Icons.logout_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  onLogout();
                },
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
