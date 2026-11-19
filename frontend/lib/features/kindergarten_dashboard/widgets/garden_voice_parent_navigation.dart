import 'package:adark_frontend/core/localization/locale_controller.dart';
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GardenVoiceNavigation(
      selectedIndex: selected.index,
      onSelected: (index) =>
          onSelected(GardenVoiceParentDestination.values[index]),
      parent: true,
      items: [
        GardenVoiceNavigationItem(
          label: l10n?.navOverview ?? 'Tổng quan',
          activeAsset: 'assets/garden_voice/parent_nav_home_active.svg',
          inactiveAsset: 'assets/garden_voice/parent_nav_home_inactive.svg',
        ),
        GardenVoiceNavigationItem(
          label: l10n?.navReports ?? 'Báo cáo',
          activeAsset: 'assets/garden_voice/parent_nav_reports_active.svg',
          inactiveAsset:
              'assets/garden_voice/parent_nav_reports_inactive.svg',
        ),
        GardenVoiceNavigationItem(
          label: l10n?.navNotifications ?? 'Thông báo',
          tooltip: 'Mở thông báo',
          activeAsset:
              'assets/garden_voice/parent_nav_notifications_active.svg',
          inactiveAsset:
              'assets/garden_voice/parent_nav_notifications_inactive.svg',
        ),
        GardenVoiceNavigationItem(
          label: l10n?.navAccount ?? 'Tài khoản',
          activeAsset: 'assets/garden_voice/parent_nav_account_active.svg',
          inactiveAsset:
              'assets/garden_voice/parent_nav_account_inactive.svg',
          size: 29,
        ),
      ],
    );
  }
}
