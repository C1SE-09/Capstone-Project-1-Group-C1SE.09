// parent_account.dart
// =========================================================
// Tab "Tài khoản" của màn phụ huynh (design v4 — Figma Make):
// hero + quan hệ, nhận xét của cô, thông tin liên hệ (sửa SĐT),
// thông tin bé (sheet chi tiết), cài đặt, đăng xuất.

import 'package:flutter/material.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_navigation_scroll.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adark_frontend/core/localization/locale_controller.dart';
import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/about_kinderlog_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/common/bug_report_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/auth/change_password_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/profile/parent_health_profile_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/parent_profile_sheet.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/widgets/parent_profile_sheet.dart'
    show
        kRelationshipOptions,
        isValidParentPhone,
        isValidParentEmail,
        showParentProfileSheet;
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/profile/parent_account_formatters.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/profile/parent_child_sheets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/profile/parent_contact_screen.dart';

export 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/profile/parent_account_formatters.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/profile/parent_contact_screen.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/screens/parent/profile/parent_child_sheets.dart';

class ParentAccount extends StatefulWidget {
  const ParentAccount({
    super.key,
    required this.parent,
    required this.overview,
    required this.reports,
    required this.onOpenReport,
    required this.onPhoneUpdated,
    this.onParentUpdated,
    this.onChildUpdated,
    this.repository,
    this.onLogout,
    this.onHealthUpdated,
    this.onOpenNotifications,
    this.onSelectChild,
  });

  final Parent parent;
  final ChildOverview overview;
  final List<DailyReport> reports;
  final ValueChanged<DailyReport> onOpenReport;
  final ValueChanged<String> onPhoneUpdated;
  final void Function(String phone, String? email, String? relationship)?
      onParentUpdated;
  final ValueChanged<Child>? onChildUpdated;
  final HttpDashboardRepository? repository;
  final VoidCallback? onLogout;
  final ValueChanged<Child>? onHealthUpdated;
  final VoidCallback? onOpenNotifications;
  final ValueChanged<String>? onSelectChild;

  @override
  State<ParentAccount> createState() => _ParentAccountState();
}

class _ParentAccountState extends State<ParentAccount> {
  bool _pushEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPushPref();
  }

  Future<void> _loadPushPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(kParentPushPrefsKey);
      if (!mounted || saved == null) return;
      setState(() => _pushEnabled = saved);
    } catch (_) {
      // Không đọc được lựa chọn đã lưu thì giữ mặc định bật.
    }
  }

  Future<void> _setPush(bool enabled) async {
    setState(() => _pushEnabled = enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kParentPushPrefsKey, enabled);
    } catch (_) {
      // Máy không lưu được thì vẫn giữ trạng thái trong phiên.
    }
    // Firebase có thể chưa cấu hình (dev) — đăng ký/xoá token là fail-soft.
    try {
      final service = PushNotificationService.instance;
      await (enabled
          ? service.registerCurrentDevice()
          : service.deleteCurrentDevice());
    } catch (_) {
      // Thiếu cấu hình Firebase thì bỏ qua, app vẫn chạy bình thường.
    }
  }

  void _openProfileSheet({
    void Function(String phone, String? email, String? relationship)? onSaved,
  }) {
    showParentProfileEditScreen(
      context,
      parent: widget.parent,
      childName: widget.overview.child.fullNameWithNickname,
      repository: widget.repository,
      onSaved: (phone, email, relationship) {
        if (widget.onParentUpdated != null) {
          widget.onParentUpdated!(phone, email, relationship);
        } else {
          widget.onPhoneUpdated(phone);
        }
        onSaved?.call(phone, email, relationship);
      },
    );
  }

  void _openContactScreen() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => GardenVoiceScope(
        child: ParentContactScreen(
          parent: widget.parent,
          childName: widget.overview.child.fullNameWithNickname,
          onEdit: (onSaved) => _openProfileSheet(onSaved: onSaved),
        ),
      ),
    ));
  }

  void _openChildInfo() {
    final children = widget.overview.allChildren.isNotEmpty
        ? widget.overview.allChildren
        : [widget.overview];
    if (children.length > 1) {
      _openChildSelectionSheet();
    } else {
      _openSingleChildInfo(children.first);
    }
  }

  void _openSingleChildInfo(ChildOverview targetOverview) {
    showKSheet<void>(
      context,
      GardenVoiceScope(
        child: ParentChildInfoSheet(
          overview: targetOverview,
          parentId: widget.parent.parentId,
          repository: widget.repository,
          allChildren: widget.overview.allChildren,
          onSwitchChild: () => _openChildSelectionSheet(),
          onChildUpdated: widget.onChildUpdated,
          onHealthUpdated: widget.onHealthUpdated,
        ),
      ),
    );
  }

  void _openChildSelectionSheet() {
    final children = widget.overview.allChildren.isNotEmpty
        ? widget.overview.allChildren
        : [widget.overview];
    showKSheet<void>(
      context,
      GardenVoiceScope(
        child: ParentChildSelectionSheet(
          children: children,
          currentChildId: widget.overview.child.childId,
          onSelectChild: (selectedOverview) {
            widget.onSelectChild?.call(selectedOverview.child.childId);
            _openSingleChildInfo(selectedOverview);
          },
        ),
      ),
    );
  }

  void _openEditChildSheet() {
    showParentChildEditSheet(
      context,
      child: widget.overview.child,
      parentId: widget.parent.parentId,
      repository: widget.repository,
      onSaved: (updated) => widget.onChildUpdated?.call(updated),
    );
  }

  void _openHealthProfile() {
    showParentHealthProfile(
      context,
      child: widget.overview.child,
      className: widget.overview.className,
      repository: widget.repository ?? HttpDashboardRepository(),
      onSaved: widget.onHealthUpdated,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.k.isGardenVoice) return _buildGardenVoiceAccount(context);

    final child = widget.overview.child;
    final parent = widget.parent;
    final relationship = parent.relationship?.trim();
    final latestReport = widget.reports.isEmpty ? null : widget.reports.first;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 28 + GardenVoiceNavigationFrame.bottomPaddingOf(context)),
      children: [
        // ── Hero ───────────────────────────────────────────────
        // Nền dùng hằng brand đậm cố định (không theo theme): brand ở theme tối là
        // teal sáng, chữ trắng trên đó chỉ đạt 2.3:1 — dưới ngưỡng AA.
        Container(
          key: const ValueKey('parent-hero'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KColors.brand,
            borderRadius: BorderRadius.circular(KRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(name: parent.fullName, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parent.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (relationship != null && relationship.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              key: const ValueKey('parent-relation-chip'),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                // Làm nền tối hơn để chữ trắng luôn đạt tương phản AA.
                                color: Colors.black.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$relationship của ${formatParentChildrenNames(widget.overview).replaceFirst("Phụ huynh bé ", "")}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _openProfileSheet,
                    tooltip: context.l10n?.childEditInfo ?? 'Chỉnh sửa thông tin',
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n?.parentHeroDays(parentJourneyDays(parent.createdAt)) ??
                    '${parentJourneyDays(parent.createdAt)} ngày cùng con ở KinderLog',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ],
          ),
        ),

        // ── Nhận xét mới nhất của cô ───────────────────────────
        if (latestReport != null &&
            (latestReport.summaryText?.trim().isNotEmpty ?? false)) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              border:
                  Border(left: BorderSide(color: context.k.brand, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“${latestReport.summaryText!.trim()}”',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    color: context.k.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.overview.teacherName} · ${kDateLabel(latestReport.reportDate)}',
                        style:
                            TextStyle(fontSize: 12, color: context.k.inkFaint),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onOpenReport(latestReport),
                      child: Text(context.l10n?.readReportAction ?? 'Đọc báo cáo ›'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // ── Thông tin liên hệ ──────────────────────────────────
        _sectionTitle(context, context.l10n?.parentContactInfo ?? 'Thông tin liên hệ'),
        KCard(
          child: Column(
            children: [
              if ((parent.email ?? '').trim().isNotEmpty)
                KInfoRow(label: 'Email', value: parent.email!.trim()),
              if (relationship != null && relationship.isNotEmpty)
                KInfoRow(label: context.l10n?.relationTitle ?? 'Quan hệ với bé', value: relationship),
              if ((parent.phone ?? '').trim().isNotEmpty)
                KInfoRow(
                  label: context.l10n?.contactPhoneLabel ?? 'Số điện thoại',
                  value: parent.phone!.trim(),
                  showEditIcon: false,
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: parent.phone!.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n?.phoneCopied ?? 'Đã sao chép số điện thoại'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        // ── Thông tin bé ───────────────────────────────────────
        _sectionTitle(context, context.l10n?.childInfoSheetTitle ?? 'Thông tin bé'),
        KCard(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Avatar(name: child.fullName, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.fullNameWithNickname,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if ((child.nickname ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                context.l10n?.nicknamePrefix(child.nickname!.trim()) ??
                                    'Biệt danh: ${child.nickname!.trim()}',
                                style: TextStyle(
                                    fontSize: 13, color: context.k.inkSoft),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: context.l10n?.childEditInfo ?? 'Chỉnh sửa thông tin bé',
                      onPressed: _openEditChildSheet,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              KInfoRow(
                label: context.l10n?.childFullName ?? 'Họ và tên',
                value: child.fullName,
              ),
              KInfoRow(
                label: context.l10n?.childNicknameLabel ?? 'Biệt danh',
                value: (child.nickname ?? '').trim().isNotEmpty
                    ? child.nickname!.trim()
                    : (context.l10n?.childNotSet ?? 'Chưa thiết lập'),
              ),
              if (child.dateOfBirth != null)
                KInfoRow(
                  label: context.l10n?.parentDobLabel ?? 'Sinh ngày',
                  value: formatChildAge(child.dateOfBirth!).isNotEmpty
                      ? '${kDateLabel(child.dateOfBirth!)} (${formatChildAge(child.dateOfBirth!)})'
                      : kDateLabel(child.dateOfBirth!),
                ),
              if (child.gender != null && child.gender!.trim().isNotEmpty)
                KInfoRow(
                  label: context.l10n?.genderLabel ?? 'Giới tính',
                  value: formatGender(child.gender),
                ),
              KInfoRow(label: context.l10n?.commonClass ?? 'Lớp', value: widget.overview.className),
              KInfoRow(
                  label: context.l10n?.entityHeadTeacher ?? 'Giáo viên chủ nhiệm',
                  value: widget.overview.teacherName),
              if (child.allergy != null)
                KInfoRow(
                  label: context.l10n?.parentAllergyTitle ?? 'Dị ứng',
                  value: child.allergy!,
                  danger: true,
                  icon: Icons.warning_amber_rounded,
                ),
              KInfoRow(
                label: context.l10n?.parentHealthProfileTitle ?? 'Hồ sơ sức khỏe',
                value: switch (child.allergyStatus) {
                  'present' => (context.l10n?.healthAllergyYes ?? (context.l10n?.healthAllergyYes ?? 'Có dị ứng')),
                  'none' => (context.l10n?.healthAllergyNone ?? 'Không có dị ứng'),
                  _ => (context.l10n?.healthUndeclared ?? 'Chưa khai báo'),
                },
                icon: Icons.health_and_safety_outlined,
                onTap: _openHealthProfile,
              ),
            ],
          ),
        ),

        // ── Cài đặt ────────────────────────────────────────────
        const SizedBox(height: 16),
        KCard(
          child: Column(
            children: [
              _settingsRow(
                context,
                icon: Icons.lock_outline_rounded,
                label: context.l10n?.changePassword ?? 'Đổi mật khẩu',
                trailing: Icon(Icons.chevron_right,
                    size: 18, color: context.k.inkFaint),
                onTap: () => showChangePasswordBottomSheet(context),
              ),
              const Divider(height: 1),
              _settingsRow(
                context,
                icon: Icons.rate_review_outlined,
                label: context.l10n?.accountBugReport ?? 'Góp ý & Cải thiện ứng dụng',
                trailing: Icon(Icons.chevron_right,
                    size: 18, color: context.k.inkFaint),
                onTap: () => showBugReportBottomSheet(context),
              ),
              const Divider(height: 1),
              _settingsRow(
                context,
                icon: Icons.notifications_outlined,
                label: context.l10n?.parentPushNotification ?? 'Thông báo đẩy',
                subtitle: context.l10n?.parentPushSubtitle ?? 'Nhận thông báo khi có báo cáo mới',
                trailing: Switch(value: _pushEnabled, onChanged: _setPush),
              ),
              const Divider(height: 1),
              _settingsRow(
                context,
                icon: Icons.language_rounded,
                label: context.l10n?.accountLanguage ?? 'Ngôn ngữ / Language',
                subtitle: LocaleController.instance.isVietnamese ? 'Tiếng Việt 🇻🇳' : 'English 🇬🇧',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showLanguageSelectionDialog(context),
              ),
              const Divider(height: 1),
              _settingsRow(
                context,
                icon: Icons.info_outline,
                label: context.l10n?.accountAbout ?? 'Về KinderLog',
                trailing: Text('v1.0.0',
                    style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
                onTap: () => showAboutKinderLogSheet(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        KButton(
          label: context.l10n?.accountLogout ?? 'Đăng xuất',
          icon: Icons.logout_rounded,
          secondary: true,
          onPressed: widget.onLogout == null
              ? null
              : () =>
                  showParentLogoutSheet(context, onLogout: widget.onLogout!),
        ),
      ],
    );
  }

  Widget _buildGardenVoiceAccount(BuildContext context) {
    final k = context.k;
    final parent = widget.parent;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 16;

    return ColoredBox(
      color: k.canvas,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 20, 20,
            24 + GardenVoiceNavigationFrame.bottomPaddingOf(context)),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n?.navAccount ?? 'Tài khoản',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: k.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n?.navNotifications ?? 'Thông báo',
                onPressed: widget.onOpenNotifications,
                icon: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: k.brandTint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SvgPicture.asset(
                    'assets/garden_voice/account_bell.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: largeText ? 160 : 126,
            child: Stack(
              children: [
                Positioned(
                  right: -16,
                  bottom: 0,
                  width: 190,
                  height: 92,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/garden_voice/books_v2.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 4,
                  bottom: 22,
                  right: 60,
                  child: Row(
                    children: [
                      Avatar(name: parent.fullName, size: 68),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parent.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: k.ink,
                              ),
                            ),
                            Text(
                              formatParentChildrenNames(widget.overview),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: k.inkSoft,
                              ),
                            ),
                            if (parent.createdAt != null)
                              Text(
                                context.l10n?.parentJourneyDaysText(parentJourneyDays(parent.createdAt)) ??
                                    '${parentJourneyDays(parent.createdAt)} ngày đồng hành cùng KinderLog',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w700,
                                  color: k.brand,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _accountSectionTitle(context, context.l10n?.parentSectionFamily ?? 'Gia đình'),
          Column(
            children: [
              _accountMenuRow(
                key: const ValueKey('parent-contact-menu'),
                icon: 'assets/garden_voice/account_phone.svg',
                label: context.l10n?.parentContactInfo ?? 'Thông tin liên hệ',
                onTap: _openContactScreen,
              ),
              _accountMenuRow(
                key: const ValueKey('parent-child-menu'),
                icon: 'assets/garden_voice/account_heart.svg',
                label: context.l10n?.parentChildHealthProfile ?? 'Thông tin bé · Hồ sơ sức khỏe',
                subtitle: context.l10n?.parentAllergyCareNotes ?? 'Dị ứng và lưu ý chăm sóc',
                onTap: _openChildInfo,
              ),
            ],
          ),
          _accountSectionTitle(context, context.l10n?.parentSectionPreferences ?? 'Tùy chọn'),
          Column(
            children: [
              _accountMenuRow(
                icon: 'assets/garden_voice/account_bell.svg',
                label: context.l10n?.parentPushNotification ?? 'Thông báo đẩy',
                subtitle: _pushEnabled
                    ? (context.l10n?.parentPushEnabled ?? 'Đã bật trên thiết bị')
                    : (context.l10n?.parentPushDisabled ?? 'Đã tắt trên thiết bị'),
                trailing: Switch(value: _pushEnabled, onChanged: _setPush),
              ),
            ],
          ),
          _accountSectionTitle(context, context.l10n?.accountSettingsAndSupport ?? 'Cài đặt & hỗ trợ'),
          Column(
            children: [
              _accountMenuRow(
                icon: 'assets/garden_voice/account_lock.svg',
                label: context.l10n?.accountChangePassword ?? 'Đổi mật khẩu',
                onTap: () => showChangePasswordBottomSheet(context),
              ),
              _accountMenuRow(
                icon: 'assets/garden_voice/account_settings.svg',
                label: context.l10n?.accountLanguage ?? 'Ngôn ngữ / Language',
                trailing: Text(
                  LocaleController.instance.isVietnamese ? 'Tiếng Việt 🇻🇳' : 'English 🇬🇧',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: k.brand,
                  ),
                ),
                onTap: () => showLanguageSelectionDialog(context),
              ),
              _accountMenuRow(
                icon: 'assets/garden_voice/account_bug.svg',
                label: context.l10n?.accountBugReport ?? 'Báo lỗi & góp ý',
                onTap: () => showBugReportBottomSheet(context),
              ),
              _accountMenuRow(
                icon: 'assets/garden_voice/account_info.svg',
                label: context.l10n?.accountAbout ?? 'Về KinderLog',
                subtitle: context.l10n?.appVersionLabel('1.0.0') ?? 'Phiên bản 1.0.0',
                onTap: () => showAboutKinderLogSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: widget.onLogout == null
                ? null
                : () =>
                    showParentLogoutSheet(context, onLogout: widget.onLogout!),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: k.badText,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            icon: SvgPicture.asset('assets/garden_voice/account_logout.svg'),
            label: Text(context.l10n?.accountLogout ?? 'Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Widget _accountSectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: context.k.ink,
          ),
        ),
      );

  Widget _accountMenuRow({
    Key? key,
    required String icon,
    required String label,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final k = context.k;
    final iconTint = switch (icon) {
      'assets/garden_voice/account_heart.svg' => k.badTint,
      'assets/garden_voice/account_moon.svg' => k.sleepRowTint,
      'assets/garden_voice/account_lock.svg' => k.accentTint,
      'assets/garden_voice/account_bug.svg' => k.badTint,
      _ => k.brandTint,
    };
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconTint,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(icon, width: 20, height: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: k.ink)),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, height: 1.4, color: k.inkSoft)),
              ],
            ),
          ),
          trailing ??
              SvgPicture.asset(
                'assets/garden_voice/account_chevron_right.svg',
                width: 18,
                height: 18,
              ),
        ],
      ),
    );
    return Column(
      key: key,
      children: [
        if (onTap == null)
          content
        else
          Semantics(button: true, child: InkWell(onTap: onTap, child: content)),
        Divider(height: 1, color: k.line),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(
          title,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: context.k.ink),
        ),
      );

  Widget _settingsRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: context.k.inkSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                if (subtitle != null)
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: context.k.inkFaint)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

