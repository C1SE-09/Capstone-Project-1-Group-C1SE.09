// frontend/lib/features/kindergarten_dashboard/screens/teacher_account_screen.dart
// =================================================================================
// Tab Tài khoản của Giáo viên (Teacher Account):
// - Thông tin giáo viên, lớp phụ trách, đổi mật khẩu, góp ý bug report, đăng xuất.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart'
    as domain_class;
import 'package:adark_frontend/features/kindergarten_dashboard/screens/bug_report_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme_controller.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class TeacherAccountScreen extends StatefulWidget {
  const TeacherAccountScreen({
    super.key,
    required this.onLogout,
    this.onSelectClass,
    this.onOpenNotifications,
    this.notificationCount,
    this.schoolName = 'Mầm non Hoa Hướng Dương',
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.repository,
    this.classRepository,
  });

  final VoidCallback onLogout;
  final VoidCallback? onSelectClass;
  final VoidCallback? onOpenNotifications;
  final int? notificationCount;
  final String schoolName;
  final String classId;
  final HttpDashboardRepository? repository;
  final HttpClassDataRepository? classRepository;

  @override
  State<TeacherAccountScreen> createState() => _TeacherAccountScreenState();
}

class _TeacherAccountScreenState extends State<TeacherAccountScreen> {
  late final HttpDashboardRepository repository =
      widget.repository ?? HttpDashboardRepository();
  late final HttpClassDataRepository classRepository =
      widget.classRepository ?? HttpClassDataRepository();
  late Future<_AccountData> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<_AccountData> _load() async {
    final values = await Future.wait([
      repository.getCurrentTeacher(),
      classRepository.getClassInfo(widget.classId),
      repository.getClassChildren(widget.classId),
    ]);
    final info = values[1] as domain_class.ClassInfo;
    return _AccountData(
      values[0] as Teacher,
      info.name,
      (values[2] as List).length,
    );
  }

  void _confirmLogout() {
    showKSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn có muốn đăng xuất không ?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                  icon: Icons.logout,
                  onPressed: widget.onLogout,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(_AccountData data) {
    showKSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.teacher.fullName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          KInfoRow(
            label: 'Số điện thoại',
            value: data.teacher.phone ?? 'Chưa cập nhật',
          ),
          const Divider(),
          KInfoRow(
            label: 'Email',
            value: data.teacher.email.isEmpty
                ? 'Chưa cập nhật'
                : data.teacher.email,
          ),
          const Divider(),
          KInfoRow(
            label: 'Lớp phụ trách',
            value: '${data.className} · ${data.childCount} trẻ',
          ),
        ],
      ),
    );
  }

  void _openThemeSelector() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const GardenVoiceScope(
          child: Scaffold(
            body: ThemeSelector(),
          ),
        ),
      ),
    );
  }

  static String _displayTeacherName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Giáo viên';
    if (trimmed.startsWith('Cô ') || trimmed.startsWith('Thầy ')) {
      return trimmed;
    }
    return 'Cô $trimmed';
  }

  static String _shortThemeBadgeLabel(ThemeMode mode) =>
      mode == ThemeMode.dark ? 'Tối' : 'Sáng';

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<_AccountData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => future = _load()),
              child: const Text('Không tải được tài khoản · Thử lại'),
            ),
          );
        }
        final data = snapshot.data!;
        final teacher = data.teacher;
        final className = data.className;
        final k = context.k;

        return ColoredBox(
          color: k.canvas,
          child: RefreshIndicator(
            onRefresh: () async {
              final a = await _load();
              if (mounted) setState(() => future = Future.value(a));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: double.infinity,
                    minHeight: 226,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -17,
                        right: -17,
                        bottom: 0,
                        height: 126,
                        child: IgnorePointer(
                          child: Image.asset(
                            'assets/garden_voice/books_v2.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 21,
                        top: 39,
                        right: 84,
                        child: Text(
                          'Tài khoản',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.24,
                            color: k.ink,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 26,
                        top: 24,
                        child: _AccountNotificationButton(
                          count: widget.notificationCount,
                          onTap: widget.onOpenNotifications,
                        ),
                      ),
                      Positioned(
                        left: 14,
                        top: 88,
                        width: 90,
                        height: 90,
                        child: Image.asset(
                          'assets/garden_voice/teacher_portrait.png',
                          width: 90,
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(112, 91, 16, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayTeacherName(teacher.fullName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.24,
                                color: k.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Giáo viên chủ nhiệm',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                height: 1.24,
                                color: k.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$className · ${widget.schoolName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.24,
                                color: k.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _showProfileSheet(data),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Xem hồ sơ',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.24,
                                      color: k.brand,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SvgPicture.asset(
                                    'assets/garden_voice/chevron_right.svg',
                                    width: 19,
                                    height: 19,
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
                const _GroupTitle('Cá nhân'),
                _AccountSectionCard(
                  children: [
                    _AccountMenuRow(
                      iconAsset: 'assets/garden_voice/account_user_round.svg',
                      iconTileColor: k.okTint,
                      label: 'Thông tin liên hệ',
                      onTap: () => _showProfileSheet(data),
                    ),
                  ],
                ),
                const _GroupTitle('Tùy chọn'),
                _AccountSectionCard(
                  children: [
                    _AccountMenuRow(
                      iconAsset: 'assets/garden_voice/account_bell.svg',
                      iconTileColor: k.accentTint,
                      label: 'Thông báo',
                      onTap: widget.onOpenNotifications,
                    ),
                    Divider(height: 0.6, thickness: 0.6, color: k.line),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeController.instance,
                      builder: (context, mode, _) => _AccountMenuRow(
                        iconAsset: 'assets/garden_voice/account_palette.svg',
                        iconTileColor: k.activityRowTint,
                        label: 'Giao diện',
                        badgeText: _shortThemeBadgeLabel(mode),
                        onTap: _openThemeSelector,
                      ),
                    ),
                    Divider(height: 0.6, thickness: 0.6, color: k.line),
                    _AccountMenuRow(
                      iconAsset: 'assets/garden_voice/account_settings.svg',
                      iconTileColor: k.sleepRowTint,
                      label: 'Đổi mật khẩu',
                      onTap: () => context.push('/change-password'),
                    ),
                  ],
                ),
                const _GroupTitle('Hỗ trợ'),
                _AccountSectionCard(
                  children: [
                    _AccountMenuRow(
                      iconAsset: 'assets/garden_voice/account_help.svg',
                      iconTileColor: k.okTint,
                      label: 'Trợ giúp & Hỏi đáp',
                      onTap: () => showBugReportBottomSheet(context),
                    ),
                    Divider(height: 0.6, thickness: 0.6, color: k.line),
                    _AccountMenuRow(
                      iconAsset: 'assets/garden_voice/account_bug.svg',
                      iconTileColor: k.badTint,
                      label: 'Báo lỗi nhanh',
                      onTap: () => showBugReportBottomSheet(context),
                    ),
                    Divider(height: 0.6, thickness: 0.6, color: k.line),
                    _AccountMenuRow(
                      iconAsset: 'assets/garden_voice/account_info.svg',
                      iconTileColor: k.activityRowTint,
                      label: 'Về KinderLog',
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 6),
                  child: Divider(height: 0.6, thickness: 0.6, color: k.line),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: InkWell(
                    onTap: _confirmLogout,
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 42),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/garden_voice/account_logout.svg',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Đăng xuất',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.24,
                                  color: k.badText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return context.k.isGardenVoice
        ? content
        : GardenVoiceScope(child: content);
  }
}

class _AccountData {
  const _AccountData(this.teacher, this.className, this.childCount);
  final Teacher teacher;
  final String className;
  final int childCount;
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(21, 14, 21, 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.24,
            color: context.k.ink,
          ),
        ),
      );
}

class _AccountSectionCard extends StatelessWidget {
  const _AccountSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        decoration: BoxDecoration(
          color: k.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A102737),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _AccountMenuRow extends StatelessWidget {
  const _AccountMenuRow({
    required this.iconAsset,
    required this.iconTileColor,
    required this.label,
    this.badgeText,
    this.onTap,
  });

  final String iconAsset;
  final Color iconTileColor;
  final String label;
  final String? badgeText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 47),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconTileColor,
                borderRadius: BorderRadius.circular(19),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                iconAsset,
                width: 22.8,
                height: 22.8,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.24,
                  color: k.ink,
                ),
              ),
            ),
            if (badgeText != null) ...[
              Container(
                constraints: const BoxConstraints(minHeight: 28),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: k.okTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.24,
                    color: k.brand,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            SvgPicture.asset(
              'assets/garden_voice/account_chevron_right.svg',
              width: 17,
              height: 17,
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: row,
    );
  }
}

class _AccountNotificationButton extends StatelessWidget {
  const _AccountNotificationButton({this.count, this.onTap});

  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final unread = count ?? 0;
    return Material(
      color: k.activityRowTint,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                'assets/garden_voice/bell.svg',
                width: 27.6,
                height: 27.6,
              ),
              if (unread > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: k.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: k.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
