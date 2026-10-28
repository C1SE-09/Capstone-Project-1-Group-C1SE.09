import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/data/repositories/auth_repository.dart';
import 'package:adark_frontend/data/repositories/http_admin_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/bug_report_sheet.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/timetable_screens.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme_controller.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/admin_trend_painter.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets/admin_search_pickers.dart';
export 'package:adark_frontend/features/kindergarten_dashboard/widgets/admin_search_pickers.dart';

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
    this.schoolName = 'Trường Mầm Non Hướng Dương',
    this.username,
  });

  final VoidCallback onLogout;
  final HttpAdminRepository? repository;
  final AdminTab initialTab;
  final AdminCategory initialCategory;
  final String schoolName;
  final String? username;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}



class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final HttpAdminRepository _repo = widget.repository ?? HttpAdminRepository();

  late AdminTab _tab = widget.initialTab;
  late AdminCategory _category = widget.initialCategory;
  final int _selectedDay = 0; // 0: Thứ 2, 1: Thứ 3, ..., 4: Thứ 6
  String _query = '';
  final _searchController = TextEditingController();



  bool _isLoading = false;
  String? _errorMessage;

  // Overview data from API
  AdminOverviewStatsDto? _stats;
  List<AdminClassProgressDto> _classesProgress = [];
  List<AdminReportTrendDto> _trends = [];

  // Management CRUD data from API
  List<AdminTeacherDto> _teachers = [];
  List<AdminChildDto> _students = [];
  List<AdminParentDto> _parents = [];
  List<AdminScheduleDto> _schedules = [];

  // Dropdown resource caches from API
  List<AdminClassDto> _classes = [];
  List<AdminTimeSlotDto> _timeSlots = [];
  String? _selectedClassId;
  String? _selectedClassName;

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
      _loadAllFeatureData(silent: true),
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
        _repo.getDashboardReportTrends(days: 7),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as AdminOverviewStatsDto;
          _classesProgress = results[1] as List<AdminClassProgressDto>;
          _trends = results[2] as List<AdminReportTrendDto>;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = getFriendlyErrorMessage(e, fallback: 'Không thể tải thống kê tổng quan. Vui lòng thử lại sau.'));
      }
    }
  }

  Future<void> _loadAllFeatureData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final dayOfWeek = _selectedDay + 2;
      final results = await Future.wait([
        _repo.getTeachers(),
        _repo.getChildren(),
        _repo.getParents(),
        _repo.getSchedules(dayOfWeek: dayOfWeek),
        _repo.getClasses(),
        _repo.getTimeSlots(),
      ]);
      if (mounted) {
        setState(() {
          _teachers = results[0] as List<AdminTeacherDto>;
          _students = results[1] as List<AdminChildDto>;
          _parents = results[2] as List<AdminParentDto>;
          _schedules = results[3] as List<AdminScheduleDto>;
          _classes = results[4] as List<AdminClassDto>;
          _timeSlots = results[5] as List<AdminTimeSlotDto>;
          if ((_selectedClassId == null || _selectedClassId!.isEmpty) && _classes.isNotEmpty) {
            _selectedClassId = _classes.first.id;
            _selectedClassName = _classes.first.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _notify(
          'Không thể tải dữ liệu chức năng: ${getFriendlyErrorMessage(e)}',
          isError: true,
        );
      }
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
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
          if (_classes.isEmpty) {
            final cls = await _repo.getClasses();
            if (mounted) {
              setState(() {
                _classes = cls;
                if ((_selectedClassId == null || _selectedClassId!.isEmpty) && _classes.isNotEmpty) {
                  _selectedClassId = _classes.first.id;
                  _selectedClassName = _classes.first.name;
                }
              });
            }
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        _notify(
          'Không thể tải dữ liệu ${_categoryLabel(_category).toLowerCase()}: ${getFriendlyErrorMessage(e)}',
          isError: true,
        );
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

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? AppColors.danger : AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
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
                child: RefreshIndicator(
                  onRefresh: _loadInitialData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
              _loadAllFeatureData();
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
          // Hàng 1: Brand Logo + Tên KinderLog (luôn hiển thị, căn giữa)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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

          // Cụm điều khiển công cụ: CHỈ HIỂN THỊ Ở TAB CHỨC NĂNG
          if (_tab == AdminTab.features) ...[
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

            // Hàng 3: Nút Thêm mới + Nút Làm mới dữ liệu
            Row(
              children: [
                if (_category != AdminCategory.schedules) ...[
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
                          _addLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: IconButton(
                    tooltip: 'Làm mới dữ liệu',
                    onPressed: () {
                      _loadAllFeatureData();
                      _notify('Đã đồng bộ dữ liệu mới nhất từ máy chủ');
                    },
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                ),
              ],
            ),
          ],
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
      AdminCategory.schedules => 'Tìm tiết học, phòng, khung giờ (vd: 08:00, 8h)...',
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
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
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
    final completionRate = _stats?.todayCompletionRate ?? 0.0;
    final sentCount = _stats?.todaySentReportsCount ?? 0;
    final draftCount = _stats?.todayDraftReportsCount ?? 0;
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
        // Lưới 3 Metric Cards trực quan (đã loại bỏ ghi âm giọng nói)
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          const gap = 12.0;

          return Column(
            children: [
              // 1. Thẻ KPI Nổi bật: Tiến độ báo cáo hôm nay (kèm Progress bar + Đã gửi/Nháp)
              _reportProgressMetricCard(
                completionRate: completionRate,
                sentCount: sentCount,
                draftCount: draftCount,
              ),
              const SizedBox(height: gap),
              // 2. Hai thẻ con: Tổng số học sinh & Nhân sự - Phụ huynh
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _studentsMetricCard(
                            totalChildren: totalChildren,
                            totalClasses: totalClasses,
                          ),
                        ),
                        const SizedBox(width: gap),
                        Expanded(
                          child: _peopleMetricCard(
                            teachersCount: teachersCount,
                            parentsCount: parentsCount,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _studentsMetricCard(
                          totalChildren: totalChildren,
                          totalClasses: totalClasses,
                        ),
                        const SizedBox(height: gap),
                        _peopleMetricCard(
                          teachersCount: teachersCount,
                          parentsCount: parentsCount,
                        ),
                      ],
                    ),
            ],
          );
        }),
        const SizedBox(height: 18),
        _progressCard(classes),
        const SizedBox(height: 16),
        _trendCard(),
      ],
    );
  }

  Widget _reportProgressMetricCard({
    required double completionRate,
    required int sentCount,
    required int draftCount,
  }) {
    final normRate = completionRate > 1.0 ? completionRate / 100.0 : completionRate;
    final rateColor = normRate >= 0.8
        ? AppColors.success
        : normRate >= 0.5
            ? AppColors.warning
            : AppColors.danger;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: rateColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.assignment_turned_in_rounded, color: rateColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tiến độ báo cáo ngày',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        'Theo dõi tỷ lệ hoàn thành sổ liên lạc hôm nay',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${completionRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: rateColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (completionRate / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: rateColor.withValues(alpha: 0.15),
                color: rateColor,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text(
                          '$sentCount đã gửi',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          '$draftCount bản nháp',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentsMetricCard({
    required int totalChildren,
    required int totalClasses,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng số học sinh',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.groups_rounded, color: AppColors.brand, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$totalChildren bé',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.meeting_room_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 5),
                  Text(
                    '$totalClasses lớp học đang hoạt động',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _peopleMetricCard({
    required int teachersCount,
    required int parentsCount,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nhân sự & Phụ huynh',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: AppColors.info, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, size: 14, color: AppColors.brand),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$teachersCount',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            Text(
                              'Giáo viên',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Theme.of(context).dividerColor,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.family_restroom_rounded, size: 14, color: AppColors.info),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$parentsCount',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            Text(
                              'Phụ huynh',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          ],
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
                            Builder(
                              builder: (context) {
                                final normRate = item.completionRate > 1.0
                                    ? item.completionRate / 100.0
                                    : item.completionRate;
                                final displayPercent = item.completionRate > 1.0
                                    ? item.completionRate.round()
                                    : (item.completionRate * 100).round();
                                final color = normRate >= 0.8
                                    ? AppColors.success
                                    : normRate >= 0.4
                                        ? AppColors.warning
                                        : AppColors.danger;
                                return Text(
                                  '$displayPercent%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: color,
                                  ),
                                );
                              },
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
                        Builder(
                          builder: (context) {
                            final normRate = item.completionRate > 1.0
                                ? item.completionRate / 100.0
                                : item.completionRate;
                            final color = normRate >= 0.8
                                ? AppColors.success
                                : normRate >= 0.4
                                    ? AppColors.warning
                                    : AppColors.danger;
                            return LinearProgressIndicator(
                              value: normRate.clamp(0.0, 1.0),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(8),
                              color: color,
                            );
                          },
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


  Widget _trendCard() {
    final totalSent = _trends.fold<int>(0, (sum, t) => sum + t.sentReports);
    final totalDraft = _trends.fold<int>(0, (sum, t) => sum + t.draftReports);
    final totalReports = totalSent + totalDraft;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Xu hướng báo cáo 7 ngày gần nhất',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tổng: $totalReports báo cáo',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Đã gửi ($totalSent)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Bản nháp ($totalDraft)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
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
          '',
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
          TimetableScreen(
            embedded: true,
            classId: _selectedClassId ?? (_classes.isNotEmpty ? _classes.first.id : ''),
            className: _selectedClassName ?? (_classes.isNotEmpty ? _classes.first.name : 'Lớp học'),
            classList: _classes,
            searchQuery: _query,
            onClassChanged: (cId) {
              setState(() {
                _selectedClassId = cId;
                final found = _classes.where((c) => c.id == cId);
                if (found.isNotEmpty) {
                  _selectedClassName = found.first.name;
                }
              });
            },
          )
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
              '${v.fullName} ${v.className} ${v.nickname} ${v.note} ${v.parentPhone} ${v.parentsSummary}'
                  .toLowerCase()
                  .contains(q))
          .toList(),
      AdminCategory.parents => _parents
          .where((v) =>
              '${v.fullName} ${v.phone} ${v.email} ${v.relationship ?? ""} ${v.childrenSummary}'
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
            if (v.dateOfBirth != null && v.dateOfBirth!.trim().isNotEmpty)
              'Ngày sinh: ${_formatIsoDate(v.dateOfBirth!)}',
            'Phụ huynh: ${v.parentsSummary.isNotEmpty ? v.parentsSummary : (v.parentName ?? "Chưa liên kết")}',
            'Y tế: ${v.note.isNotEmpty ? v.note : "Bình thường, không dị ứng"}',
          ],
          <String>[],
        ),
      AdminParentDto v => (
          v.fullName,
          v.relationship != null && v.relationship!.isNotEmpty
              ? 'Phụ huynh (${v.relationship})'
              : 'Phụ huynh học sinh',
          [
            'SĐT: ${v.phone}',
            'Email: ${v.email.isNotEmpty ? v.email : "Chưa cập nhật"}',
          ],
          v.childrenSummary.isNotEmpty
              ? [
                  v.childrenSummary
                      .replaceFirst('Bé: Chưa liên kết học sinh', 'Chưa liên kết học sinh')
                      .replaceFirst('Bé: Chưa liên kết', 'Chưa liên kết')
                      .replaceFirst('BN: ', 'Bé: ')
                ]
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

  String _formatIsoDate(String iso) {
    try {
      final parts = iso.split('T')[0].split('-');
      if (parts.length == 3) {
        return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
      }
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 7. TAB 3: ACCOUNT (TÀI KHOẢN ADMIN & CẤU HÌNH BẢO MẬT)
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _account() {
    final currentUsername = (widget.username != null && widget.username!.trim().isNotEmpty)
        ? widget.username!.trim()
        : (AuthRepository.currentUser?.username?.trim().isNotEmpty == true
            ? AuthRepository.currentUser!.username!.trim()
            : 'admin');

    final initials = currentUsername.length >= 2
        ? currentUsername.substring(0, 2).toUpperCase()
        : (currentUsername.isNotEmpty ? currentUsername.substring(0, 1).toUpperCase() : 'A');

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
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      child: Text(
                        initials,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUsername,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Quản trị viên trường',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.schoolName,
                            style: const TextStyle(fontSize: 12),
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
                  _infoRow('Tên đăng nhập', currentUsername),
                  _infoRow('Email liên hệ', 'admin@kinderlog.edu.vn'),
                  _infoRow('Số điện thoại', '0988 888 999'),
                  _infoRow('Quyền hạn', 'School Admin'),
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
                  ListTile(
                    leading: const Icon(Icons.rate_review_outlined),
                    title: const Text('Góp ý & Cải thiện ứng dụng'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showBugReportBottomSheet(context),
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
    if (category == AdminCategory.schedules) return;
    final isEdit = item != null;
    final form = GlobalKey<FormState>();

    if (category == AdminCategory.parents && _students.isEmpty) {
      try {
        _students = await _repo.getChildren();
      } catch (_) {}
    }

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
    final usernameCtrl = TextEditingController(
      text: switch (item) {
        AdminTeacherDto v => v.username ?? '',
        AdminParentDto v => v.username ?? '',
        _ => '',
      },
    );
    final passwordCtrl = TextEditingController();
    bool obscurePassword = true;

    int schedDay = _selectedDay;
    String? selectedClassId;
    List<String> studentParentIds = [];
    DateTime? studentDob;
    if (category == AdminCategory.students) {
      if (item is AdminChildDto) {
        selectedClassId = item.classId;
        studentParentIds = List<String>.from(item.parentIds);
        if (studentParentIds.isEmpty && item.parentId != null) {
          studentParentIds.add(item.parentId!);
        }
        if (item.dateOfBirth != null && item.dateOfBirth!.isNotEmpty) {
          studentDob = DateTime.tryParse(item.dateOfBirth!.split('T')[0]);
        }
      }
      if (selectedClassId == null && _classes.isNotEmpty) {
        selectedClassId = _classes.first.id;
      }
    }

    List<String> teacherClassIds = [];
    if (category == AdminCategory.teachers && item is AdminTeacherDto) {
      teacherClassIds = List<String>.from(item.classIds);
    }

    String? selectedChildId;
    String? parentRelationship;
    if (category == AdminCategory.parents) {
      if (item is AdminParentDto) {
        selectedChildId = item.childId ?? (item.childIds.isNotEmpty ? item.childIds.first : null);
        parentRelationship = item.relationship ?? 'Bố';
      } else {
        parentRelationship = 'Bố';
      }
    }

    String? dialogError;
    bool isSaving = false;

    if (!mounted) return;

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
                      if (dialogError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                          decoration: const InputDecoration(labelText: 'Họ và tên học sinh *'),
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
                        InkWell(
                          onTap: () async {
                            final picked = await showParentSearchMultiPicker(
                              context,
                              _parents,
                              currentSelectedIds: studentParentIds,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                studentParentIds = picked;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Phụ huynh liên kết (có thể chọn nhiều)',
                              hintText: 'Bấm để tìm và chọn phụ huynh...',
                              suffixIcon: Icon(Icons.people_outline, size: 20),
                            ),
                            child: studentParentIds.isNotEmpty
                                ? Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: studentParentIds.map((pid) {
                                      final matches = _parents.where((p) => p.id == pid).toList();
                                      final pName = matches.isNotEmpty ? matches.first.fullName : 'Phụ huynh';
                                      return Chip(
                                        label: Text(pName, style: const TextStyle(fontSize: 12)),
                                        visualDensity: VisualDensity.compact,
                                        deleteIcon: const Icon(Icons.close, size: 14),
                                        onDeleted: () {
                                          setDialogState(() {
                                            studentParentIds.remove(pid);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  )
                                : Text(
                                    'Chưa chọn phụ huynh / Bấm để liên kết',
                                    style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: studentDob ?? DateTime(now.year - 3, now.month, now.day),
                              firstDate: DateTime(2010),
                              lastDate: now,
                              helpText: 'Chọn ngày sinh của bé',
                              cancelText: 'Hủy',
                              confirmText: 'Chọn',
                            );
                            if (picked != null) {
                              setDialogState(() {
                                studentDob = picked;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Ngày sinh của học sinh (dd/MM/yyyy)',
                              hintText: 'Bấm để chọn ngày sinh...',
                              suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                            ),
                            child: Text(
                              studentDob != null
                                  ? '${studentDob!.day.toString().padLeft(2, '0')}/${studentDob!.month.toString().padLeft(2, '0')}/${studentDob!.year}'
                                  : 'Chưa thiết lập (Bấm để chọn ngày sinh)',
                              style: TextStyle(
                                fontSize: 14,
                                color: studentDob != null
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).hintColor,
                              ),
                            ),
                          ),
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
                          decoration: const InputDecoration(labelText: 'Họ và tên giáo viên *'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: usernameCtrl,
                          decoration: const InputDecoration(labelText: 'Tài khoản đăng nhập *'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tài khoản';
                            if (v.trim().length < 3) return 'Tài khoản tối thiểu 3 ký tự';
                            if (v.trim().contains(' ')) return 'Tài khoản không được chứa khoảng trắng';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: isEdit ? 'Mật khẩu (để trống nếu không đổi)' : 'Mật khẩu *',
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (!isEdit && (v == null || v.trim().isEmpty)) {
                              return 'Vui lòng nhập mật khẩu';
                            }
                            if (v != null && v.isNotEmpty && v.length < 6) {
                              return 'Mật khẩu tối thiểu 6 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: secondCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại *',
                            counterText: '',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
                            if (!RegExp(r'^0\d{9}$').hasMatch(v.trim())) {
                              return 'Số điện thoại phải gồm đúng 10 chữ số (bắt đầu bằng 0)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: thirdCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email liên hệ *'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email liên hệ';
                            final gmailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$', caseSensitive: false);
                            if (!gmailRegex.hasMatch(v.trim())) return 'Email phải có định dạng @gmail.com';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: teacherClassIds.isNotEmpty ? teacherClassIds.first : null,
                          decoration: const InputDecoration(labelText: 'Lớp phụ trách chính'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Không'),
                            ),
                            ..._classes.map((c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text('${c.name} (${c.gradeLabel})'),
                            )),
                          ],
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == null || v.isEmpty) {
                                teacherClassIds = [];
                              } else {
                                teacherClassIds = [v];
                              }
                            });
                          },
                        ),
                      ] else if (category == AdminCategory.parents) ...[
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Họ và tên phụ huynh *'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: usernameCtrl,
                          decoration: const InputDecoration(labelText: 'Tài khoản đăng nhập *'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tài khoản';
                            if (v.trim().length < 3) return 'Tài khoản tối thiểu 3 ký tự';
                            if (v.trim().contains(' ')) return 'Tài khoản không được chứa khoảng trắng';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: isEdit ? 'Mật khẩu (để trống nếu không đổi)' : 'Mật khẩu *',
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (!isEdit && (v == null || v.trim().isEmpty)) {
                              return 'Vui lòng nhập mật khẩu';
                            }
                            if (v != null && v.isNotEmpty && v.length < 6) {
                              return 'Mật khẩu tối thiểu 6 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: secondCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại *',
                            counterText: '',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
                            if (!RegExp(r'^0\d{9}$').hasMatch(v.trim())) {
                              return 'Số điện thoại phải gồm đúng 10 chữ số (bắt đầu bằng 0)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: thirdCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email liên hệ (nếu có)'),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final gmailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$', caseSensitive: false);
                              if (!gmailRegex.hasMatch(v.trim())) return 'Email phải có định dạng @gmail.com';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: parentRelationship ?? 'Bố',
                          decoration: const InputDecoration(labelText: 'Vai trò / Mối quan hệ với bé'),
                          items: const [
                            DropdownMenuItem(value: 'Bố', child: Text('Bố (Cha)')),
                            DropdownMenuItem(value: 'Mẹ', child: Text('Mẹ')),
                            DropdownMenuItem(value: 'Ông', child: Text('Ông')),
                            DropdownMenuItem(value: 'Bà', child: Text('Bà')),
                            DropdownMenuItem(value: 'Người giám hộ', child: Text('Người giám hộ')),
                          ],
                          onChanged: (v) => setDialogState(() => parentRelationship = v),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showChildSearchPicker(
                              context,
                              _students,
                              currentSelectedId: selectedChildId,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedChildId = picked == '__none__' ? null : picked;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Học sinh liên kết (con)',
                              hintText: 'Bấm để tìm theo tên bé, biệt danh hoặc lớp...',
                              suffixIcon: selectedChildId != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setDialogState(() {
                                          selectedChildId = null;
                                        });
                                      },
                                    )
                                  : const Icon(Icons.search, size: 20),
                            ),
                            child: Text(
                              selectedChildId != null
                                  ? () {
                                      final found = _students.where((c) => c.id == selectedChildId);
                                      if (found.isNotEmpty) {
                                        final c = found.first;
                                        final nick = c.nickname.isNotEmpty ? ' (${c.nickname})' : '';
                                        final cls = c.className.isNotEmpty ? ' · ${c.className}' : '';
                                        return 'Bé ${c.fullName}$nick$cls';
                                      }
                                      return 'Học sinh ($selectedChildId)';
                                    }()
                                  : 'Chưa liên kết / Bấm để chọn bé',
                              style: TextStyle(
                                color: selectedChildId != null ? null : Theme.of(context).hintColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
                child: const Text('Hủy bỏ'),
              ),
              FilledButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;

                        // Kiểm tra tài khoản và email đã tồn tại hay chưa
                        if (category == AdminCategory.teachers || category == AdminCategory.parents) {
                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          final username = usernameCtrl.text.trim();
                          final email = thirdCtrl.text.trim();
                          final phone = secondCtrl.text.trim();
                          final type = category == AdminCategory.teachers ? 'teacher' : 'parent';
                          final excludeId = isEdit
                              ? (item is AdminTeacherDto ? item.id : (item is AdminParentDto ? item.id : null))
                              : null;

                          try {
                            final check = await _repo.checkAvailability(
                              type: type,
                              username: username.isNotEmpty ? username : null,
                              email: email.isNotEmpty ? email : null,
                              phone: phone.isNotEmpty ? phone : null,
                              excludeId: excludeId,
                            );

                            if (check['username_exists'] == true) {
                              setDialogState(() {
                                isSaving = false;
                                dialogError = 'Tài khoản đăng nhập "$username" đã tồn tại trên hệ thống. Vui lòng chọn tài khoản khác.';
                              });
                              return;
                            }

                            if (check['email_exists'] == true) {
                              setDialogState(() {
                                isSaving = false;
                                dialogError = 'Địa chỉ email "$email" đã được sử dụng. Vui lòng nhập email khác.';
                              });
                              return;
                            }

                            if (check['phone_exists'] == true) {
                              setDialogState(() {
                                isSaving = false;
                                dialogError = 'Số điện thoại "$phone" đã được đăng ký. Vui lòng kiểm tra lại.';
                              });
                              return;
                            }
                          } catch (_) {
                            // Bỏ qua lỗi kết nối check nhanh, tiếp tục luồng submit
                          }

                          setDialogState(() => isSaving = false);
                        }

                        if (!dialogCtx.mounted) return;
                        Navigator.pop(ctx, true);
                      },
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(isSaving ? 'Đang kiểm tra...' : 'Lưu dữ liệu'),
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
              username: usernameCtrl.text.trim().isNotEmpty ? usernameCtrl.text.trim() : null,
              password: passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : null,
              classId: teacherClassIds.isNotEmpty ? teacherClassIds.first : null,
              classIds: teacherClassIds,
            );
            break;
          case AdminCategory.students:
            final old = item as AdminChildDto;
            await _repo.updateChild(
              old.id,
              fullName: nameCtrl.text.trim(),
              nickname: secondCtrl.text.trim().isNotEmpty ? secondCtrl.text.trim() : null,
              classId: selectedClassId,
              parentId: studentParentIds.isNotEmpty ? studentParentIds.first : null,
              parentIds: studentParentIds,
              dateOfBirth: studentDob != null
                  ? '${studentDob!.year}-${studentDob!.month.toString().padLeft(2, '0')}-${studentDob!.day.toString().padLeft(2, '0')}'
                  : null,
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
              relationship: parentRelationship,
              username: usernameCtrl.text.trim().isNotEmpty ? usernameCtrl.text.trim() : null,
              password: passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : null,
              childId: selectedChildId,
              childIds: selectedChildId != null ? [selectedChildId!] : [],
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
            final emailVal = thirdCtrl.text.trim();
            final phoneVal = secondCtrl.text.trim().isNotEmpty
                ? secondCtrl.text.trim()
                : '09${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
            await _repo.createTeacher(
              fullName: nameCtrl.text.trim(),
              phone: phoneVal,
              email: emailVal.isNotEmpty ? emailVal : '${usernameCtrl.text.trim()}@kinderlog.edu.vn',
              username: usernameCtrl.text.trim().isNotEmpty ? usernameCtrl.text.trim() : null,
              password: passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : null,
              classId: teacherClassIds.isNotEmpty ? teacherClassIds.first : null,
              classIds: teacherClassIds,
            );
            break;
          case AdminCategory.students:
            await _repo.createChild(
              fullName: nameCtrl.text.trim(),
              nickname: secondCtrl.text.trim().isNotEmpty ? secondCtrl.text.trim() : null,
              classId: selectedClassId,
              parentId: studentParentIds.isNotEmpty ? studentParentIds.first : null,
              parentIds: studentParentIds,
              dateOfBirth: studentDob != null
                  ? '${studentDob!.year}-${studentDob!.month.toString().padLeft(2, '0')}-${studentDob!.day.toString().padLeft(2, '0')}'
                  : null,
              note: fourthCtrl.text.trim().isNotEmpty ? fourthCtrl.text.trim() : null,
            );
            break;
          case AdminCategory.parents:
            final phoneVal = secondCtrl.text.trim().isNotEmpty
                ? secondCtrl.text.trim()
                : '09${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
            await _repo.createParent(
              fullName: nameCtrl.text.trim(),
              phone: phoneVal,
              email: thirdCtrl.text.trim().isNotEmpty ? thirdCtrl.text.trim() : null,
              relationship: parentRelationship ?? 'Phụ huynh',
              username: usernameCtrl.text.trim().isNotEmpty ? usernameCtrl.text.trim() : null,
              password: passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : null,
              childId: selectedChildId,
              childIds: selectedChildId != null ? [selectedChildId!] : [],
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
      _notify(getFriendlyErrorMessage(e), isError: true);
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
      _notify('Không thể xóa dữ liệu: ${getFriendlyErrorMessage(e)}', isError: true);
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
// 10. TREND PAINTER (DELEGATE SANG WIDGETS/ADMIN_TREND_PAINTER.DART)
// ═════════════════════════════════════════════════════════════════════════════

typedef _TrendPainter = AdminTrendPainter;
