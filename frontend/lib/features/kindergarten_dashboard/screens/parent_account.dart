// parent_account.dart
// =========================================================
// Tab "Tài khoản" của màn phụ huynh (design v4 — Figma Make):
// hero + quan hệ, nhận xét của cô, thông tin liên hệ (sửa SĐT),
// thông tin bé (sheet chi tiết), cài đặt, đăng xuất.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/core/utils/phone_utils.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/data/repositories/http_medication_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/bug_report_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/change_password_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_health_profile_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/parent_child_edit_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/parent_profile_sheet.dart';
export '../widgets/parent_profile_sheet.dart'
    show
        kRelationshipOptions,
        isValidParentPhone,
        isValidParentEmail,
        showParentProfileSheet;

/// Khoá lưu lựa chọn nhận thông báo đẩy trên máy.
const kParentPushPrefsKey = 'kinderlog-parent-push';

/// Ngày gắn bó = số ngày kể từ lúc tạo tài khoản (createdAt).
int parentJourneyDays(DateTime? createdAt, {DateTime? now}) {
  if (createdAt == null) return 0;
  return (now ?? DateTime.now()).difference(createdAt).inDays.clamp(0, 100000);
}

/// Định dạng số tuổi của trẻ từ ngày sinh (ví dụ: "4 tuổi" hoặc "3 tuổi 8 tháng").
String formatChildAge(DateTime? dob, {DateTime? now}) {
  if (dob == null) return '';
  final current = now ?? DateTime.now();
  if (dob.isAfter(current)) return '';
  int years = current.year - dob.year;
  int months = current.month - dob.month;
  if (current.day < dob.day) {
    months--;
  }
  if (months < 0) {
    years--;
    months += 12;
  }
  if (years <= 0) {
    return '$months tháng tuổi';
  } else if (months == 0) {
    return '$years tuổi';
  } else {
    return '$years tuổi $months tháng';
  }
}

/// Chuyển đổi mã giới tính sang tiếng Việt thân thiện.
String formatGender(String? gender) {
  if (gender == null || gender.trim().isEmpty) return 'Chưa cập nhật';
  final g = gender.trim().toLowerCase();
  if (g == 'male' || g == 'nam') return 'Bé trai (Nam)';
  if (g == 'female' || g == 'nữ' || g == 'nu') return 'Bé gái (Nữ)';
  return 'Khác';
}

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
    this.medicationRepository,
    this.onLogout,
    this.onHealthUpdated,
    this.onOpenNotifications,
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
  final HttpMedicationRepository? medicationRepository;
  final VoidCallback? onLogout;
  final ValueChanged<Child>? onHealthUpdated;
  final VoidCallback? onOpenNotifications;

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
      childName: widget.overview.child.fullName,
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
          childName: widget.overview.child.fullName,
          onEdit: (onSaved) => _openProfileSheet(onSaved: onSaved),
        ),
      ),
    ));
  }

  void _openChildInfo() {
    showKSheet<void>(
      context,
      GardenVoiceScope(
        child: _ParentChildInfoSheet(
          overview: widget.overview,
          parentId: widget.parent.parentId,
          repository: widget.repository,
          medicationRepository: widget.medicationRepository,
          onChildUpdated: widget.onChildUpdated,
          onHealthUpdated: widget.onHealthUpdated,
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
      medicationRepository: widget.medicationRepository,
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                                '$relationship của ${child.displayName}',
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
                    tooltip: 'Chỉnh sửa thông tin',
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
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
                      child: const Text('Đọc báo cáo ›'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // ── Thông tin liên hệ ──────────────────────────────────
        _sectionTitle(context, 'Thông tin liên hệ'),
        KCard(
          child: Column(
            children: [
              if ((parent.email ?? '').trim().isNotEmpty)
                KInfoRow(label: 'Email', value: parent.email!.trim()),
              if (relationship != null && relationship.isNotEmpty)
                KInfoRow(label: 'Quan hệ với bé', value: relationship),
              if ((parent.phone ?? '').trim().isNotEmpty)
                KInfoRow(
                  label: 'Số điện thoại',
                  value: parent.phone!.trim(),
                  showEditIcon: false,
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: parent.phone!.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép số điện thoại'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        // ── Thông tin bé ───────────────────────────────────────
        _sectionTitle(context, 'Thông tin bé'),
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
                            child.fullName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if ((child.nickname ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
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
                      tooltip: 'Chỉnh sửa thông tin bé',
                      onPressed: _openEditChildSheet,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              KInfoRow(
                label: 'Họ và tên',
                value: child.fullName,
              ),
              KInfoRow(
                label: 'Biệt danh',
                value: (child.nickname ?? '').trim().isNotEmpty
                    ? child.nickname!.trim()
                    : 'Chưa thiết lập',
              ),
              if (child.dateOfBirth != null)
                KInfoRow(
                  label: 'Sinh ngày',
                  value: formatChildAge(child.dateOfBirth!).isNotEmpty
                      ? '${kDateLabel(child.dateOfBirth!)} (${formatChildAge(child.dateOfBirth!)})'
                      : kDateLabel(child.dateOfBirth!),
                ),
              if (child.gender != null && child.gender!.trim().isNotEmpty)
                KInfoRow(
                  label: 'Giới tính',
                  value: formatGender(child.gender),
                ),
              KInfoRow(label: 'Lớp', value: widget.overview.className),
              KInfoRow(
                  label: 'Giáo viên chủ nhiệm',
                  value: widget.overview.teacherName),
              if (child.allergy != null)
                KInfoRow(
                  label: 'Dị ứng',
                  value: child.allergy!,
                  danger: true,
                  icon: Icons.warning_amber_rounded,
                ),
              KInfoRow(
                label: 'Hồ sơ sức khỏe',
                value: switch (child.allergyStatus) {
                  'present' => 'Có dị ứng',
                  'none' => 'Không có dị ứng',
                  _ => 'Chưa khai báo',
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
                label: 'Đổi mật khẩu',
                trailing: Icon(Icons.chevron_right,
                    size: 18, color: context.k.inkFaint),
                onTap: () => showChangePasswordBottomSheet(context),
              ),
              const Divider(height: 1),
              _settingsRow(
                context,
                icon: Icons.rate_review_outlined,
                label: 'Góp ý & Cải thiện ứng dụng',
                trailing: Icon(Icons.chevron_right,
                    size: 18, color: context.k.inkFaint),
                onTap: () => showBugReportBottomSheet(context),
              ),
              const Divider(height: 1),
              _settingsRow(
                context,
                icon: Icons.notifications_outlined,
                label: 'Thông báo đẩy',
                subtitle: 'Nhận thông báo khi có báo cáo mới',
                trailing: Switch(value: _pushEnabled, onChanged: _setPush),
              ),
              const Divider(height: 1),
              _settingsRow(
                context,
                icon: Icons.info_outline,
                label: 'Về KinderLog',
                trailing: Text('v1.0.0',
                    style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        KButton(
          label: 'Đăng xuất',
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
    final child = widget.overview.child;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 16;

    return ColoredBox(
      color: k.canvas,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tài khoản',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: k.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Thông báo',
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
                              'Phụ huynh bé ${child.displayName}',
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
          _accountSectionTitle(context, 'Gia đình'),
          Column(
            children: [
              _accountMenuRow(
                key: const ValueKey('parent-contact-menu'),
                icon: 'assets/garden_voice/account_phone.svg',
                label: 'Thông tin liên hệ',
                onTap: _openContactScreen,
              ),
              _accountMenuRow(
                key: const ValueKey('parent-child-menu'),
                icon: 'assets/garden_voice/account_heart.svg',
                label: 'Thông tin bé · Hồ sơ sức khỏe',
                subtitle: 'Dị ứng và lưu ý chăm sóc',
                onTap: _openChildInfo,
              ),
            ],
          ),
          _accountSectionTitle(context, 'Tùy chọn'),
          Column(
            children: [
              _accountMenuRow(
                icon: 'assets/garden_voice/account_bell.svg',
                label: 'Thông báo đẩy',
                subtitle: _pushEnabled
                    ? 'Đã bật trên thiết bị'
                    : 'Đã tắt trên thiết bị',
                trailing: Switch(value: _pushEnabled, onChanged: _setPush),
              ),
            ],
          ),
          _accountSectionTitle(context, 'Cài đặt & hỗ trợ'),
          Column(
            children: [
              _accountMenuRow(
                icon: 'assets/garden_voice/account_lock.svg',
                label: 'Đổi mật khẩu',
                onTap: () => showChangePasswordBottomSheet(context),
              ),
              _accountMenuRow(
                icon: 'assets/garden_voice/account_bug.svg',
                label: 'Báo lỗi & góp ý',
                onTap: () => showBugReportBottomSheet(context),
              ),
              _accountMenuRow(
                icon: 'assets/garden_voice/account_info.svg',
                label: 'Về KinderLog',
                subtitle: 'Phiên bản 1.0.0',
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
            label: const Text('Đăng xuất'),
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

class ParentContactScreen extends StatefulWidget {
  const ParentContactScreen({
    super.key,
    required this.parent,
    required this.childName,
    required this.onEdit,
  });

  final Parent parent;
  final String childName;
  final void Function(
    void Function(String phone, String? email, String? relationship) onSaved,
  ) onEdit;

  @override
  State<ParentContactScreen> createState() => _ParentContactScreenState();
}

class _ParentContactScreenState extends State<ParentContactScreen> {
  late String? _phone = widget.parent.phone;
  late String? _email = widget.parent.email;
  late String? _relationship = widget.parent.relationship;

  void _edit() => widget.onEdit((phone, email, relationship) {
        setState(() {
          _phone = phone;
          _email = email;
          _relationship = relationship;
        });
      });

  String _maskedEmail(String? value) {
    final email = value?.trim() ?? '';
    final at = email.indexOf('@');
    return at < 0
        ? (email.isEmpty ? 'Chưa cập nhật' : email)
        : '${email.substring(0, at)}@…';
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone?.trim() ?? '';
    return Scaffold(
      backgroundColor: context.k.canvas,
      appBar: KAppBar(
          title: 'Thông tin liên hệ',
          onBack: () => Navigator.maybePop(context)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Tài khoản phụ huynh của bé ${widget.childName}',
              style: TextStyle(
                  fontSize: 14, height: 1.4, color: context.k.inkSoft),
            ),
            const SizedBox(height: 14),
            _contactCard(context, 'Họ và tên', widget.parent.fullName),
            const SizedBox(height: 14),
            Semantics(
              button: phoneCallUri(phone) != null,
              label: 'Sao chép số điện thoại',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: phoneCallUri(phone) == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Đã sao chép số điện thoại')),
                        );
                      },
                child: _contactCard(
                  context,
                  'Số điện thoại',
                  phone.isEmpty ? 'Chưa cập nhật' : maskedPhone(phone),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _contactCard(context, 'Email', _maskedEmail(_email)),
            const SizedBox(height: 14),
            _contactCard(
              context,
              'Quan hệ với bé',
              _relationship?.trim().isNotEmpty == true
                  ? _relationship!.trim()
                  : 'Chưa cập nhật',
            ),
            const SizedBox(height: 14),
            KButton(label: 'Chỉnh sửa thông tin', onPressed: _edit),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(BuildContext context, String label, String value) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: context.k.surfaceSunken,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: context.k.brand)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 16, height: 1.4, color: context.k.ink)),
          ],
        ),
      );
}

class _ParentChildInfoSheet extends StatefulWidget {
  const _ParentChildInfoSheet({
    required this.overview,
    required this.parentId,
    required this.repository,
    required this.medicationRepository,
    required this.onChildUpdated,
    required this.onHealthUpdated,
  });

  final ChildOverview overview;
  final String parentId;
  final HttpDashboardRepository? repository;
  final HttpMedicationRepository? medicationRepository;
  final ValueChanged<Child>? onChildUpdated;
  final ValueChanged<Child>? onHealthUpdated;

  @override
  State<_ParentChildInfoSheet> createState() => _ParentChildInfoSheetState();
}

class _ParentChildInfoSheetState extends State<_ParentChildInfoSheet> {
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

  String _initials(String name) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    return words
        .toList()
        .reversed
        .take(2)
        .toList()
        .reversed
        .map((word) => String.fromCharCode(word.runes.first))
        .join()
        .toUpperCase();
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
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Thông tin bé',
                    style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: context.k.ink)),
              ),
              IconButton(
                tooltip: 'Chỉnh sửa thông tin bé',
                onPressed: _editChild,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Đóng',
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
                            _initials(child.fullName),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.k.surface),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(child.fullName,
                            style: TextStyle(
                                fontSize: 16,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: context.k.ink)),
                        Text(
                          [
                            if ((child.nickname ?? '').trim().isNotEmpty)
                              'Biệt danh: ${child.nickname!.trim()}',
                            if (overview.className.trim().isNotEmpty)
                              'Lớp ${overview.className.trim()}',
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
                            label: 'Ngày sinh',
                            value:
                                '${kDateLabel(dateOfBirth)}${formatChildAge(dateOfBirth).isEmpty ? '' : ' · ${formatChildAge(dateOfBirth)}'}',
                          ),
                        if (overview.teacherName.trim().isNotEmpty)
                          KInfoRow(
                              label: 'Giáo viên chủ nhiệm',
                              value: overview.teacherName),
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
                      medicationRepository: widget.medicationRepository,
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
                              Text('Hồ sơ sức khỏe',
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
                        Text('Xem ›',
                            style: TextStyle(
                                fontSize: 12, color: context.k.accentDeep)),
                      ],
                    ),
                  ),
                  if (phoneAvailable) ...[
                    const SizedBox(height: 12),
                    KButton(
                      label: 'Gọi giáo viên chủ nhiệm',
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
        Text('Bạn có muốn đăng xuất không ?',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: KButton(
                label: 'Hủy',
                secondary: true,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KButton(
                label: 'Đăng xuất',
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
