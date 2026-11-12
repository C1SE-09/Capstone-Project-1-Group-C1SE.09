import 'package:adark_frontend/features/kindergarten_dashboard/widgets/garden_voice_navigation.dart';
import 'package:flutter/material.dart';

enum GardenVoiceParentDestination { home, reports, notifications, account }

class GardenVoiceParentNavigation extends StatelessWidget
    implements PreferredSizeWidget {
  const GardenVoiceParentNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final GardenVoiceParentDestination selected;
  final ValueChanged<GardenVoiceParentDestination> onSelected;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) => GardenVoiceNavigation(
        selectedIndex: selected.index,
        onSelected: (index) =>
            onSelected(GardenVoiceParentDestination.values[index]),
        parent: true,
        items: const [
          GardenVoiceNavigationItem(
            label: 'Tổng quan',
            activeAsset: 'assets/garden_voice/parent_nav_home_active.svg',
            inactiveAsset: 'assets/garden_voice/parent_nav_home_inactive.svg',
          ),
          GardenVoiceNavigationItem(
            label: 'Báo cáo',
            activeAsset: 'assets/garden_voice/parent_nav_reports_active.svg',
            inactiveAsset:
                'assets/garden_voice/parent_nav_reports_inactive.svg',
          ),
          GardenVoiceNavigationItem(
            label: 'Thông báo',
            tooltip: 'Mở thông báo',
            activeAsset:
                'assets/garden_voice/parent_nav_notifications_active.svg',
            inactiveAsset:
                'assets/garden_voice/parent_nav_notifications_inactive.svg',
          ),
          GardenVoiceNavigationItem(
            label: 'Tài khoản',
            activeAsset: 'assets/garden_voice/parent_nav_account_active.svg',
            inactiveAsset:
                'assets/garden_voice/parent_nav_account_inactive.svg',
            size: 29,
          ),
        ],
      );
}
