// frontend/lib/features/kindergarten_dashboard/screens/admin_dashboard_screen.dart
// ==============================================================================
// Màn hình Admin Dashboard (Tổng quan quản trị hệ thống)
// Thiết kế chuẩn Figma Make / Design System của KinderLog:
// - Màu sắc: Flat UI, canvas #F6F4EF, cards #FFFFFF viền 1px #E7E3DA, brand #16665A
// - 4 Thẻ chỉ số tổng quan (Học sinh, Tiến độ báo cáo, Giọng nói, Nhân sự)
// - Bảng tiến độ theo dõi từng lớp học có thanh tiến độ (Progress bar)
// - Hàng đợi xử lý giọng nói STT & Tình trạng hạ tầng máy chủ
// - Biểu đồ xu hướng báo cáo 7 ngày gần nhất
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adark_frontend/data/repositories/http_admin_repository.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/screens/admin_management_screen.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onLogout,
    this.repository,
  });

  final VoidCallback onLogout;
  final HttpAdminRepository? repository;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final HttpAdminRepository _repo = widget.repository ?? HttpAdminRepository();

  String _activeNav = 'Tổng quan';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _schoolIndex = 0;
  final List<String> _schools = [
    'Trường Mầm Non Hướng Dương',
    'Trường Mầm Non Ánh Sao',
  ];

  bool _isLoading = false;

  // Dữ liệu mặc định từ bản vẽ thiết kế Figma (sẽ ghi đè khi gọi API thành công)
  List<AdminClassProgressDto> _classesProgress = [
    AdminClassProgressDto(
      classId: 'c1',
      className: 'Mầm 1',
      gradeLabel: 'Khối 2–3 tuổi',
      teacherName: 'Cô Nguyễn Thu Thảo',
      totalChildren: 25,
      reportedChildren: 23,
      pendingChildren: 2,
      completionRate: 92.0,
    ),
    AdminClassProgressDto(
      classId: 'c2',
      className: 'Mầm 2',
      gradeLabel: 'Khối 2–3 tuổi',
      teacherName: 'Cô Trần Thị Lan',
      totalChildren: 24,
      reportedChildren: 24,
      pendingChildren: 0,
      completionRate: 100.0,
    ),
    AdminClassProgressDto(
      classId: 'c3',
      className: 'Chồi 1',
      gradeLabel: 'Khối 3–4 tuổi',
      teacherName: 'Cô Phạm Mai Anh',
      totalChildren: 28,
      reportedChildren: 25,
      pendingChildren: 3,
      completionRate: 89.0,
    ),
    AdminClassProgressDto(
      classId: 'c4',
      className: 'Chồi 2',
      gradeLabel: 'Khối 3–4 tuổi',
      teacherName: 'Cô Lê Ngọc Hà',
      totalChildren: 27,
      reportedChildren: 21,
      pendingChildren: 6,
      completionRate: 78.0,
    ),
    AdminClassProgressDto(
      classId: 'c5',
      className: 'Lá 1',
      gradeLabel: 'Khối 4–5 tuổi',
      teacherName: 'Cô Đỗ Minh Hương',
      totalChildren: 30,
      reportedChildren: 29,
      pendingChildren: 1,
      completionRate: 97.0,
    ),
  ];

  AdminOverviewStatsDto _overviewStats = AdminOverviewStatsDto(
    totalSchools: 2,
    totalClasses: 14,
    totalChildren: 342,
    totalTeachers: 24,
    totalParents: 320,
    todayReportsCount: 342,
    todaySentReportsCount: 285,
    todayDraftReportsCount: 57,
    todayCompletionRate: 83.3,
    totalVoiceRecords: 1250,
    todayVoiceRecords: 148,
  );

  AdminVoiceStatsDto _voiceStats = AdminVoiceStatsDto(
    totalRecords: 1250,
    completedRecords: 142,
    pendingRecords: 4,
    failedRecords: 2,
    totalDurationSeconds: 13500.0, // 3h 45m
  );

  AdminSystemHealthDto _healthStats = AdminSystemHealthDto(
    databaseStatus: 'healthy',
    redisStatus: 'healthy',
    apiStatus: 'healthy',
    serverTime: '21:05:00 UTC+7',
  );

  List<AdminReportTrendDto> _reportTrends = [
    AdminReportTrendDto(reportDate: '08/10', totalReports: 309, sentReports: 238, draftReports: 71),
    AdminReportTrendDto(reportDate: '09/10', totalReports: 316, sentReports: 252, draftReports: 64),
    AdminReportTrendDto(reportDate: '10/10', totalReports: 313, sentReports: 244, draftReports: 69),
    AdminReportTrendDto(reportDate: '11/10', totalReports: 326, sentReports: 268, draftReports: 58),
    AdminReportTrendDto(reportDate: '12/10', totalReports: 328, sentReports: 276, draftReports: 52),
    AdminReportTrendDto(reportDate: '13/10', totalReports: 332, sentReports: 271, draftReports: 61),
    AdminReportTrendDto(reportDate: '14/10', totalReports: 342, sentReports: 285, draftReports: 57),
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        _repo.getDashboardOverviewStats().catchError((_) => _overviewStats),
        _repo.getDashboardClassesProgress().catchError((_) => _classesProgress),
        _repo.getDashboardVoiceStats().catchError((_) => _voiceStats),
        _repo.getDashboardReportTrends().catchError((_) => _reportTrends),
        _repo.getDashboardSystemHealth().catchError((_) => _healthStats),
      ]);

      if (mounted) {
        setState(() {
          _overviewStats = futures[0] as AdminOverviewStatsDto;
          final classes = futures[1] as List<AdminClassProgressDto>;
          if (classes.isNotEmpty) _classesProgress = classes;
          _voiceStats = futures[2] as AdminVoiceStatsDto;
          final trends = futures[3] as List<AdminReportTrendDto>;
          if (trends.isNotEmpty) _reportTrends = trends;
          _healthStats = futures[4] as AdminSystemHealthDto;
        });
      }
    } catch (_) {
      // Dùng dữ liệu thiết kế mặc định nếu offline / lỗi API
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: context.k.canvas, fontSize: 13)),
        backgroundColor: context.k.ink,
        duration: const Duration(milliseconds: 2200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<AdminClassProgressDto> get _filteredClasses {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _classesProgress;
    return _classesProgress.where((c) {
      final text = '${c.className} ${c.gradeLabel} ${c.teacherName}'.toLowerCase();
      return text.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: context.k.canvas,
      drawer: isDesktop ? null : _buildDrawer(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildHeader(isDesktop),
                if (_isLoading)
                  LinearProgressIndicator(
                    color: context.k.brand,
                    backgroundColor: context.k.surfaceSunken,
                    minHeight: 2.5,
                  ),
                Expanded(
                  child: _activeNav == 'Tổng quan'
                      ? _buildDashboardContent()
                      : _buildManagementSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // SIDEBAR & NAVIGATION
  // ══════════════════════════════════════════════════════════

  Widget _buildSidebar() {
    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: context.k.surface,
        border: Border(right: BorderSide(color: context.k.line, width: 1)),
      ),
      child: Column(
        children: [
          // Logo Header
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.k.line, width: 1)),
            ),
            child: Row(
              children: [
                _buildBrandMark(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KinderLog',
                        style: TextStyle(
                          color: context.k.brand,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'QUẢN TRỊ HỆ THỐNG',
                        style: TextStyle(
                          color: context.k.inkFaint,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    'KHÔNG GIAN LÀM VIỆC',
                    style: TextStyle(
                      color: context.k.inkFaint,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                _buildNavItem('Tổng quan', Icons.grid_view_rounded),
                _buildNavItem('Trường & Lớp học', Icons.school_outlined),
                _buildNavItem('Học sinh & Phụ huynh', Icons.people_alt_outlined),
                _buildNavItem('Giáo viên & Nhân sự', Icons.person_add_alt_outlined),
                _buildNavItem('Báo cáo ngày', Icons.description_outlined),
                _buildNavItem('Xử lý giọng nói', Icons.mic_none_outlined, badge: '6'),
                _buildNavItem('Cấu hình hệ thống', Icons.vpn_key_outlined),
              ],
            ),
          ),

          // Footer Sidebar (Trạng thái máy chủ & Profile)
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: context.k.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.k.line, width: 1)),
              ),
              child: Row(
                children: [
                  _buildBrandMark(),
                  const SizedBox(width: 12),
                  Text(
                    'KinderLog Admin',
                    style: TextStyle(
                      color: context.k.brand,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  _buildNavItem('Tổng quan', Icons.grid_view_rounded, isDrawer: true),
                  _buildNavItem('Trường & Lớp học', Icons.school_outlined, isDrawer: true),
                  _buildNavItem('Học sinh & Phụ huynh', Icons.people_alt_outlined, isDrawer: true),
                  _buildNavItem('Giáo viên & Nhân sự', Icons.person_add_alt_outlined, isDrawer: true),
                  _buildNavItem('Báo cáo ngày', Icons.description_outlined, isDrawer: true),
                  _buildNavItem('Xử lý giọng nói', Icons.mic_none_outlined, badge: '6', isDrawer: true),
                  _buildNavItem('Cấu hình hệ thống', Icons.vpn_key_outlined, isDrawer: true),
                ],
              ),
            ),
            _buildSidebarFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandMark() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.k.brand,
        borderRadius: BorderRadius.circular(KRadii.card),
      ),
      child: Center(
        child: Icon(Icons.spa_rounded, color: context.k.canvas, size: 22),
      ),
    );
  }

  Widget _buildNavItem(String label, IconData icon, {String? badge, bool isDrawer = false}) {
    final active = _activeNav == label;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: InkWell(
        onTap: () {
          setState(() => _activeNav = label);
          if (isDrawer) Navigator.of(context).pop();
          if (label != 'Tổng quan' &&
              label != 'Trường & Lớp học' &&
              label != 'Học sinh & Phụ huynh' &&
              label != 'Giáo viên & Nhân sự') {
            _notify('$label: Khu vực đang được cập nhật');
          }
        },
        borderRadius: BorderRadius.circular(KRadii.control),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? context.k.brandTint : Colors.transparent,
            borderRadius: BorderRadius.circular(KRadii.control),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? context.k.brand : context.k.inkSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? context.k.brand : context.k.inkSoft,
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.k.warnTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: context.k.warnDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.k.line, width: 1)),
      ),
      child: Column(
        children: [
          // Server status badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.k.okTint,
              borderRadius: BorderRadius.circular(KRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.k.ok,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Trạng thái máy chủ',
                        style: TextStyle(
                          color: context.k.ok,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'PostgreSQL & Redis: Hoạt động',
                  style: TextStyle(
                    color: context.k.inkSoft,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // User profile & Logout
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: context.k.brandTint,
                child: Text(
                  'A',
                  style: TextStyle(color: context.k.brand, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Quản trị',
                      style: TextStyle(color: context.k.ink, fontWeight: FontWeight.w600, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Quản trị viên',
                      style: TextStyle(color: context.k.inkFaint, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.logout_rounded, size: 18, color: context.k.inkSoft),
                tooltip: 'Đăng xuất',
                onPressed: widget.onLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // TOPBAR HEADER
  // ══════════════════════════════════════════════════════════

  Widget _buildHeader(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.k.canvas,
        border: Border(bottom: BorderSide(color: context.k.line, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDesktop)
              IconButton(
                icon: Icon(Icons.menu_rounded, color: context.k.brand),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            SizedBox(
              width: 280,
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(color: context.k.ink, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm học sinh, lớp, giáo viên...',
                  hintStyle: TextStyle(color: context.k.inkFaint, fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 18, color: context.k.inkSoft),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  filled: true,
                  fillColor: context.k.surface,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.k.line),
                    borderRadius: BorderRadius.circular(KRadii.control),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.k.brand, width: 1.5),
                    borderRadius: BorderRadius.circular(KRadii.control),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            if (isDesktop) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: context.k.brand),
                  const SizedBox(width: 6),
                  Text(
                    'Ngày thống kê: ',
                    style: TextStyle(color: context.k.inkSoft, fontSize: 12),
                  ),
                  Text(
                    'Hôm nay, ${DateFormat("dd/MM/yyyy").format(DateTime.now())}',
                    style: TextStyle(color: context.k.ink, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _schoolIndex = (_schoolIndex + 1) % _schools.length);
                  _notify('Đã chuyển sang ${_schools[_schoolIndex]}');
                },
                icon: Icon(Icons.school_outlined, size: 16, color: context.k.inkSoft),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_schools[_schoolIndex], style: TextStyle(color: context.k.ink, fontSize: 12)),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: context.k.inkSoft),
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.k.line),
                  backgroundColor: context.k.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadii.control)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            IconButton(
              onPressed: () => _notify('Bạn không có thông báo mới'),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 20, color: context.k.inkSoft),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: context.k.bad, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: () => _notify('Đã mở biểu mẫu thêm tài khoản mới'),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Thêm tài khoản mới', style: TextStyle(fontSize: 12.5)),
              style: FilledButton.styleFrom(
                backgroundColor: context.k.brand,
                foregroundColor: context.k.canvas,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadii.control)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // DASHBOARD CONTENT
  // ══════════════════════════════════════════════════════════

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      color: context.k.brand,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng quan hệ thống',
                        style: TextStyle(
                          color: context.k.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Theo dõi hoạt động trường học và tiến độ báo cáo trong ngày.',
                        style: TextStyle(color: context.k.inkSoft, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.k.surface,
                    border: Border.all(color: context.k.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(color: context.k.ok, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        'Dữ liệu vừa cập nhật lúc ${DateFormat("HH:mm").format(DateTime.now())}',
                        style: TextStyle(color: context.k.inkSoft, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4 Thẻ KPI Metrics
            _buildMetricCards(),
            const SizedBox(height: 20),

            // Bảng tiến độ & Widgets bên phải
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1080) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildClassesProgressTable()),
                      const SizedBox(width: 20),
                      SizedBox(width: 320, child: _buildRightSideWidgets()),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildClassesProgressTable(),
                      const SizedBox(height: 20),
                      _buildRightSideWidgets(),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            // Biểu đồ xu hướng 7 ngày
            _buildReportTrendCard(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // METRIC CARDS
  // ══════════════════════════════════════════════════════════

  Widget _buildMetricCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 600
                ? 2
                : 1;

        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 164,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricCard(
              icon: Icons.people_outline,
              label: 'Tổng số học sinh',
              value: '${_overviewStats.totalChildren} bé',
              detail: '${_overviewStats.totalClasses} lớp học · ${_overviewStats.totalSchools} trường',
              tintColor: context.k.brandTint,
              iconColor: context.k.brand,
            ),
            _buildMetricCard(
              icon: Icons.check_circle_outline,
              label: 'Tiến độ báo cáo ngày',
              value: '${_overviewStats.todayCompletionRate.toStringAsFixed(1)}%',
              detail: '${_overviewStats.todaySentReportsCount} đã gửi · ${_overviewStats.todayDraftReportsCount} bản nháp',
              tintColor: context.k.okTint,
              iconColor: context.k.ok,
            ),
            _buildMetricCard(
              icon: Icons.mic_none_outlined,
              label: 'Bản ghi âm giọng nói',
              value: '${_overviewStats.todayVoiceRecords} file hôm nay',
              detail: 'Tổng cộng: ${_overviewStats.totalVoiceRecords} file',
              tintColor: context.k.warnTint,
              iconColor: context.k.warn,
            ),
            _buildMetricCard(
              icon: Icons.person_outline,
              label: 'Nhân sự & Phụ huynh',
              value: '${_overviewStats.totalTeachers} giáo viên',
              detail: '${_overviewStats.totalParents} phụ huynh đang hoạt động',
              tintColor: context.k.infoTint,
              iconColor: context.k.info,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String detail,
    required Color tintColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.k.surface,
        borderRadius: BorderRadius.circular(KRadii.card),
        border: Border.all(color: context.k.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.k.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tintColor,
                  borderRadius: BorderRadius.circular(KRadii.control),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: context.k.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(color: context.k.inkFaint, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // TABLE TIẾN ĐỘ BÁO CÁO THEO LỚP
  // ══════════════════════════════════════════════════════════

  Widget _buildClassesProgressTable() {
    final list = _filteredClasses;

    return Container(
      decoration: BoxDecoration(
        color: context.k.surface,
        borderRadius: BorderRadius.circular(KRadii.card),
        border: Border.all(color: context.k.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiến độ báo cáo theo lớp học trong ngày',
                        style: TextStyle(color: context.k.ink, fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${list.length} lớp phù hợp · Cập nhật theo thời gian thực',
                        style: TextStyle(color: context.k.inkFaint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _notify('Đang hiển thị toàn bộ ${list.length} lớp học'),
                  child: Text(
                    'Xem tất cả lớp',
                    style: TextStyle(color: context.k.brand, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE7E3DA)),

          // Scrollable Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 720),
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                headingRowColor: WidgetStatePropertyAll(context.k.surfaceSunken),
                horizontalMargin: 16,
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Lớp học', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  DataColumn(label: Text('Giáo viên chủ nhiệm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  DataColumn(label: Text('Sĩ số', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  DataColumn(label: Text('Đã gửi / Đã đọc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  DataColumn(label: Text('Chưa nộp / Nháp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  DataColumn(label: Text('Tỷ lệ hoàn thành', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                ],
                rows: list.map((item) {
                  final percent = item.completionRate.clamp(0.0, 100.0);
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.className, style: TextStyle(fontWeight: FontWeight.bold, color: context.k.ink, fontSize: 13)),
                            Text(item.gradeLabel, style: TextStyle(color: context.k.inkFaint, fontSize: 11)),
                          ],
                        ),
                      ),
                      DataCell(Text(item.teacherName, style: TextStyle(color: context.k.inkSoft, fontSize: 12.5))),
                      DataCell(Text('${item.totalChildren} bé', style: TextStyle(color: context.k.inkSoft, fontSize: 12.5))),
                      DataCell(_buildStateBadge('${item.reportedChildren} bé', tone: 'ok')),
                      DataCell(_buildStateBadge('${item.pendingChildren} bé', tone: 'warn')),
                      DataCell(
                        Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent / 100,
                                  backgroundColor: context.k.surfaceSunken,
                                  color: context.k.brand,
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${percent.toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: context.k.ink, fontSize: 12)),
                          ],
                        ),
                      ),
                      DataCell(
                        TextButton(
                          onPressed: () => _notify('Đang mở chi tiết lớp ${item.className}'),
                          child: Text('Chi tiết', style: TextStyle(color: context.k.brand, fontSize: 12)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('Không tìm thấy lớp hoặc giáo viên phù hợp.', style: TextStyle(color: context.k.inkFaint, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStateBadge(String text, {required String tone}) {
    Color bg = context.k.okTint;
    Color fg = context.k.ok;
    if (tone == 'warn') {
      bg = context.k.warnTint;
      fg = context.k.warnDeep;
    } else if (tone == 'bad') {
      bg = context.k.badTint;
      fg = context.k.bad;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ══════════════════════════════════════════════════════════
  // RIGHT SIDE WIDGETS (STT + SYSTEM HEALTH)
  // ══════════════════════════════════════════════════════════

  Widget _buildRightSideWidgets() {
    return Column(
      children: [
        // Voice STT Queue Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.k.surface,
            borderRadius: BorderRadius.circular(KRadii.card),
            border: Border.all(color: context.k.line, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hàng đợi xử lý giọng nói STT', style: TextStyle(color: context.k.ink, fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text('VoiceRecordStats · Hôm nay', style: TextStyle(color: context.k.inkFaint, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: context.k.warnTint, borderRadius: BorderRadius.circular(KRadii.control)),
                    child: Icon(Icons.mic, size: 18, color: context.k.warn),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.k.surfaceSunken, borderRadius: BorderRadius.circular(KRadii.control)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tổng thời lượng', style: TextStyle(color: context.k.inkFaint, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '${(_voiceStats.totalDurationSeconds / 3600).floor()} giờ ${((_voiceStats.totalDurationSeconds % 3600) / 60).round()} phút ghi âm',
                      style: TextStyle(color: context.k.ink, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildMetricRow('Hoàn thành', '${_voiceStats.completedRecords} file', 'ok'),
              const SizedBox(height: 8),
              _buildMetricRow('Đang xử lý', '${_voiceStats.pendingRecords} file', 'warn'),
              const SizedBox(height: 8),
              _buildMetricRow('Lỗi xử lý', '${_voiceStats.failedRecords} file', 'bad'),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // System Health Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.k.surface,
            borderRadius: BorderRadius.circular(KRadii.card),
            border: Border.all(color: context.k.line, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tình trạng hạ tầng', style: TextStyle(color: context.k.ink, fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text('SystemHealthStats', style: TextStyle(color: context.k.inkFaint, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: context.k.okTint, borderRadius: BorderRadius.circular(KRadii.control)),
                    child: Icon(Icons.check_circle_outline, size: 18, color: context.k.ok),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildHealthItem('Cơ sở dữ liệu (PostgreSQL)', _healthStats.databaseStatus == 'healthy' ? 'Đang kết nối' : 'Lỗi kết nối'),
              _buildHealthItem('Bộ nhớ đệm (Redis Queue)', _healthStats.redisStatus == 'healthy' ? 'Hoạt động tốt' : 'Lỗi kết nối'),
              _buildHealthItem('Máy chủ API (FastAPI)', _healthStats.apiStatus == 'healthy' ? 'Ổn định' : 'Chưa phản hồi'),
              const Divider(color: Color(0xFFE7E3DA), height: 24),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: context.k.inkFaint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Thời gian hệ thống: ${_healthStats.serverTime.isNotEmpty ? _healthStats.serverTime : "21:05:00 UTC+7"}',
                      style: TextStyle(color: context.k.inkFaint, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, String tone) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.k.inkSoft, fontSize: 12.5)),
        _buildStateBadge(value, tone: tone),
      ],
    );
  }

  Widget _buildHealthItem(String name, String state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: context.k.ok, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: TextStyle(color: context.k.ink, fontSize: 12, fontWeight: FontWeight.w500))),
          Text(state, style: TextStyle(color: context.k.ok, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // REPORT TREND CHART (7 NGÀY GẦN NHẤT)
  // ══════════════════════════════════════════════════════════

  Widget _buildReportTrendCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.k.surface,
        borderRadius: BorderRadius.circular(KRadii.card),
        border: Border.all(color: context.k.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Xu hướng báo cáo 7 ngày gần nhất', style: TextStyle(color: context.k.ink, fontWeight: FontWeight.bold, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text('Số báo cáo được tạo và gửi đến phụ huynh', style: TextStyle(color: context.k.inkFaint, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: context.k.brand, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Đã gửi phụ huynh', style: TextStyle(color: context.k.inkSoft, fontSize: 11.5, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: context.k.warn, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Bản nháp', style: TextStyle(color: context.k.inkSoft, fontSize: 11.5, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: _ReportTrendChartPainter(
                data: _reportTrends,
                brandColor: context.k.brand,
                warnColor: context.k.warn,
                lineColor: context.k.line,
                surfaceColor: context.k.surface,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _reportTrends.map((e) {
              return Text(
                e.reportDate,
                style: TextStyle(color: context.k.inkFaint, fontSize: 11),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // MANAGEMENT CRUD FALLBACK SECTION (KHI CHỌN TAB KHÁC)
  // ══════════════════════════════════════════════════════════

  Widget _buildManagementSection() {
    AdminCategory category = AdminCategory.teachers;
    if (_activeNav == 'Học sinh & Phụ huynh') {
      category = AdminCategory.parents;
    } else if (_activeNav == 'Trường & Lớp học') {
      category = AdminCategory.schedules;
    } else if (_activeNav == 'Giáo viên & Nhân sự') {
      category = AdminCategory.teachers;
    }

    return AdminManagementScreen(
      onLogout: widget.onLogout,
      repository: _repo,
      initialCategory: category,
      embedded: true,
    );
  }
}

// ══════════════════════════════════════════════════════════
// CUSTOM LINE CHART PAINTER (VẼ ĐỒ HỌA SVG 1:1 TỪ FIGMA)
// ══════════════════════════════════════════════════════════

class _ReportTrendChartPainter extends CustomPainter {
  _ReportTrendChartPainter({
    required this.data,
    required this.brandColor,
    required this.warnColor,
    required this.lineColor,
    required this.surfaceColor,
  });

  final List<AdminReportTrendDto> data;
  final Color brandColor;
  final Color warnColor;
  final Color lineColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final gridPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    // 4 đường kẻ ngang
    const gridYValues = [0.15, 0.40, 0.65, 0.90];
    for (final gy in gridYValues) {
      final y = size.height * gy;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), gridPaint);
    }

    final n = data.length;
    final stepX = (size.width - 60) / (n > 1 ? n - 1 : 1);

    final sentPoints = <Offset>[];
    final draftPoints = <Offset>[];

    for (int i = 0; i < n; i++) {
      final x = 30 + i * stepX;
      // Normalization
      final sentNorm = ((data[i].sentReports - 200) / 100).clamp(0.0, 1.0);
      final draftNorm = ((data[i].draftReports - 30) / 60).clamp(0.0, 1.0);

      final sentY = size.height * 0.90 - sentNorm * (size.height * 0.75);
      final draftY = size.height * 0.90 - draftNorm * (size.height * 0.75);

      sentPoints.add(Offset(x, sentY));
      draftPoints.add(Offset(x, draftY));
    }

    // Vẽ đường polyline "Đã gửi"
    final sentPath = Path();
    sentPath.moveTo(sentPoints.first.dx, sentPoints.first.dy);
    for (int i = 1; i < sentPoints.length; i++) {
      sentPath.lineTo(sentPoints[i].dx, sentPoints[i].dy);
    }
    final sentStroke = Paint()
      ..color = brandColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(sentPath, sentStroke);

    // Vẽ đường polyline "Bản nháp"
    final draftPath = Path();
    draftPath.moveTo(draftPoints.first.dx, draftPoints.first.dy);
    for (int i = 1; i < draftPoints.length; i++) {
      draftPath.lineTo(draftPoints[i].dx, draftPoints[i].dy);
    }
    final draftStroke = Paint()
      ..color = warnColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(draftPath, draftStroke);

    // Vẽ các chấm tròn điểm dữ liệu
    final dotFill = Paint()..color = surfaceColor;
    final sentDotStroke = Paint()
      ..color = brandColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    final draftDotStroke = Paint()
      ..color = warnColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final p in sentPoints) {
      canvas.drawCircle(p, 4.0, dotFill);
      canvas.drawCircle(p, 4.0, sentDotStroke);
    }
    for (final p in draftPoints) {
      canvas.drawCircle(p, 3.5, dotFill);
      canvas.drawCircle(p, 3.5, draftDotStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _ReportTrendChartPainter oldDelegate) => true;
}
