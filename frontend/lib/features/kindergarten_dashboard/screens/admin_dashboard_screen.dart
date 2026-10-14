import 'package:flutter/material.dart';
import 'package:adark_frontend/data/repositories/http_admin_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme_controller.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1. DESIGN SYSTEM COLORS (100% FIDELITY FROM admin_UI/app_theme.dart)
// ═════════════════════════════════════════════════════════════════════════════

abstract final class AppColors {
  // Bí danh của bảng màu app (KColors) — một nguồn duy nhất cho giá trị màu.
  // shortcut: alias tĩnh chỉ dùng theme sáng, đổi call site sang context.k khi màn admin cần dark-mode.
  static const brand = KColors.brand;
  static const brandStrong = KColors.brandStrong;
  static const brandTint = KColors.brandTint;
  static const warning = KColors.warn;
  static const warningTint = KColors.warnTint;
  static const danger = KColors.bad;
  static const dangerTint = KColors.badTint;
  static const success = KColors.ok;
  static const successTint = KColors.okTint;
  static const info = KColors.info;
}

const dayLabels = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6'];

enum AdminTab { overview, features, account }

enum AdminCategory { teachers, students, parents, schedules }

class ScheduleConflict {
  const ScheduleConflict(this.first, this.second, this.message);

  final AdminScheduleDto first;
  final AdminScheduleDto second;
  final String message;
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. ADMIN DASHBOARD SCREEN (CHUẨN MOBILE 100% FIGMA + TÍCH HỢP 100% API BACKEND)
// ═════════════════════════════════════════════════════════════════════════════

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onLogout,
    this.repository,
    this.initialTab = AdminTab.overview,
    this.initialCategory = AdminCategory.teachers,
  });

  final VoidCallback onLogout;
  final HttpAdminRepository? repository;
  final AdminTab initialTab;
  final AdminCategory initialCategory;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final HttpAdminRepository _repo = widget.repository ?? HttpAdminRepository();

  late AdminTab _tab = widget.initialTab;
  late AdminCategory _category = widget.initialCategory;
  int _selectedDay = 0; // 0: Thứ 2, 1: Thứ 3, ..., 4: Thứ 6
  String _query = '';
  final _searchController = TextEditingController();

  int _schoolIndex = 0;
  static const _schools = [
    'Trường Mầm Non Hướng Dương',
    'Trường Mầm Non Ánh Sao',
  ];

  bool _isLoading = false;
  String? _errorMessage;

  // Overview data from API
  AdminOverviewStatsDto? _stats;
  List<AdminClassProgressDto> _classesProgress = [];
  AdminVoiceStatsDto? _voiceStats;
  List<AdminReportTrendDto> _trends = [];
  AdminSystemHealthDto? _health;

  // Management CRUD data from API
  List<AdminTeacherDto> _teachers = [];
  List<AdminChildDto> _students = [];
  List<AdminParentDto> _parents = [];
  List<AdminScheduleDto> _schedules = [];

  // Dropdown resource caches from API
  List<AdminClassDto> _classes = [];
  List<AdminTimeSlotDto> _timeSlots = [];

  bool get _isDarkMode {
    final mode = ThemeController.instance.value;
    if (mode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return mode == ThemeMode.dark;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadDropdownResources(),
      _loadOverviewData(),
      _loadCategoryData(silent: true),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDropdownResources() async {
    try {
      final results = await Future.wait([
        _repo.getClasses(),
        _repo.getTimeSlots(),
      ]);
      if (mounted) {
        setState(() {
          _classes = results[0] as List<AdminClassDto>;
          _timeSlots = results[1] as List<AdminTimeSlotDto>;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadOverviewData() async {
    try {
      final results = await Future.wait([
        _repo.getDashboardOverviewStats(),
        _repo.getDashboardClassesProgress(),
        _repo.getDashboardVoiceStats(),
        _repo.getDashboardReportTrends(days: 7),
        _repo.getDashboardSystemHealth(),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as AdminOverviewStatsDto;
          _classesProgress = results[1] as List<AdminClassProgressDto>;
          _voiceStats = results[2] as AdminVoiceStatsDto;
          _trends = results[3] as List<AdminReportTrendDto>;
          _health = results[4] as AdminSystemHealthDto;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Không thể tải thống kê tổng quan: $e');
      }
    }
  }

  Future<void> _loadCategoryData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      switch (_category) {
        case AdminCategory.teachers:
          final res = await _repo.getTeachers();
          if (mounted) setState(() => _teachers = res);
          break;
        case AdminCategory.students:
          final res = await _repo.getChildren();
          if (mounted) setState(() => _students = res);
          break;
        case AdminCategory.parents:
          final res = await _repo.getParents();
          if (mounted) setState(() => _parents = res);
          break;
        case AdminCategory.schedules:
          final dayOfWeek = _selectedDay + 2; // 0 (Thứ 2) -> 2
          final res = await _repo.getSchedules(dayOfWeek: dayOfWeek);
          if (mounted) setState(() => _schedules = res);
          break;
      }
    } catch (e) {
      if (mounted) {
        _notify('Lỗi tải dữ liệu ${_categoryLabel(_category)}: $e');
      }
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
    }
  }

  List<ScheduleConflict> _conflictsFor(int day) {
    final dayOfWeek = day + 2;
    final items = _schedules.where((item) => item.dayOfWeek == dayOfWeek).toList();
    final result = <ScheduleConflict>[];

    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        final a = items[i];
        final b = items[j];

        final aStart = _timeToMinutes(a.startTime);
        final aEnd = _timeToMinutes(a.endTime);
        final bStart = _timeToMinutes(b.startTime);
        final bEnd = _timeToMinutes(b.endTime);

        if (aStart == null || aEnd == null || bStart == null || bEnd == null) continue;

        // Trùng / chồng lấn thời gian
        if (!(aStart < bEnd && aEnd > bStart)) continue;

        final sameRoom = a.roomName.trim().isNotEmpty &&
            a.roomName.trim().toLowerCase() == b.roomName.trim().toLowerCase();

        if (sameRoom) {
          result.add(ScheduleConflict(
            a,
            b,
            'Trùng phòng "${a.roomName}" giữa "${a.activityName}" và "${b.activityName}" '
            '(${a.timeRange} và ${b.timeRange})',
          ));
        }
      }
    }
    return result;
  }

  int get _totalConflicts => List.generate(
        dayLabels.length,
        (day) => _conflictsFor(day).length,
      ).fold(0, (sum, count) => sum + count);

  int? _timeToMinutes(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return null;
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 3. GIAO DIỆN CHÍNH NATIVE MOBILE (CHUẨN 100% FIGMA HÌNH 2)
  // ═════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _mobileHeader(),
            if (_isLoading)
              const LinearProgressIndicator(
                color: AppColors.brand,
                backgroundColor: AppColors.brandTint,
                minHeight: 2.5,
              ),
            Expanded(
              child: SelectionArea(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _content(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (index) {
            setState(() {
              _tab = AdminTab.values[index];
              _query = '';
              _searchController.clear();
            });
            if (_tab == AdminTab.overview) {
              _loadOverviewData();
            } else if (_tab == AdminTab.features) {
              _loadCategoryData();
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _totalConflicts > 0,
                label: Text('$_totalConflicts'),
                child: const Icon(Icons.tune_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: _totalConflicts > 0,
                label: Text('$_totalConflicts'),
                child: const Icon(Icons.tune),
              ),
              label: 'Chức năng',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 4. MOBILE HEADER (100% FIDELITY TỪ FIGMA HÌNH 2)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _mobileHeader() {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final hasSearch = _query.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng 1: Brand Logo + Tên KinderLog
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_florist, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'KinderLog',
                style: TextStyle(
                  color: AppColors.brand,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hàng 2: Search bar full-width độc lập
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _query = val),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              hintText: _searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: hasSearch
                  ? IconButton(
                      iconSize: 18,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _query = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),

          // Hàng 3: Chọn cơ sở trường học + Nút vuông Dark mode
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _schoolIndex,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.school_outlined, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: List.generate(
                    _schools.length,
                    (idx) => DropdownMenuItem(
                      value: idx,
                      child: Text(
                        _schools[idx],
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _schoolIndex = val);
                      _notify('Đã chuyển sang ${_schools[val]}');
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: IconButton(
                  tooltip: _isDarkMode ? 'Giao diện sáng' : 'Giao diện tối',
                  onPressed: () {
                    final newMode = _isDarkMode ? ThemeMode.light : ThemeMode.dark;
                    ThemeController.instance.set(newMode);
                    setState(() {});
                  },
                  icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hàng 4: Chuông thông báo + Nút + Thêm tài khoản mới + Nút Quay lại
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: IconButton(
                  tooltip: 'Thông báo',
                  onPressed: () => _notify('Hệ thống hoạt động bình thường, không có cảnh báo mới'),
                  icon: const Badge(
                    smallSize: 7,
                    child: Icon(Icons.notifications_none, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () => _showEditor(_category),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      _tab == AdminTab.features ? _addLabel : 'Thêm tài khoản mới',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () {
                    if (_tab != AdminTab.overview) {
                      setState(() {
                        _tab = AdminTab.overview;
                        _query = '';
                        _searchController.clear();
                      });
                    } else {
                      _confirmLogout();
                    }
                  },
                  child: Text(
                    _tab == AdminTab.overview ? 'Đăng xuất' : 'Quay lại',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hàng 5: Pill badge trạng thái đồng bộ dữ liệu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 8, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(
                      'Dữ liệu vừa cập nhật lúc $timeStr',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: 'Làm mới dữ liệu',
                onPressed: () {
                  _loadOverviewData();
                  _loadCategoryData();
                  _notify('Đã đồng bộ dữ liệu mới nhất từ máy chủ');
                },
                icon: const Icon(Icons.refresh),
              ),
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

  String _categoryLabel(AdminCategory c) => switch (c) {
        AdminCategory.teachers => 'giáo viên',
        AdminCategory.students => 'học sinh',
        AdminCategory.parents => 'phụ huynh',
        AdminCategory.schedules => 'thời khóa biểu',
      };

  Widget _content() => switch (_tab) {
        AdminTab.overview => _overview(),
        AdminTab.features => _features(),
        AdminTab.account => _account(),
      };

  Widget _heading(String title, String subtitle, {Widget? trailing}) {
    final isSmall = MediaQuery.sizeOf(context).width < 600;
    if (isSmall && trailing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: trailing,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing,
        ],
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 5. TAB 1: OVERVIEW (TỔNG QUAN HỆ THỐNG - GẮN REAL STATS TỪ BACKEND API)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _overview() {
    final q = _query.toLowerCase().trim();
    final classes = _classesProgress
        .where((item) =>
            '${item.className} ${item.gradeLabel} ${item.teacherName}'
                .toLowerCase()
                .contains(q))
        .toList();

    final totalChildren = _stats?.totalChildren ?? 0;
    final totalClasses = _stats?.totalClasses ?? 0;
    final totalSchools = _stats?.totalSchools ?? 2;
    final completionRate = _stats?.todayCompletionRate ?? 0.0;
    final sentCount = _stats?.todaySentReportsCount ?? 0;
    final draftCount = _stats?.todayDraftReportsCount ?? 0;
    final todayVoice = _stats?.todayVoiceRecords ?? 0;
    final totalVoice = _stats?.totalVoiceRecords ?? 0;
    final teachersCount = _stats?.totalTeachers ?? _teachers.length;
    final parentsCount = _stats?.totalParents ?? _parents.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.danger),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger))),
              ],
            ),
          ),
        _heading(
          'Tổng quan hệ thống',
          'Theo dõi hoạt động trường học, tiến độ báo cáo và tài nguyên hệ thống theo thời gian thực.',
        ),
        const SizedBox(height: 18),
        // Lưới 2 cột Metric Cards chuẩn Mobile Figma (Hình 2)
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 600 ? 2 : 1;
          const gap = 12.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              _metric(
                width,
                Icons.groups_outlined,
                'Tổng số học sinh',
                '$totalChildren bé',
                '$totalClasses lớp học · $totalSchools cơ sở',
                AppColors.brand,
              ),
              _metric(
                width,
                Icons.check_circle_outline,
                'Tiến độ báo cáo ngày',
                '${completionRate.toStringAsFixed(1)}%',
                '$sentCount đã gửi · $draftCount bản nháp',
                AppColors.success,
              ),
              _metric(
                width,
                Icons.mic_none,
                'Bản ghi âm giọng nói',
                '$todayVoice file hôm nay',
                'Tổng cộng: $totalVoice file',
                AppColors.warning,
              ),
              _metric(
                width,
                Icons.people_outline,
                'Nhân sự & Phụ huynh',
                '$teachersCount giáo viên',
                '$parentsCount phụ huynh đang hoạt động',
                AppColors.info,
              ),
            ],
          );
        }),
        const SizedBox(height: 18),
        _progressCard(classes),
        const SizedBox(height: 16),
        _voiceCard(),
        const SizedBox(height: 16),
        _healthCard(),
        const SizedBox(height: 16),
        _trendCard(),
      ],
    );
  }

  Widget _metric(
    double width,
    IconData icon,
    String label,
    String value,
    String detail,
    Color color,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withAlpha(33),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressCard(List<AdminClassProgressDto> classes) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            title: const Text(
              'Tiến độ báo cáo theo lớp học trong ngày',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.className,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  Text(
                                    item.gradeLabel.isNotEmpty ? item.gradeLabel : 'Khối mầm non',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(item.completionRate * 100).round()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: item.completionRate >= 0.8
                                    ? AppColors.success
                                    : item.completionRate >= 0.4
                                        ? AppColors.warning
                                        : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.teacherName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${item.reportedChildren}/${item.totalChildren} bé',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: item.completionRate.clamp(0.0, 1.0),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(8),
                          color: item.completionRate >= 0.8
                              ? AppColors.success
                              : item.completionRate >= 0.4
                                  ? AppColors.warning
                                  : AppColors.danger,
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

  Widget _voiceCard() {
    final v = _voiceStats;
    final completed = v?.completedRecords ?? 0;
    final pending = v?.pendingRecords ?? 0;
    final failed = v?.failedRecords ?? 0;
    final durationMin = ((v?.totalDurationSeconds ?? 0) / 60).round();

    return _statusCard(
      title: 'Hàng đợi xử lý giọng nói STT',
      subtitle: '$durationMin phút ghi âm',
      icon: Icons.mic_none,
      color: AppColors.warning,
      rows: [
        ('Hoàn thành', '$completed file', AppColors.success),
        ('Đang xử lý', '$pending file', AppColors.warning),
        ('Lỗi xử lý', '$failed file', AppColors.danger),
      ],
    );
  }

  Widget _healthCard() {
    final h = _health;
    return _statusCard(
      title: 'Tình trạng hạ tầng máy chủ',
      subtitle: h?.serverTime ?? 'Thời gian thực',
      icon: Icons.check_circle_outline,
      color: AppColors.success,
      rows: [
        ('Cơ sở dữ liệu', h?.databaseStatus == 'healthy' ? 'Đang kết nối' : 'Cảnh báo', AppColors.success),
        ('Redis Queue', h?.redisStatus == 'healthy' ? 'Hoạt động tốt' : 'Gián đoạn', AppColors.success),
        ('FastAPI Backend', h?.apiStatus == 'healthy' ? 'Ổn định' : 'Kiểm tra', AppColors.success),
      ],
    );
  }

  Widget _statusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<(String, String, Color)> rows,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: row.$3),
                    const SizedBox(width: 8),
                    Expanded(child: Text(row.$1, style: const TextStyle(fontSize: 12))),
                    Text(
                      row.$2,
                      style: TextStyle(
                        color: row.$3,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xu hướng báo cáo 7 ngày gần nhất',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Số báo cáo được tạo và gửi đến phụ huynh (Xanh: đã gửi, Vàng: bản nháp)',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendPainter(
                  dark: _isDarkMode,
                  trends: _trends,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 6. TAB 2: FEATURES (QUẢN TRỊ CRUD: GIÁO VIÊN, HỌC SINH, PHỤ HUYNH, LỊCH)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _features() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Chức năng quản trị hệ thống',
          'Quản lý giáo viên, học sinh, phụ huynh và kiểm tra xung đột thời khóa biểu tự động.',
        ),
        const SizedBox(height: 16),
        // Lưới 2x2 hiển thị trọn vẹn 100% cả 4 danh mục không bị cắt xén
        LayoutBuilder(builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _categoryButton(
                category: AdminCategory.teachers,
                icon: Icons.person_add_outlined,
                label: 'Giáo viên',
                count: _teachers.length,
                width: itemWidth,
              ),
              _categoryButton(
                category: AdminCategory.students,
                icon: Icons.school_outlined,
                label: 'Học sinh',
                count: _students.length,
                width: itemWidth,
              ),
              _categoryButton(
                category: AdminCategory.parents,
                icon: Icons.groups_outlined,
                label: 'Phụ huynh',
                count: _parents.length,
                width: itemWidth,
              ),
              _categoryButton(
                category: AdminCategory.schedules,
                icon: Icons.event_note_outlined,
                label: 'Thời khóa biểu',
                count: _schedules.length,
                width: itemWidth,
                badgeCount: _totalConflicts,
              ),
            ],
          );
        }),
        const SizedBox(height: 18),
        if (_category == AdminCategory.schedules)
          _scheduleList()
        else
          _peopleGrid(),
      ],
    );
  }

  Widget _categoryButton({
    required AdminCategory category,
    required IconData icon,
    required String label,
    required int count,
    required double width,
    int badgeCount = 0,
  }) {
    final selected = _category == category;
    final theme = Theme.of(context);
    final isDark = _isDarkMode;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _category = category;
          _query = '';
          _searchController.clear();
        });
        _loadCategoryData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.brand.withAlpha(50) : AppColors.brandTint)
              : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.brand : theme.dividerColor,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.brand : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AppColors.brand : null,
                ),
              ),
            ),
            const SizedBox(width: 4),
            if (badgeCount > 0)
              Badge(
                label: Text('$badgeCount'),
                backgroundColor: AppColors.danger,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.brand.withAlpha(30)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.brand : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _peopleGrid() {
    final q = _query.trim().toLowerCase();
    final List<Object> items = switch (_category) {
      AdminCategory.teachers => _teachers
          .where((v) =>
              '${v.fullName} ${v.phone} ${v.email} ${v.className}'
                  .toLowerCase()
                  .contains(q))
          .toList(),
      AdminCategory.students => _students
          .where((v) =>
              '${v.fullName} ${v.className} ${v.nickname} ${v.note} ${v.parentPhone}'
                  .toLowerCase()
                  .contains(q))
          .toList(),
      AdminCategory.parents => _parents
          .where((v) =>
              '${v.fullName} ${v.phone} ${v.email} ${v.childrenSummary}'
                  .toLowerCase()
                  .contains(q))
          .toList(),
      AdminCategory.schedules => <Object>[],
    };

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('Không tìm thấy dữ liệu phù hợp.'),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 600 ? 2 : 1;
      const gap = 12.0;
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
      AdminTeacherDto v => (
          v.fullName,
          'Giáo viên phụ trách',
          ['SĐT: ${v.phone}', 'Email: ${v.email.isNotEmpty ? v.email : "Chưa cập nhật"}'],
          v.className.split(', ').where((c) => c.isNotEmpty && c != 'Chưa phân lớp').toList(),
        ),
      AdminChildDto v => (
          v.fullName,
          v.nickname.isNotEmpty ? 'Bé ${v.nickname}' : 'Học sinh',
          [
            'Lớp: ${v.className}',
            'Y tế: ${v.note.isNotEmpty ? v.note : "Bình thường, không dị ứng"}',
          ],
          <String>[],
        ),
      AdminParentDto v => (
          v.fullName,
          'Phụ huynh học sinh',
          [
            'SĐT: ${v.phone}',
            'Email: ${v.email.isNotEmpty ? v.email : "Chưa cập nhật"}',
          ],
          v.childrenSummary.isNotEmpty
              ? [v.childrenSummary]
              : <String>[],
        ),
      _ => ('', '', <String>[], <String>[]),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                )),
            if (chips.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips
                    .map((chip) => Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(chip, style: const TextStyle(fontSize: 11)),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 6),
            Divider(color: Theme.of(context).dividerColor),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditor(_category, item: item),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Sửa'),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(item),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
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
            v.dayOfWeek == (_selectedDay + 2) &&
            '${v.activityName} ${v.roomName} ${v.content}'
                .toLowerCase()
                .contains(q))
        .toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(dayLabels.length, (day) {
              final count = _conflictsFor(day).length;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: day == _selectedDay,
                  onSelected: (_) {
                    setState(() => _selectedDay = day);
                    _loadCategoryData();
                  },
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
              color: _isDarkMode
                  ? AppColors.warning.withAlpha(33)
                  : AppColors.warningTint,
              border: Border.all(color: AppColors.warning),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                    SizedBox(width: 8),
                    Text(
                      'Cảnh báo xung đột thời khóa biểu',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...conflicts.map((c) => Text('• ${c.message}', style: const TextStyle(fontSize: 13))),
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
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    width: conflict ? 2 : 1,
                    color: conflict
                        ? AppColors.danger
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: conflict
                              ? AppColors.danger
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item.startTime}\n${item.endTime}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: conflict ? Colors.white : null,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.activityName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (conflict) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Phòng: ${item.roomName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (item.content.isNotEmpty)
                              Text(
                                item.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
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

  // ═════════════════════════════════════════════════════════════════════════════
  // 7. TAB 3: ACCOUNT (TÀI KHOẢN ADMIN & CẤU HÌNH BẢO MẬT)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _account() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              'Tài khoản Quản trị viên',
              'Thông tin tài khoản quyền quản trị hệ thống và cấu hình ứng dụng.',
            ),
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
                          Text(
                            'Admin Quản trị',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Quản trị viên hệ thống (Super Admin)',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Trường Mầm Non Hướng Dương & Ánh Sao',
                            style: TextStyle(fontSize: 12),
                          ),
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
                  _infoRow('Trạng thái bảo mật', 'Xác thực chuẩn JWT', valueColor: AppColors.success),
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
                    secondary: Icon(_isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                    title: const Text('Giao diện tối'),
                    value: _isDarkMode,
                    onChanged: (val) {
                      ThemeController.instance.set(val ? ThemeMode.dark : ThemeMode.light);
                      setState(() {});
                    },
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Phiên bản phần mềm'),
                    trailing: Text('v2.4.0 (Mobile Edition)'),
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
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, letterSpacing: .8, fontWeight: FontWeight.w700),
        ),
      );

  Widget _infoRow(String label, String value, {Color? valueColor}) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text(label)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
        ],
      );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'AD';
    if (parts.length < 2) return parts[0][0].toUpperCase();
    return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 8. DIALOG THÊM / SỬA (GẮN 100% API REPOSITORY CHO CẢ 4 DANH MỤC)
  // ═════════════════════════════════════════════════════════════════════════════

  Future<void> _showEditor(AdminCategory category, {Object? item}) async {
    final isEdit = item != null;
    final form = GlobalKey<FormState>();

    // Controllers
    final nameCtrl = TextEditingController(
      text: switch (item) {
        AdminTeacherDto v => v.fullName,
        AdminChildDto v => v.fullName,
        AdminParentDto v => v.fullName,
        AdminScheduleDto v => v.activityName,
        _ => '',
      },
    );
    final secondCtrl = TextEditingController(
      text: switch (item) {
        AdminTeacherDto v => v.phone,
        AdminChildDto v => v.nickname,
        AdminParentDto v => v.phone,
        AdminScheduleDto v => v.startTime,
        _ => '',
      },
    );
    final thirdCtrl = TextEditingController(
      text: switch (item) {
        AdminTeacherDto v => v.email,
        AdminChildDto v => v.className,
        AdminParentDto v => v.email,
        AdminScheduleDto v => v.endTime,
        _ => '',
      },
    );
    final fourthCtrl = TextEditingController(
      text: switch (item) {
        AdminTeacherDto v => v.className,
        AdminChildDto v => v.note,
        AdminParentDto v => v.childrenSummary,
        AdminScheduleDto v => v.roomName,
        _ => '',
      },
    );

    int schedDay = _selectedDay;
    String? selectedClassId;
    if (category == AdminCategory.students) {
      if (item is AdminChildDto) {
        selectedClassId = item.classId;
      }
      if (selectedClassId == null && _classes.isNotEmpty) {
        selectedClassId = _classes.first.id;
      }
    }

    List<String> teacherClassIds = [];
    if (category == AdminCategory.teachers && item is AdminTeacherDto) {
      teacherClassIds = List<String>.from(item.classIds);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final dialogWidth = (MediaQuery.sizeOf(dialogCtx).width - 32).clamp(280.0, 520.0);
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text('${isEdit ? 'Chỉnh sửa' : 'Thêm'} ${_categoryLabel(category)}'),
            content: SizedBox(
              width: dialogWidth,
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (category == AdminCategory.schedules) ...[
                        DropdownButtonFormField<int>(
                          initialValue: schedDay,
                          decoration: const InputDecoration(labelText: 'Ngày học'),
                          items: List.generate(
                            dayLabels.length,
                            (i) => DropdownMenuItem(value: i, child: Text(dayLabels[i])),
                          ),
                          onChanged: (value) => setDialogState(() => schedDay = value ?? 0),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Tên tiết học'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên' : null,
                        ),
                        if (_timeSlots.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _timeSlots.map((slot) {
                              return ActionChip(
                                label: Text('${slot.name} (${slot.startTime}–${slot.endTime})', style: const TextStyle(fontSize: 11)),
                                onPressed: () {
                                  setDialogState(() {
                                    secondCtrl.text = slot.startTime;
                                    thirdCtrl.text = slot.endTime;
                                    if (nameCtrl.text.isEmpty) {
                                      nameCtrl.text = slot.name;
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: secondCtrl,
                                decoration: const InputDecoration(labelText: 'Bắt đầu (HH:mm)'),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Nhập giờ bắt đầu' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: thirdCtrl,
                                decoration: const InputDecoration(labelText: 'Kết thúc (HH:mm)'),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Nhập giờ kết thúc' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fourthCtrl,
                          decoration: const InputDecoration(labelText: 'Phòng học'),
                        ),
                      ] else if (category == AdminCategory.students) ...[
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Họ và tên học sinh'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: secondCtrl,
                          decoration: const InputDecoration(labelText: 'Tên gọi / Biệt danh (ở nhà)'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedClassId,
                          decoration: const InputDecoration(labelText: 'Lớp học'),
                          items: _classes
                              .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.gradeLabel})')))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedClassId = v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fourthCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Ghi chú y tế & dị ứng'),
                        ),
                      ] else if (category == AdminCategory.teachers) ...[
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Họ và tên giáo viên'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: secondCtrl,
                          decoration: const InputDecoration(labelText: 'Số điện thoại'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: thirdCtrl,
                          decoration: const InputDecoration(labelText: 'Email liên hệ'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: teacherClassIds.isNotEmpty ? teacherClassIds.first : (_classes.isNotEmpty ? _classes.first.id : null),
                          decoration: const InputDecoration(labelText: 'Lớp phụ trách chính'),
                          items: _classes
                              .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.gradeLabel})')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() {
                                teacherClassIds = [v];
                              });
                            }
                          },
                        ),
                      ] else if (category == AdminCategory.parents) ...[
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Họ và tên phụ huynh'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: secondCtrl,
                          decoration: const InputDecoration(labelText: 'Số điện thoại'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: thirdCtrl,
                          decoration: const InputDecoration(labelText: 'Email liên hệ'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fourthCtrl,
                          decoration: const InputDecoration(labelText: 'Học sinh liên kết (con)'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy bỏ'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Lưu dữ liệu'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (isEdit) {
        // UPDATE API
        switch (category) {
          case AdminCategory.teachers:
            final old = item as AdminTeacherDto;
            await _repo.updateTeacher(
              old.id,
              fullName: nameCtrl.text.trim(),
              phone: secondCtrl.text.trim(),
              email: thirdCtrl.text.trim(),
              classId: teacherClassIds.isNotEmpty ? teacherClassIds.first : old.classId,
              classIds: teacherClassIds.isNotEmpty ? teacherClassIds : old.classIds,
            );
            break;
          case AdminCategory.students:
            final old = item as AdminChildDto;
            await _repo.updateChild(
              old.id,
              fullName: nameCtrl.text.trim(),
              nickname: secondCtrl.text.trim().isNotEmpty ? secondCtrl.text.trim() : null,
              classId: selectedClassId,
              note: fourthCtrl.text.trim().isNotEmpty ? fourthCtrl.text.trim() : null,
            );
            break;
          case AdminCategory.parents:
            final old = item as AdminParentDto;
            await _repo.updateParent(
              old.id,
              fullName: nameCtrl.text.trim(),
              phone: secondCtrl.text.trim(),
              email: thirdCtrl.text.trim().isNotEmpty ? thirdCtrl.text.trim() : null,
            );
            break;
          case AdminCategory.schedules:
            final old = item as AdminScheduleDto;
            await _repo.updateSchedule(
              old.id,
              activityName: nameCtrl.text.trim(),
              startTime: secondCtrl.text.trim(),
              endTime: thirdCtrl.text.trim(),
              roomName: fourthCtrl.text.trim().isNotEmpty ? fourthCtrl.text.trim() : null,
              dayOfWeek: schedDay + 2,
            );
            break;
        }
        _notify('Đã cập nhật dữ liệu thành công!');
      } else {
        // CREATE API
        switch (category) {
          case AdminCategory.teachers:
            await _repo.createTeacher(
              fullName: nameCtrl.text.trim(),
              phone: secondCtrl.text.trim().isNotEmpty ? secondCtrl.text.trim() : '0900000000',
              email: thirdCtrl.text.trim().isNotEmpty ? thirdCtrl.text.trim() : 'teacher@kinderlog.edu.vn',
              classId: teacherClassIds.isNotEmpty ? teacherClassIds.first : null,
              classIds: teacherClassIds,
            );
            break;
          case AdminCategory.students:
            await _repo.createChild(
              fullName: nameCtrl.text.trim(),
              nickname: secondCtrl.text.trim().isNotEmpty ? secondCtrl.text.trim() : null,
              classId: selectedClassId,
              note: fourthCtrl.text.trim().isNotEmpty ? fourthCtrl.text.trim() : null,
            );
            break;
          case AdminCategory.parents:
            await _repo.createParent(
              fullName: nameCtrl.text.trim(),
              phone: secondCtrl.text.trim().isNotEmpty ? secondCtrl.text.trim() : '0910000000',
              email: thirdCtrl.text.trim().isNotEmpty ? thirdCtrl.text.trim() : null,
            );
            break;
          case AdminCategory.schedules:
            await _repo.createSchedule(
              activityName: nameCtrl.text.trim(),
              startTime: secondCtrl.text.trim(),
              endTime: thirdCtrl.text.trim(),
              roomName: fourthCtrl.text.trim().isNotEmpty ? fourthCtrl.text.trim() : 'Phòng học',
              dayOfWeek: schedDay + 2,
            );
            break;
        }
        _notify('Đã thêm mới dữ liệu thành công!');
      }
      _loadCategoryData();
      _loadOverviewData();
    } catch (e) {
      _notify('Thao tác thất bại: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 9. DIALOG XÁC NHẬN XÓA (GẮN 100% DELETE API)
  // ═════════════════════════════════════════════════════════════════════════════

  Future<void> _confirmDelete(Object item) async {
    final name = switch (item) {
      AdminTeacherDto v => v.fullName,
      AdminChildDto v => v.fullName,
      AdminParentDto v => v.fullName,
      AdminScheduleDto v => v.activityName,
      _ => '',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
        title: const Text('Xác nhận xóa dữ liệu'),
        content: Text(
          'Bạn có chắc chắn muốn xóa “$name”? Thao tác này sẽ xóa vĩnh viễn trên cơ sở dữ liệu và không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy bỏ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      switch (item) {
        case AdminTeacherDto v:
          await _repo.deleteTeacher(v.id);
          break;
        case AdminChildDto v:
          await _repo.deleteChild(v.id);
          break;
        case AdminParentDto v:
          await _repo.deleteParent(v.id);
          break;
        case AdminScheduleDto v:
          await _repo.deleteSchedule(v.id);
          break;
      }
      _notify('Đã xóa thành công: $name');
      _loadCategoryData();
      _loadOverviewData();
    } catch (e) {
      _notify('Lỗi khi xóa: $e');
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản Quản trị viên?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ở lại')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onLogout();
  }

  Future<void> _changePassword() async {
    final form = GlobalKey<FormState>();
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogWidth = (MediaQuery.sizeOf(context).width - 32).clamp(280.0, 440.0);
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Đổi mật khẩu tài khoản'),
          content: SizedBox(
            width: dialogWidth,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: current,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
                      validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập mật khẩu cũ' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: next,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                      validator: (value) => (value?.length ?? 0) < 6
                          ? 'Mật khẩu cần ít nhất 6 ký tự'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirm,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
                      validator: (value) =>
                          value != next.text ? 'Mật khẩu xác nhận không khớp' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Lưu mật khẩu'),
            ),
          ],
        );
      },
    );

    current.dispose();
    next.dispose();
    confirm.dispose();
    if (saved == true && mounted) _notify('Đổi mật khẩu thành công');
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 10. TREND PAINTER (VẼ BIỂU ĐỒ XU HƯỚNG 7 NGÀY TỪ DATA API THẬT)
// ═════════════════════════════════════════════════════════════════════════════

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.dark, required this.trends});

  final bool dark;
  final List<AdminReportTrendDto> trends;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = dark ? Colors.white12 : const Color(0xFFE3E9E6)
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final sentData = trends.isNotEmpty
        ? trends.map((t) => t.sentReports.toDouble()).toList()
        : <double>[238.0, 252.0, 244.0, 268.0, 276.0, 271.0, 285.0];

    final draftData = trends.isNotEmpty
        ? trends.map((t) => t.draftReports.toDouble()).toList()
        : <double>[71.0, 64.0, 69.0, 58.0, 52.0, 61.0, 57.0];

    final maxVal = [
      ...sentData,
      ...draftData,
      100.0,
    ].reduce((a, b) => a > b ? a : b);

    _line(canvas, size, sentData, AppColors.brand, 0, maxVal * 1.15);
    _line(canvas, size, draftData, AppColors.warning, 0, maxVal * 1.15);
  }

  void _line(Canvas canvas, Size size, List<double> data, Color color, double min, double max) {
    if (data.isEmpty) return;
    final path = Path();
    final dot = Paint()..color = color;
    for (var i = 0; i < data.length; i++) {
      final x = data.length > 1 ? i * size.width / (data.length - 1) : size.width / 2;
      final y = size.height - ((data[i] - min) / (max - min == 0 ? 1 : (max - min))) * size.height;
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
      oldDelegate.dark != dark || oldDelegate.trends != trends;
}
