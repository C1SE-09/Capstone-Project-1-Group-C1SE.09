import 'package:flutter/material.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/ui_types.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:adark_frontend/domain/entities/class/class_report_overview.dart' as legacy_overview;
import 'package:adark_frontend/features/kindergarten_dashboard/adapters/class_info_adapter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final ValueChanged<UserRole> onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserRole role = UserRole.teacher;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: KColors.brand, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.school_outlined, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text('KinderLog', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text(
            'Báo cáo hằng ngày cho lớp mầm non — chỉ cần kể, hệ thống lo phần còn lại.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: KColors.inkSoft),
          ),
          const SizedBox(height: 36),
          Text('Bạn là', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          _RoleCard(
            selected: role == UserRole.teacher,
            icon: Icons.school_outlined,
            title: 'Giáo viên',
            description: 'Ghi nhận và gửi báo cáo hằng ngày',
            onTap: () => setState(() => role = UserRole.teacher),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            selected: role == UserRole.parent,
            icon: Icons.people_outline,
            title: 'Phụ huynh',
            description: 'Xem báo cáo hằng ngày của con',
            onTap: () => setState(() => role = UserRole.parent),
          ),
          const Spacer(),
          KButton(label: 'Đăng nhập', large: true, onPressed: () => widget.onLogin(role)),
          const SizedBox(height: 12),
          const Center(child: Text('Bản demo · chưa có xác thực', style: TextStyle(fontSize: 12, color: KColors.inkFaint))),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.selected, required this.icon, required this.title, required this.description, required this.onTap});
  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? KColors.brandTint : KColors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? KColors.brand : KColors.line),
        borderRadius: BorderRadius.circular(KRadii.card),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(KRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? KColors.brand : KColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 21, color: selected ? Colors.white : KColors.inkSoft),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KColors.inkSoft)),
                  ],
                ),
              ),
              Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? KColors.brand : Colors.transparent,
                  border: Border.all(color: selected ? KColors.brand : KColors.lineStrong, width: 2),
                ),
                child: selected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClassSelectScreen extends StatefulWidget {
  const ClassSelectScreen({super.key, required this.onPick, this.repository});
  final ValueChanged<String> onPick;
  final HttpDashboardRepository? repository;
  @override
  State<ClassSelectScreen> createState() => _ClassSelectScreenState();
}

class _ClassSelectScreenState extends State<ClassSelectScreen> {
  late final HttpDashboardRepository repository = widget.repository ?? HttpDashboardRepository();
  late Future<List<legacy_overview.ClassReportOverview>> classesFuture;
  @override
  void initState() { super.initState(); classesFuture = repository.getTeacherClasses(); }
  // Renders repository loading, error, and class data states.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 42, 20, 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Chọn lớp', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4), Text('Chọn lớp bạn muốn ghi nhận hôm nay.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: KColors.inkSoft)),
      const SizedBox(height: 24),
      Expanded(child: FutureBuilder<List<legacy_overview.ClassReportOverview>>(future: classesFuture, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Không tải được danh sách lớp.'), TextButton(onPressed: () => setState(() => classesFuture = repository.getTeacherClasses()), child: const Text('Thử lại'))]));
        final classes = (snapshot.data ?? []).map((item) => uiClassInfoFromOverview(item)).toList();
        if (classes.isEmpty) return const Center(child: Text('Chưa có lớp được phân công.'));
        return ListView(children: classes.map((item) => Padding(padding: const EdgeInsets.only(bottom: 12), child: KCard(onTap: () => widget.onPick(item.id), padding: const EdgeInsets.all(16), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: KColors.brandTint, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.groups_outlined, color: KColors.brand)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Lớp ${item.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)), Text(item.school, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: KColors.inkSoft)), Text('${item.count} trẻ · ${item.role}', style: Theme.of(context).textTheme.bodySmall)])), const Icon(Icons.chevron_right, color: KColors.inkFaint)])))).toList());
      }))
    ]));
}
