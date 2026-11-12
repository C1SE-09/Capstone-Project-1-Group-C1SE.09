import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_navigation.dart';
import 'package:flutter/material.dart';

enum GardenVoiceTeacherDestination { home, classList, record, reports, account }

class GardenVoiceTeacherNavigation extends StatelessWidget
    implements PreferredSizeWidget {
  const GardenVoiceTeacherNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final GardenVoiceTeacherDestination selected;
  final ValueChanged<GardenVoiceTeacherDestination> onSelected;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) => GardenVoiceNavigation(
        selectedIndex: selected.index,
        onSelected: (index) =>
            onSelected(GardenVoiceTeacherDestination.values[index]),
        parent: false,
        items: const [
          GardenVoiceNavigationItem(
            label: 'Tổng quan',
            activeAsset: 'assets/garden_voice/nav_home_active.svg',
            inactiveAsset: 'assets/garden_voice/nav_home_inactive.svg',
          ),
          GardenVoiceNavigationItem(
            label: 'Lớp',
            activeAsset: 'assets/garden_voice/nav_class_active.svg',
            inactiveAsset: 'assets/garden_voice/nav_class_inactive.svg',
          ),
          GardenVoiceNavigationItem(
            label: 'Ghi âm',
            activeAsset: 'assets/garden_voice/nav_mic_action.svg',
            inactiveAsset: 'assets/garden_voice/nav_mic_action.svg',
            size: 30,
            action: true,
          ),
          GardenVoiceNavigationItem(
            label: 'Báo cáo',
            activeAsset: 'assets/garden_voice/nav_reports_active.svg',
            inactiveAsset: 'assets/garden_voice/nav_reports_inactive.svg',
          ),
          GardenVoiceNavigationItem(
            label: 'Tài khoản',
            activeAsset: 'assets/garden_voice/nav_account_active.svg',
            inactiveAsset: 'assets/garden_voice/nav_account_inactive.svg',
            size: 29,
          ),
        ],
      );
}
