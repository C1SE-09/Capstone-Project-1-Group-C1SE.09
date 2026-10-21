// parent_account.dart
// =========================================================
// Tab "Tài khoản" của màn phụ huynh (design v4 — Figma Make):
// hero + quan hệ, nhận xét của cô, thông tin liên hệ (sửa SĐT),
// thông tin bé (sheet chi tiết), cài đặt, đăng xuất.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adark_frontend/core/notifications/push_notification_service.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/domain/entities/auth/parent.dart';
import 'package:adark_frontend/domain/entities/child/child.dart';
import 'package:adark_frontend/domain/entities/child/child_overview.dart';
import 'package:adark_frontend/domain/entities/report/daily_report.dart';

import '../theme.dart';
import '../widgets.dart';
import 'bug_report_sheet.dart';
import 'change_password_screen.dart';

/// Khoá lưu lựa chọn nhận thông báo đẩy trên máy.
const kParentPushPrefsKey = 'kinderlog-parent-push';

/// Danh sách quan hệ mặc định với bé.
const kRelationshipOptions = ['Bố', 'Mẹ', 'Ông', 'Bà', 'Người giám hộ'];

/// SĐT hợp lệ: đúng 10 chữ số, bắt đầu bằng 0.
bool isValidParentPhone(String value) => RegExp(r'^0\d{9}$').hasMatch(value.trim());

/// Email hợp lệ: cho phép để trống hoặc đúng định dạng email.
bool isValidParentEmail(String value) {
  final v = value.trim();
  if (v.isEmpty) return true;
  return RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z0-9]{2,}$').hasMatch(v);
}

/// Ngày gắn bó = số ngày kể từ lúc tạo tài khoản (createdAt).
int parentJourneyDays(DateTime? createdAt, {DateTime? now}) {
  if (createdAt == null) return 0;
  return (now ?? DateTime.now()).difference(createdAt).inDays.clamp(0, 100000);
}

/// Định dạng số tuổi của trẻ từ ngày sinh (ví dụ: "4 tuổi" hoặc "3 tuổi 8 tháng").
String formatChildAge(DateTime? dob, {DateTime? now}) {
  if (dob == null) return '';
  final current = now ?? DateTime.now();
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
    this.onLogout,
  });

  final Parent parent;
  final ChildOverview overview;
  final List<DailyReport> reports;
  final ValueChanged<DailyReport> onOpenReport;
  final ValueChanged<String> onPhoneUpdated;
  final void Function(String phone, String? email, String? relationship)? onParentUpdated;
  final ValueChanged<Child>? onChildUpdated;
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

  void _openProfileSheet() {
    showParentProfileSheet(
      context,
      parent: widget.parent,
      repository: widget.repository,
      onSaved: (phone, email, relationship) {
        widget.onPhoneUpdated(phone);
        widget.onParentUpdated?.call(phone, email, relationship);
      },
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
                  showEditIcon: false,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: parent.phone!.trim()));
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if ((child.nickname ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Biệt danh: ${child.nickname!.trim()}',
                                style: TextStyle(fontSize: 13, color: context.k.inkSoft),
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

/// Sheet sửa thông tin phụ huynh (SĐT, Email, Quan hệ với bé) — PUT /api/parent/{id}.
Future<void> showParentProfileSheet(
  BuildContext context, {
  required Parent parent,
  required void Function(String phone, String? email, String? relationship) onSaved,
  HttpDashboardRepository? repository,
}) {
  return showKSheet(
    context,
    _ParentProfileForm(parent: parent, repository: repository, onSaved: onSaved),
  );
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

class _ParentProfileForm extends StatefulWidget {
  const _ParentProfileForm({required this.parent, required this.onSaved, this.repository});

  final Parent parent;
  final void Function(String phone, String? email, String? relationship) onSaved;
  final HttpDashboardRepository? repository;

  @override
  State<_ParentProfileForm> createState() => _ParentProfileFormState();
}

class _ParentProfileFormState extends State<_ParentProfileForm> {
  late final TextEditingController _phoneController =
      TextEditingController(text: widget.parent.phone ?? '');
  late final TextEditingController _emailController =
      TextEditingController(text: widget.parent.email ?? '');
  late String? _relationship = widget.parent.relationship?.trim();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (_relationship != null && !kRelationshipOptions.contains(_relationship)) {
      _relationship = null;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    if (!isValidParentPhone(phone)) return;
    if (!isValidParentEmail(email)) {
      setState(() => _error = 'Email không hợp lệ. Vui lòng kiểm tra lại.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.repository?.updateParentProfile(
        widget.parent.parentId,
        phone: phone,
        email: email.isEmpty ? null : email,
        relationship: _relationship,
      );
      if (!mounted) return;
      widget.onSaved(phone, email.isEmpty ? null : email, _relationship);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thông tin phụ huynh')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = getFriendlyErrorMessage(
          error,
          fallback: 'Không lưu được thông tin, vui lòng thử lại.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final validPhone = isValidParentPhone(_phoneController.text);
    final validEmail = isValidParentEmail(_emailController.text);
    final canSave = validPhone && validEmail && !_saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Chỉnh sửa thông tin', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          autofocus: true,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'Số điện thoại *',
            helperText: '10 chữ số, bắt đầu bằng 0',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'Email',
            helperText: 'vd: phuhuynh@gmail.com',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _relationship,
          decoration: const InputDecoration(
            labelText: 'Quan hệ với bé',
          ),
          items: kRelationshipOptions
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (val) => setState(() => _relationship = val),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 13, color: context.k.bad)),
        ],
        const SizedBox(height: 20),
        KButton(
          label: _saving ? 'Đang lưu…' : 'Lưu thay đổi',
          onPressed: canSave ? _save : null,
        ),
      ],
    );
  }
}

/// Sheet chỉnh sửa thông tin của bé (họ tên, biệt danh, ngày sinh, giới tính, dị ứng).
Future<void> showParentChildEditSheet(
  BuildContext context, {
  required Child child,
  required String parentId,
  required HttpDashboardRepository? repository,
  required ValueChanged<Child> onSaved,
}) {
  return showKSheet(
    context,
    _ParentChildEditSheetBody(
      child: child,
      parentId: parentId,
      repository: repository,
      onSaved: onSaved,
    ),
  );
}

class _ParentChildEditSheetBody extends StatefulWidget {
  const _ParentChildEditSheetBody({
    required this.child,
    required this.parentId,
    required this.repository,
    required this.onSaved,
  });

  final Child child;
  final String parentId;
  final HttpDashboardRepository? repository;
  final ValueChanged<Child> onSaved;

  @override
  State<_ParentChildEditSheetBody> createState() => _ParentChildEditSheetBodyState();
}

class _ParentChildEditSheetBodyState extends State<_ParentChildEditSheetBody> {
  late final TextEditingController _nameController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _allergyController;
  DateTime? _selectedDob;
  String _selectedGender = 'male';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child.fullName);
    _nicknameController = TextEditingController(text: widget.child.nickname ?? '');
    _allergyController = TextEditingController(text: widget.child.medicalAllergies ?? '');
    _selectedDob = widget.child.dateOfBirth;
    final g = (widget.child.gender ?? '').trim().toLowerCase();
    _selectedGender = (g == 'female' || g == 'nữ' || g == 'nu') ? 'female' : 'male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _allergyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 3, now.month, now.day),
      firstDate: DateTime(2015),
      lastDate: now,
      helpText: 'Chọn ngày sinh của bé',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Họ và tên của bé không được để trống.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.repository?.updateChildInfo(
        parentId: widget.parentId,
        childId: widget.child.childId,
        fullName: name,
        nickname: _nicknameController.text.trim().isEmpty ? null : _nicknameController.text.trim(),
        dateOfBirth: _selectedDob,
        gender: _selectedGender,
        medicalAllergies: _allergyController.text.trim().isEmpty ? null : _allergyController.text.trim(),
      );

      if (!mounted) return;
      if (updated != null) {
        widget.onSaved(updated);
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thông tin của bé thành công')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = getFriendlyErrorMessage(
          e,
          fallback: 'Không thể lưu thông tin của bé. Vui lòng thử lại sau.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chỉnh sửa thông tin bé',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Họ và tên
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Họ và tên của bé *',
                hintText: 'Ví dụ: Nguyễn Minh An',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 14),

            // Biệt danh
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Tên gọi ở nhà (Biệt danh)',
                hintText: 'Ví dụ: Bơ, Sóc, Bon...',
                prefixIcon: Icon(Icons.favorite_outline),
              ),
            ),
            const SizedBox(height: 14),

            // Ngày sinh
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(KRadii.control),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ngày sinh của bé',
                  prefixIcon: Icon(Icons.cake_outlined),
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                ),
                child: Text(
                  _selectedDob != null
                      ? '${kDateLabel(_selectedDob!)} (${formatChildAge(_selectedDob!)})'
                      : 'Chọn ngày sinh',
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedDob != null ? context.k.ink : context.k.inkFaint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Giới tính
            Text(
              'Giới tính',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.k.ink),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _GenderOption(
                    label: 'Bé trai (Nam)',
                    icon: Icons.male_rounded,
                    isSelected: _selectedGender == 'male',
                    onTap: () => setState(() => _selectedGender = 'male'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GenderOption(
                    label: 'Bé gái (Nữ)',
                    icon: Icons.female_rounded,
                    isSelected: _selectedGender == 'female',
                    onTap: () => setState(() => _selectedGender = 'female'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Dị ứng & Lưu ý sức khỏe
            TextField(
              controller: _allergyController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Dị ứng & Lưu ý sức khỏe',
                hintText: 'Ghi chú các dị ứng đồ ăn, phấn hoa, thuốc hoặc dặn dò cho cô...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.healing_outlined),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(fontSize: 13, color: context.k.bad)),
            ],

            const SizedBox(height: 24),
            KButton(
              label: _saving ? 'Đang lưu thông tin…' : 'Lưu thay đổi',
              icon: Icons.save_outlined,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KRadii.control),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? context.k.brand.withValues(alpha: .08) : context.k.surface,
          borderRadius: BorderRadius.circular(KRadii.control),
          border: Border.all(
            color: isSelected ? context.k.brand : context.k.line,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? context.k.brand : context.k.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? context.k.brand : context.k.ink,
              ),
            ),
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
