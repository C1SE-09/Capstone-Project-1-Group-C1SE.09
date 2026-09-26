// frontend/lib/presentation/teacher/pages/teacher_bottom_navigation.dart
// ================================================================
// Khung điều hướng chính dành cho giáo viên.
// 3 tab: Tổng quan / Báo cáo lớp / Ghi nhận hoạt động.

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/presentation/teacher/pages/activity_recording_screen.dart';
import 'package:adark_frontend/presentation/teacher/pages/class_report_list_screen.dart';
import 'package:adark_frontend/presentation/teacher/pages/teacher_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TeacherBottomNavigation extends StatefulWidget {
  const TeacherBottomNavigation({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<TeacherBottomNavigation> createState() =>
      _TeacherBottomNavigationState();
}

class _TeacherBottomNavigationState extends State<TeacherBottomNavigation> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  late final List<Widget> _pages = const [
    TeacherScreen(),
    ClassReportListScreen(),
    ActivityRecordingScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // IndexedStack giữ nguyên trạng thái từng tab khi chuyển qua lại.
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard_rounded),
            label: l10n.overview,
          ),
          NavigationDestination(
            icon: const Icon(Icons.assessment_outlined),
            selectedIcon: const Icon(Icons.assessment_rounded),
            label: l10n.classReport,
          ),
          NavigationDestination(
            icon: const Icon(Icons.mic_none_rounded),
            selectedIcon: const Icon(Icons.mic_rounded),
            label: l10n.activityRecording,
          ),
        ],
      ),
    );
  }
}
