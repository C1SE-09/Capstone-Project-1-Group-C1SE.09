// parent_account.dart
// =========================================================
// Tab "Tài khoản" của màn phụ huynh (design v4 — Figma Make):
// hero + quan hệ, nhận xét của cô, thông tin liên hệ (sửa SĐT),
// thông tin bé (sheet chi tiết), cài đặt, đăng xuất.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';

import '../theme.dart';
import '../widgets.dart';
import 'bug_report_sheet.dart';
import 'change_password_screen.dart';

/// Khoá lưu lựa chọn nhận thông báo đẩy trên máy.
const kParentPushPrefsKey = 'kinderlog-parent-push';

/// SĐT hợp lệ: khớp đúng pattern backend `^0\d{9,10}$`.
bool isValidParentPhone(String value) => RegExp(r'^0\d{9,10}$').hasMatch(value.trim());

/// Ngày gắn bó = số ngày kể từ lúc tạo tài khoản (createdAt).
int parentJourneyDays(DateTime? createdAt, {DateTime? now}) {
  if (createdAt == null) return 0;
  return (now ?? DateTime.now()).difference(createdAt).inDays.clamp(0, 100000);
}

class ParentAccount extends StatefulWidget {
  const ParentAccount({
    super.key,
    required this.parent,
    required this.overview,
    required this.reports,
    required this.onOpenReport,
    required this.onPhoneUpdated,
    this.repository,
    this.onLogout,
  });

  final Parent parent;
  final ChildOverview overview;
  final List<DailyReport> reports;
  final ValueChanged<DailyReport> onOpenReport;
  final ValueChanged<String> onPhoneUpdated;
  final HttpDashboardRepository? repository;
  final VoidCallback? onLogout;

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
      await (enabled ? service.registerCurrentDevice() : service.deleteCurrentDevice());
    } catch (_) {
      // Thiếu cấu hình Firebase thì bỏ qua, app vẫn chạy bình thường.
    }
  }

  void _openPhoneSheet() {
    showParentPhoneSheet(
      context,
      parent: widget.parent,
      repository: widget.repository,
      onSaved: widget.onPhoneUpdated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.overview.child;
    final parent = widget.parent;
    final relationship = parent.relationship?.trim();
    final latestReport = widget.reports.isEmpty ? null : widget.reports.first;

    return ListView(
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                // 14% trắng trên nền brand đậm: chữ trắng đạt ~5:1
                                color: Colors.white.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$relationship của ${child.displayName}',
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _openPhoneSheet,
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
        if (latestReport != null && (latestReport.summaryText?.trim().isNotEmpty ?? false)) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: context.k.brand, width: 3)),
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
                        style: TextStyle(fontSize: 12, color: context.k.inkFaint),
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
                  onTap: _openPhoneSheet,
                ),
            ],
          ),
        ),

        // ── Thông tin bé ───────────────────────────────────────
        _sectionTitle(context, 'Thông tin bé'),
        KCard(
          child: Column(
            children: [
              InkWell(
                onTap: () => showParentChildSheet(context, overview: widget.overview),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Avatar(name: child.fullName, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          child.fullName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: context.k.inkFaint),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              if ((child.nickname ?? '').trim().isNotEmpty)
                KInfoRow(label: 'Biệt danh', value: child.nickname!.trim()),
              KInfoRow(label: 'Lớp', value: widget.overview.className),
              KInfoRow(label: 'Giáo viên chủ nhiệm', value: widget.overview.teacherName),
              if (child.allergy != null)
                KInfoRow(
                  label: 'Dị ứng',
                  value: child.allergy!,
                  danger: true,
                  icon: Icons.warning_amber_rounded,
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
                trailing: Icon(Icons.chevron_right, size: 18, color: context.k.inkFaint),
                onTap: () => showChangePasswordBottomSheet(context),
              ),
              const Divider(height: 1),
              _settingsRow(
                context,
                icon: Icons.rate_review_outlined,
                label: 'Góp ý & Cải thiện ứng dụng',
                trailing: Icon(Icons.chevron_right, size: 18, color: context.k.inkFaint),
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
              const ThemeSelector(),
              const Divider(height: 1),
              _settingsRow(
                context,
                icon: Icons.info_outline,
                label: 'Về KinderLog',
                trailing: Text('v1.0.0', style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
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
              : () => showParentLogoutSheet(context, onLogout: widget.onLogout!),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.k.ink),
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
                  Text(subtitle, style: TextStyle(fontSize: 12, color: context.k.inkFaint)),
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

/// Sheet sửa số điện thoại — PUT /api/parent/{id} (self-service).
Future<void> showParentPhoneSheet(
  BuildContext context, {
  required Parent parent,
  required ValueChanged<String> onSaved,
  HttpDashboardRepository? repository,
}) {
  return showKSheet(
    context,
    _ParentPhoneForm(parent: parent, repository: repository, onSaved: onSaved),
  );
}

class _ParentPhoneForm extends StatefulWidget {
  const _ParentPhoneForm({required this.parent, required this.onSaved, this.repository});

  final Parent parent;
  final ValueChanged<String> onSaved;
  final HttpDashboardRepository? repository;

  @override
  State<_ParentPhoneForm> createState() => _ParentPhoneFormState();
}

class _ParentPhoneFormState extends State<_ParentPhoneForm> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.parent.phone ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _controller.text.trim();
    if (!isValidParentPhone(phone)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository?.updateMyPhone(widget.parent.parentId, phone);
      if (!mounted) return;
      widget.onSaved(phone);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu số điện thoại')),
      );
    } on ClassDataException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (error.statusCode) {
          409 => 'Số điện thoại đã được sử dụng',
          422 => 'Số điện thoại không hợp lệ',
          _ => 'Không lưu được số điện thoại, vui lòng thử lại.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Không lưu được số điện thoại, vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = isValidParentPhone(_controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Chỉnh sửa thông tin', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            helperText: '10–11 số, bắt đầu bằng 0',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 13, color: context.k.bad)),
        ],
        const SizedBox(height: 20),
        KButton(
          label: _saving ? 'Đang lưu…' : 'Lưu',
          onPressed: valid && !_saving ? _save : null,
        ),
      ],
    );
  }
}

/// Sheet chi tiết bé: thông tin, dị ứng, liên hệ giáo viên (bấm để copy).
Future<void> showParentChildSheet(
  BuildContext context, {
  required ChildOverview overview,
}) {
  return showKSheet(context, _ParentChildSheetBody(overview: overview));
}

class _ParentChildSheetBody extends StatelessWidget {
  const _ParentChildSheetBody({required this.overview});

  final ChildOverview overview;

  Future<void> _copyPhone(BuildContext context, String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã copy số điện thoại')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = overview.child;
    final dob = child.dateOfBirth;
    final phone = overview.teacherPhone?.trim();
    final allergy = child.allergy; // đã bỏ "Không có" + tiền tố "Dị ứng"

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Avatar(name: child.fullName, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      if ((child.nickname ?? '').trim().isNotEmpty)
                        Text(
                          'Biệt danh: ${child.nickname!.trim()}',
                          style: TextStyle(fontSize: 13, color: context.k.inkSoft),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dob != null) KInfoRow(label: 'Ngày sinh', value: kDateLabel(dob)),
            KInfoRow(label: 'Lớp', value: overview.className),
            if ((overview.roomNumber ?? '').trim().isNotEmpty)
              KInfoRow(label: 'Phòng', value: overview.roomNumber!.trim()),
            KInfoRow(label: 'Giáo viên chủ nhiệm', value: overview.teacherName),
            if (allergy != null && allergy.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.k.badTint,
                  borderRadius: BorderRadius.circular(KRadii.control),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: context.k.bad),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dị ứng $allergy',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.k.bad),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 16),
              KButton(
                label: phone,
                icon: Icons.copy_rounded,
                onPressed: () => _copyPhone(context, phone),
              ),
              const SizedBox(height: 6),
              Text(
                'Bấm để copy số điện thoại của cô.',
                style: TextStyle(fontSize: 12, color: context.k.inkFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
        Text('Bạn có muốn đăng xuất không ?', style: Theme.of(context).textTheme.titleMedium),
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
