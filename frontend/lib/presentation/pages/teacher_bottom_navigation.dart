// frontend/lib/presentation/pages/teacher_bottom_navigation.dart
// ================================================================
// Khung điều hướng chính dành cho giáo viên.
// 3 tab: Tổng quan / Báo cáo lớp / Ghi nhận hoạt động.

import 'package:adark_frontend/core/theme/app_theme.dart';
import 'package:adark_frontend/presentation/pages/activity_recording_screen.dart';
import 'package:adark_frontend/presentation/pages/class_report_list_screen.dart';
import 'package:adark_frontend/presentation/pages/teacher_screen.dart';
import 'package:flutter/material.dart';

class TeacherBottomNavigation extends StatefulWidget {
  const TeacherBottomNavigation({super.key});

  @override
  State<TeacherBottomNavigation> createState() => _TeacherBottomNavigationState();
}

class _TeacherBottomNavigationState extends State<TeacherBottomNavigation> {
  int _selectedIndex = 0;

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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment_rounded),
            label: 'Báo cáo lớp',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'Ghi nhận',
          ),
        ],
      ),
    );
  }
}
