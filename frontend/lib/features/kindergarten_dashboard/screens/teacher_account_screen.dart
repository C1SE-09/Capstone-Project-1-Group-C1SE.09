// frontend/lib/features/kindergarten_dashboard/screens/teacher_account_screen.dart
// =================================================================================
// Tab Tài khoản của Giáo viên (Teacher Account):
// - Thông tin giáo viên, lớp phụ trách, đổi mật khẩu, góp ý bug report, đăng xuất.

import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_class_data_repository.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/auth/teacher.dart';
import 'package:adark_frontend/domain/entities/class/class_info.dart' as domain_class;
import 'package:adark_frontend/features/kindergarten_dashboard/screens/bug_report_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/change_password_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class TeacherAccountScreen extends StatefulWidget {
  const TeacherAccountScreen({
    super.key,
    required this.onLogout,
    this.onSelectClass,
    this.classId = 'aaaaaaaa-0000-0000-0000-000000000001',
    this.repository,
    this.classRepository,
  });

  final VoidCallback onLogout;
  final VoidCallback? onSelectClass;
  final String classId;
  final HttpDashboardRepository? repository;
  final HttpClassDataRepository? classRepository;

  @override
  State<TeacherAccountScreen> createState() => _TeacherAccountScreenState();
}

class _TeacherAccountScreenState extends State<TeacherAccountScreen> {
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late final HttpClassDataRepository classRepository = widget.classRepository ?? HttpClassDataRepository();
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
    return _AccountData(values[0] as Teacher, info.name, (values[2] as List).length);
  }

  void _confirmLogout() {
    showKSheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn có muốn đăng xuất không ?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: KButton(label: 'Hủy', secondary: true, onPressed: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(child: KButton(label: 'Đăng xuất', icon: Icons.logout, onPressed: widget.onLogout)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_AccountData>(
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

          return RefreshIndicator(
            onRefresh: () async {
              final a = await _load();
              if (mounted) setState(() => future = Future.value(a));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              children: [
                Text('Tài khoản', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 14),
                KCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Avatar(name: teacher.fullName, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(teacher.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            Text('Giáo viên · $className', style: TextStyle(fontSize: 13, color: context.k.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const _GroupTitle('Thông tin'),
                KCard(
                  child: Column(
                    children: [
                      _AccountRow(icon: Icons.phone_outlined, label: 'Số điện thoại', value: teacher.phone ?? 'Chưa cập nhật'),
                      const Divider(),
                      _AccountRow(
                        icon: Icons.school_outlined,
                        label: 'Lớp phụ trách',
                        value: className,
                      ),
                      const Divider(),
                      _AccountRow(icon: Icons.groups_outlined, label: 'Số trẻ', value: '${data.childCount} trẻ'),
                    ],
                  ),
                ),
                const _GroupTitle('Tùy chỉnh'),
                KCard(
                  child: Column(
                    children: [
                      _AccountRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Đổi mật khẩu',
                        chevron: true,
                        onTap: () => showChangePasswordBottomSheet(context),
                      ),
                      const Divider(),
                      const ThemeSelector(),
                      const Divider(),
                      _AccountRow(
                        icon: Icons.rate_review_outlined,
                        label: 'Góp ý & Cải thiện ứng dụng',
                        chevron: true,
                        onTap: () => showBugReportBottomSheet(context),
                      ),
                      const Divider(),
                      const _AccountRow(icon: Icons.info_outline, label: 'Về KinderLog', value: 'v1.0.0'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                KButton(label: 'Đăng xuất', icon: Icons.logout, secondary: true, large: true, onPressed: _confirmLogout),
              ],
            ),
          );
        },
      );
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
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
      );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.icon, required this.label, this.value, this.chevron = false, this.onTap});

  final IconData icon;
  final String label;
  final String? value;
  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: context.k.inkSoft),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          if (value != null) Text(value!, style: Theme.of(context).textTheme.bodySmall),
          if (chevron) Icon(Icons.chevron_right, size: 18, color: context.k.inkFaint),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, child: row);
    }
    return row;
  }
}
