import 'package:flutter/material.dart';

import 'admin_data.dart';
import 'app_theme.dart';
import 'models.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    required this.darkMode,
    required this.onThemeChanged,
    this.onLogout,
    super.key,
  });

  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback? onLogout;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminTab _tab = AdminTab.overview;
  AdminCategory _category = AdminCategory.teachers;
  int _selectedDay = 0;
  String _query = '';
  final _searchController = TextEditingController();
  int _schoolIndex = 0;
  static const _schools = [
    'Trường Mầm Non Hướng Dương',
    'Trường Mầm Non Ánh Sao',
  ];
  final _teachers = [...initialTeachers];
  final _students = [...initialStudents];
  final _parents = [...initialParents];
  final _schedules = [...initialSchedules];

  List<ScheduleConflict> _conflictsFor(int day) {
    final items = _schedules.where((item) => item.day == day).toList();
    final result = <ScheduleConflict>[];
    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        final a = items[i];
        final b = items[j];
        if (!(a.start.compareTo(b.end) < 0 && a.end.compareTo(b.start) > 0)) {
          continue;
        }
        final sameRoom = a.room.trim().toLowerCase() ==
            b.room.trim().toLowerCase();
        final sameTeacher = a.teacherName.trim().toLowerCase() ==
            b.teacherName.trim().toLowerCase();
        if (!sameRoom && !sameTeacher) continue;
        final reason = sameRoom && sameTeacher
            ? 'Trùng phòng "${a.room}" và giáo viên "${a.teacherName}"'
            : sameRoom
                ? 'Trùng phòng "${a.room}"'
                : 'Trùng giáo viên "${a.teacherName}"';
        result.add(ScheduleConflict(
          a,
          b,
          '$reason giữa "${a.name}" và "${b.name}" '
              '(${a.start}–${a.end} và ${b.start}–${b.end})',
        ));
      }
    }
    return result;
  }

  int get _totalConflicts => List.generate(
        dayLabels.length,
        (day) => _conflictsFor(day).length,
      ).fold(0, (sum, count) => sum + count);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _mobileHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: _content(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
              selectedIndex: _tab.index,
              onDestinationSelected: (index) => setState(() {
                _tab = AdminTab.values[index];
                _query = '';
                _searchController.clear();
              }),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Tổng quan',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _totalConflicts > 0,
                    label: Text('$_totalConflicts'),
                    child: const Icon(Icons.tune_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _totalConflicts > 0,
                    label: Text('$_totalConflicts'),
                    child: const Icon(Icons.tune),
                  ),
                  label: 'Chức năng',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Tài khoản',
                ),
              ],
            ),
      ),
    );
  }

  Widget _brand({bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.local_florist, color: Colors.white),
        ),
        if (!compact) ...[
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KinderLog',
                style: TextStyle(
                  color: AppColors.brand,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'QUẢN TRỊ HỆ THỐNG',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _mobileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border:
            Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _brand(compact: true),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KinderLog',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('Quản trị hệ thống',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                tooltip: widget.darkMode ? 'Giao diện sáng' : 'Giao diện tối',
                onPressed: () => widget.onThemeChanged(!widget.darkMode),
                icon: Icon(
                    widget.darkMode ? Icons.light_mode : Icons.dark_mode),
              ),
              IconButton(
                tooltip: 'Thông báo',
                onPressed: () => _notify('Bạn không có thông báo mới'),
                icon: const Badge(
                  smallSize: 7,
                  child: Icon(Icons.notifications_none),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _schoolIndex,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.school_outlined),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: List.generate(
                    _schools.length,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text(
                        _schools[index],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  onChanged: (index) {
                    if (index == null) return;
                    setState(() => _schoolIndex = index);
                    _notify('Đã chuyển sang ${_schools[index]}');
                  },
                ),
              ),
              if (_tab == AdminTab.features) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: _addLabel,
                  onPressed: () => _showEditor(_category),
                  icon: const Icon(Icons.add),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String get _searchHint {
    if (_tab != AdminTab.features) return 'Tìm kiếm học sinh, lớp, giáo viên...';
    return switch (_category) {
      AdminCategory.teachers => 'Tìm giáo viên, số điện thoại, lớp...',
      AdminCategory.students => 'Tìm học sinh, lớp, dị ứng...',
      AdminCategory.parents => 'Tìm phụ huynh, con liên kết...',
      AdminCategory.schedules => 'Tìm tiết học, phòng, giáo viên...',
    };
  }

  String get _addLabel => switch (_category) {
        AdminCategory.teachers => 'Thêm giáo viên',
        AdminCategory.students => 'Thêm học sinh',
        AdminCategory.parents => 'Thêm phụ huynh',
        AdminCategory.schedules => 'Thêm lịch học',
      };

  Widget _content() => switch (_tab) {
        AdminTab.overview => _overview(),
        AdminTab.features => _features(),
        AdminTab.account => _account(),
      };

  Widget _heading(String title, String subtitle, {Widget? trailing}) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 5),
                Text(subtitle,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      );

  Widget _overview() {
    final q = _query.toLowerCase().trim();
    final classes = classProgress
        .where((item) =>
            '${item.className} ${item.grade} ${item.teacher}'
                .toLowerCase()
                .contains(q))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Tổng quan hệ thống',
          'Theo dõi hoạt động trường học, tiến độ báo cáo và tài nguyên hệ thống.',
        ),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          const columns = 2;
          const gap = 14.0;
          final width =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              _metric(width, Icons.groups_outlined, 'Tổng số học sinh', '342 bé',
                  '14 lớp học · 2 trường', AppColors.brand),
              _metric(width, Icons.check_circle_outline, 'Tiến độ báo cáo ngày',
                  '83,3%', '285 đã gửi · 57 bản nháp', AppColors.success),
              _metric(width, Icons.mic_none, 'Bản ghi âm giọng nói',
                  '148 file hôm nay', 'Tổng cộng: 1.250 file', AppColors.warning),
              _metric(
                  width,
                  Icons.people_outline,
                  'Nhân sự & Phụ huynh',
                  '${_teachers.length} giáo viên',
                  '${_parents.length} phụ huynh đang hoạt động',
                  AppColors.info),
            ],
          );
        }),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          final progress = _progressCard(classes);
          final status = Column(
            children: [
              _voiceCard(),
              const SizedBox(height: 16),
              _healthCard(),
            ],
          );
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: progress),
                    const SizedBox(width: 20),
                    SizedBox(width: 320, child: status),
                  ],
                )
              : Column(children: [progress, const SizedBox(height: 18), status]);
        }),
        const SizedBox(height: 20),
        _trendCard(),
      ],
    );
  }

  Widget _metric(double width, IconData icon, String label, String value,
      String detail, Color color) {
    return SizedBox(
      width: width,
      height: 164,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label)),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withAlpha(33),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(detail,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressCard(List<ClassProgress> classes) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            title: const Text('Tiến độ báo cáo theo lớp học trong ngày',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${classes.length} lớp phù hợp · Cập nhật thời gian thực'),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          if (classes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(42),
              child: Text('Không tìm thấy lớp hoặc giáo viên phù hợp.'),
            )
          else
            ...classes.map(
              (item) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.className,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(item.grade,
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(item.teacher,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${(item.progress * 100).round()}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 5),
                              LinearProgressIndicator(
                                value: item.progress,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _voiceCard() => _statusCard(
        title: 'Hàng đợi xử lý giọng nói STT',
        subtitle: '3 giờ 45 phút ghi âm',
        icon: Icons.mic_none,
        color: AppColors.warning,
        rows: const [
          ('Hoàn thành', '142 file', AppColors.success),
          ('Đang xử lý', '4 file', AppColors.warning),
          ('Lỗi xử lý', '2 file', AppColors.danger),
        ],
      );

  Widget _healthCard() => _statusCard(
        title: 'Tình trạng hạ tầng',
        subtitle: 'SystemHealthStats',
        icon: Icons.check_circle_outline,
        color: AppColors.success,
        rows: const [
          ('Cơ sở dữ liệu', 'Đang kết nối', AppColors.success),
          ('Redis Queue', 'Hoạt động tốt', AppColors.success),
          ('FastAPI', 'Ổn định', AppColors.success),
        ],
      );

  Widget _statusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<(String, String, Color)> rows,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 14),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: row.$3),
                    const SizedBox(width: 8),
                    Expanded(child: Text(row.$1, style: const TextStyle(fontSize: 12))),
                    Text(row.$2,
                        style: TextStyle(
                            color: row.$3,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Xu hướng báo cáo 7 ngày gần nhất',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Số báo cáo được tạo và gửi đến phụ huynh',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 18),
            SizedBox(
              height: 190,
              width: double.infinity,
              child: CustomPaint(painter: _TrendPainter(widget.darkMode)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _features() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Chức năng quản trị hệ thống',
          'Quản lý giáo viên, học sinh, phụ huynh và kiểm tra xung đột thời khóa biểu.',
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<AdminCategory>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: AdminCategory.teachers,
                  icon: const Icon(Icons.person_add_outlined),
                  label: Text('Giáo viên (${_teachers.length})')),
              ButtonSegment(
                  value: AdminCategory.students,
                  icon: const Icon(Icons.school_outlined),
                  label: Text('Học sinh (${_students.length})')),
              ButtonSegment(
                  value: AdminCategory.parents,
                  icon: const Icon(Icons.groups_outlined),
                  label: Text('Phụ huynh (${_parents.length})')),
              ButtonSegment(
                  value: AdminCategory.schedules,
                  icon: Badge(
                    isLabelVisible: _totalConflicts > 0,
                    label: Text('$_totalConflicts'),
                    child: const Icon(Icons.event_note_outlined),
                  ),
                  label: Text('Thời khóa biểu (${_schedules.length})')),
            ],
            selected: {_category},
            onSelectionChanged: (selected) => setState(() {
              _category = selected.first;
              _query = '';
              _searchController.clear();
            }),
          ),
        ),
        const SizedBox(height: 20),
        _searchField(),
        const SizedBox(height: 16),
        if (_category == AdminCategory.schedules)
          _scheduleList()
        else
          _peopleGrid(),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        isDense: true,
        hintText: _searchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () => setState(() {
                  _query = '';
                  _searchController.clear();
                }),
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }

  Widget _peopleGrid() {
    final q = _query.trim().toLowerCase();
    final items = switch (_category) {
      AdminCategory.teachers => _teachers
          .where((v) =>
              '${v.name} ${v.phone} ${v.email} ${v.role} ${v.classes.join(' ')}'
                  .toLowerCase()
                  .contains(q))
          .toList(),
      AdminCategory.students => _students
          .where((v) =>
              '${v.name} ${v.className} ${v.nickname} ${v.medicalNotes}'
                  .toLowerCase()
                  .contains(q))
          .toList(),
      AdminCategory.parents => _parents
          .where((v) =>
              '${v.name} ${v.phone} ${v.email} ${v.relationship} ${v.linkedChildren.join(' ')}'
                  .toLowerCase()
                  .contains(q))
          .toList(),
      AdminCategory.schedules => <Object>[],
    };
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: Text('Không tìm thấy dữ liệu phù hợp.'),
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1050
          ? 3
          : constraints.maxWidth >= 650
              ? 2
              : 1;
      const gap = 14.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: items
            .map((item) => SizedBox(width: width, child: _personCard(item)))
            .toList(),
      );
    });
  }

  Widget _personCard(Object item) {
    final (name, subtitle, lines, chips) = switch (item) {
      Teacher v => (
          v.name,
          v.role,
          ['SĐT: ${v.phone}', 'Email: ${v.email}'],
          v.classes
        ),
      Student v => (
          v.name,
          v.nickname,
          ['Lớp: ${v.className}', 'Y tế: ${v.medicalNotes}'],
          <String>[]
        ),
      ParentAccount v => (
          v.name,
          v.relationship,
          ['SĐT: ${v.phone}', 'Email: ${v.email}'],
          v.linkedChildren
        ),
      _ => ('', '', <String>[], <String>[]),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(_initials(name))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                )),
            if (chips.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips
                    .map((chip) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(chip,
                              style: const TextStyle(fontSize: 11)),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 8),
            Divider(color: Theme.of(context).dividerColor),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditor(_category, item: item),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Sửa'),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(item),
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Xóa'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleList() {
    final conflicts = _conflictsFor(_selectedDay);
    final conflictIds = {
      for (final conflict in conflicts)
        ...[conflict.first.id, conflict.second.id],
    };
    final q = _query.toLowerCase().trim();
    final items = _schedules
        .where((v) =>
            v.day == _selectedDay &&
            '${v.name} ${v.room} ${v.teacherName} ${v.description}'
                .toLowerCase()
                .contains(q))
        .toList();
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(dayLabels.length, (day) {
              final count = _conflictsFor(day).length;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: day == _selectedDay,
                  onSelected: (_) => setState(() => _selectedDay = day),
                  avatar: count == 0
                      ? null
                      : Badge(label: Text('$count'), child: const SizedBox()),
                  label: Text(dayLabels[day]),
                ),
              );
            }),
          ),
        ),
        if (conflicts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.darkMode
                  ? AppColors.warning.withAlpha(33)
                  : AppColors.warningTint,
              border: Border.all(color: AppColors.warning),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning),
                    SizedBox(width: 8),
                    Text('Cảnh báo xung đột thời khóa biểu',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                ...conflicts.map((c) => Text('• ${c.message}',
                    style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(44),
            child: Text('Chưa có tiết học phù hợp.'),
          )
        else
          ...items.map((item) {
            final conflict = conflictIds.contains(item.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    width: conflict ? 2 : 1,
                    color: conflict
                        ? AppColors.danger
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: conflict
                              ? AppColors.danger
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          '${item.start}\n${item.end}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: conflict ? Colors.white : null,
                            fontWeight: FontWeight.w700,
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
                                Flexible(
                                  child: Text(item.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ),
                                if (conflict) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.warning_amber_rounded,
                                      color: AppColors.danger, size: 18),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.room} · ${item.teacherName}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(item.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) => action == 'edit'
                            ? _showEditor(AdminCategory.schedules, item: item)
                            : _confirmDelete(item),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Sửa')),
                          PopupMenuItem(value: 'delete', child: Text('Xóa')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _account() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Tài khoản Quản trị viên',
                'Thông tin tài khoản quyền quản trị hệ thống và cấu hình ứng dụng.'),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 32, child: Text('AQ')),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Quản trị',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text('Quản trị viên hệ thống (Super Admin)',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                          const SizedBox(height: 4),
                          const Text(
                              'Trường Mầm Non Hướng Dương & Ánh Sao',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _sectionLabel('CHI TIẾT TÀI KHOẢN'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _infoRow('Tên đăng nhập', 'quantri'),
                  _infoRow('Email liên hệ', 'admin@kinderlog.edu.vn'),
                  _infoRow('Số điện thoại', '0988 888 999'),
                  _infoRow('Quyền hạn', 'Toàn quyền Super Admin'),
                  _infoRow('Trạng thái bảo mật', '2FA đang bật',
                      valueColor: AppColors.success),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionLabel('TÙY CHỈNH & BẢO MẬT'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Đổi mật khẩu tài khoản'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePassword,
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  SwitchListTile(
                    secondary: Icon(widget.darkMode
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined),
                    title: const Text('Giao diện tối'),
                    value: widget.darkMode,
                    onChanged: widget.onThemeChanged,
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Phiên bản phần mềm'),
                    trailing: Text('v2.4.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất tài khoản quản trị'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, letterSpacing: .8, fontWeight: FontWeight.w700)),
      );

  Widget _infoRow(String label, String value, {Color? valueColor}) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Expanded(child: Text(label)),
                Flexible(
                  child: Text(value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          color: valueColor, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
        ],
      );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return name.characters.first.toUpperCase();
    return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _showEditor(AdminCategory category, {Object? item}) async {
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => _EditorDialog(
        category: category,
        item: item,
        teachers: _teachers,
        schedules: _schedules,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result is Teacher) {
        final index = _teachers.indexWhere((v) => v.id == result.id);
        index < 0 ? _teachers.insert(0, result) : _teachers[index] = result;
      } else if (result is Student) {
        final index = _students.indexWhere((v) => v.id == result.id);
        index < 0 ? _students.insert(0, result) : _students[index] = result;
      } else if (result is ParentAccount) {
        final index = _parents.indexWhere((v) => v.id == result.id);
        index < 0 ? _parents.insert(0, result) : _parents[index] = result;
      } else if (result is Schedule) {
        final index = _schedules.indexWhere((v) => v.id == result.id);
        index < 0 ? _schedules.add(result) : _schedules[index] = result;
        _selectedDay = result.day;
      }
    });
    _notify(item == null ? 'Đã thêm dữ liệu thành công' : 'Đã cập nhật dữ liệu');
  }

  Future<void> _confirmDelete(Object item) async {
    final name = switch (item) {
      Teacher v => v.name,
      Student v => v.name,
      ParentAccount v => v.name,
      Schedule v => v.name,
      _ => '',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
        title: const Text('Xác nhận xóa dữ liệu'),
        content: Text('Bạn có chắc chắn muốn xóa “$name”? '
            'Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy bỏ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      if (item is Teacher) _teachers.remove(item);
      if (item is Student) _students.remove(item);
      if (item is ParentAccount) _parents.remove(item);
      if (item is Schedule) _schedules.remove(item);
    });
    _notify('Đã xóa: $name');
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: const Text('Xác nhận đăng xuất'),
        content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản Quản trị viên?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ở lại')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onLogout?.call();
    if (widget.onLogout == null) _notify('Đã đăng xuất an toàn (bản demo)');
  }

  Future<void> _changePassword() async {
    final form = GlobalKey<FormState>();
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Form(
          key: form,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Mật khẩu hiện tại'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                  validator: (value) => (value?.length ?? 0) < 8
                      ? 'Mật khẩu cần ít nhất 8 ký tự'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
                  validator: (value) =>
                      value != next.text ? 'Mật khẩu xác nhận không khớp' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Lưu mật khẩu'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (saved == true && mounted) _notify('Đổi mật khẩu thành công');
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Vui lòng nhập thông tin' : null;

class _EditorDialog extends StatefulWidget {
  const _EditorDialog({
    required this.category,
    required this.item,
    required this.teachers,
    required this.schedules,
  });

  final AdminCategory category;
  final Object? item;
  final List<Teacher> teachers;
  final List<Schedule> schedules;

  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _second;
  late final TextEditingController _third;
  late final TextEditingController _fourth;
  int _day = 0;
  String? _scheduleError;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(
      text: switch (item) {
        Teacher v => v.name,
        Student v => v.name,
        ParentAccount v => v.name,
        Schedule v => v.name,
        _ => '',
      },
    );
    _second = TextEditingController(
      text: switch (item) {
        Teacher v => v.phone,
        Student v => v.nickname,
        ParentAccount v => v.phone,
        Schedule v => v.start,
        _ => '',
      },
    );
    _third = TextEditingController(
      text: switch (item) {
        Teacher v => v.email,
        Student v => v.className,
        ParentAccount v => v.email,
        Schedule v => v.end,
        _ => '',
      },
    );
    _fourth = TextEditingController(
      text: switch (item) {
        Teacher v => v.classes.join(', '),
        Student v => v.medicalNotes,
        ParentAccount v => v.linkedChildren.join(', '),
        Schedule v => v.room,
        _ => '',
      },
    );
    if (item is Schedule) _day = item.day;
  }

  @override
  void dispose() {
    _name.dispose();
    _second.dispose();
    _third.dispose();
    _fourth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return AlertDialog(
      title: Text('${editing ? 'Chỉnh sửa' : 'Thêm'} $_entityName'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 500,
          child: SingleChildScrollView(child: _fields()),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy bỏ')),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Text('Lưu dữ liệu'),
        ),
      ],
    );
  }

  String get _entityName => switch (widget.category) {
        AdminCategory.teachers => 'giáo viên',
        AdminCategory.students => 'học sinh',
        AdminCategory.parents => 'phụ huynh',
        AdminCategory.schedules => 'tiết học',
      };

  Widget _fields() {
    if (widget.category == AdminCategory.schedules) {
      final schedule = widget.item is Schedule ? widget.item as Schedule : null;
      return Column(
        children: [
          DropdownButtonFormField<int>(
            initialValue: _day,
            decoration: const InputDecoration(labelText: 'Ngày học'),
            items: List.generate(
              dayLabels.length,
              (i) => DropdownMenuItem(value: i, child: Text(dayLabels[i])),
            ),
            onChanged: (value) => setState(() => _day = value ?? 0),
          ),
          const SizedBox(height: 12),
          _field(_name, 'Tên tiết học'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field(_second, 'Bắt đầu (HH:mm)')),
              const SizedBox(width: 10),
              Expanded(child: _field(_third, 'Kết thúc (HH:mm)')),
            ],
          ),
          const SizedBox(height: 12),
          _field(_fourth, 'Phòng học'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: schedule?.teacherName,
            decoration: const InputDecoration(labelText: 'Giáo viên'),
            items: widget.teachers
                .map((v) =>
                    DropdownMenuItem(value: v.name, child: Text(v.name)))
                .toList(),
            onChanged: (value) => setState(() {
              final old = schedule;
              _selectedTeacher = value ?? old?.teacherName ?? '';
            }),
          ),
          if (_scheduleError != null) ...[
            const SizedBox(height: 12),
            Text(_scheduleError!,
                style: const TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
          ],
        ],
      );
    }
    final labels = switch (widget.category) {
      AdminCategory.teachers =>
        ('Họ và tên', 'Số điện thoại', 'Email', 'Lớp phụ trách (cách nhau bởi dấu phẩy)'),
      AdminCategory.students =>
        ('Họ và tên', 'Tên gọi', 'Lớp học', 'Ghi chú y tế & dị ứng'),
      AdminCategory.parents =>
        ('Họ và tên', 'Số điện thoại', 'Email', 'Học sinh liên kết'),
      AdminCategory.schedules => ('', '', '', ''),
    };
    return Column(
      children: [
        _field(_name, labels.$1),
        const SizedBox(height: 12),
        _field(_second, labels.$2),
        const SizedBox(height: 12),
        _field(_third, labels.$3),
        const SizedBox(height: 12),
        _field(_fourth, labels.$4, maxLines: 2),
      ],
    );
  }

  String _selectedTeacher = '';

  Widget _field(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: _required,
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final old = widget.item;
    Object result;
    switch (widget.category) {
      case AdminCategory.teachers:
        final previous = old is Teacher ? old : null;
        result = Teacher(
          id: previous?.id ?? 't-$stamp',
          name: _name.text.trim(),
          phone: _second.text.trim(),
          email: _third.text.trim(),
          classes: _split(_fourth.text),
          role: previous?.role ?? 'Giáo viên chủ nhiệm',
        );
        break;
      case AdminCategory.students:
        final previous = old is Student ? old : null;
        result = Student(
          id: previous?.id ?? 'c-$stamp',
          name: _name.text.trim(),
          nickname: _second.text.trim(),
          className: _third.text.trim(),
          medicalNotes: _fourth.text.trim(),
        );
        break;
      case AdminCategory.parents:
        final previous = old is ParentAccount ? old : null;
        result = ParentAccount(
          id: previous?.id ?? 'p-$stamp',
          name: _name.text.trim(),
          phone: _second.text.trim(),
          email: _third.text.trim(),
          linkedChildren: _split(_fourth.text),
          relationship: previous?.relationship ?? 'Phụ huynh',
        );
        break;
      case AdminCategory.schedules:
        final previous = old is Schedule ? old : null;
        final teacher = _selectedTeacher.isNotEmpty
            ? _selectedTeacher
            : previous?.teacherName ?? widget.teachers.first.name;
        final draft = Schedule(
          id: previous?.id ?? 'sch-$stamp',
          day: _day,
          name: _name.text.trim(),
          start: _second.text.trim(),
          end: _third.text.trim(),
          room: _fourth.text.trim(),
          teacherName: teacher,
          description: previous?.description ?? 'Tiết học mới',
        );
        Schedule? conflict;
        for (final other in widget.schedules) {
          if (other.id == draft.id || other.day != draft.day) continue;
          final overlaps = draft.start.compareTo(other.end) < 0 &&
              draft.end.compareTo(other.start) > 0;
          final clashes = overlaps &&
              (draft.room.toLowerCase() == other.room.toLowerCase() ||
                  draft.teacherName.toLowerCase() ==
                      other.teacherName.toLowerCase());
          if (clashes) {
            conflict = other;
            break;
          }
        }
        if (draft.start.compareTo(draft.end) >= 0) {
          setState(() => _scheduleError =
              'Giờ kết thúc phải muộn hơn giờ bắt đầu.');
          return;
        }
        final conflictItem = conflict;
        if (conflictItem != null) {
          setState(() => _scheduleError =
              'Xung đột với “${conflictItem.name}” (${conflictItem.start}–${conflictItem.end}).');
          return;
        }
        result = draft;
        break;
    }
    Navigator.pop(context, result);
  }

  List<String> _split(String value) => value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.dark);

  final bool dark;
  static const List<double> sent = [238.0, 252.0, 244.0, 268.0, 276.0, 271.0, 285.0];
  static const List<double> draft = [71.0, 64.0, 69.0, 58.0, 52.0, 61.0, 57.0];

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = dark ? Colors.white12 : const Color(0xFFE3E9E6)
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    _line(canvas, size, sent, AppColors.brand, 220, 300);
    _line(canvas, size, draft, AppColors.warning, 40, 80);
  }

  void _line(Canvas canvas, Size size, List<double> data, Color color,
      double min, double max) {
    final path = Path();
    final dot = Paint()..color = color;
    for (var i = 0; i < data.length; i++) {
      final x = i * size.width / (data.length - 1);
      final y = size.height - ((data[i] - min) / (max - min)) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 4, dot);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
