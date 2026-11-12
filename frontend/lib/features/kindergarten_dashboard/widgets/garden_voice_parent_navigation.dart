import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  Widget build(BuildContext context) => GardenVoiceScope(
        child: Builder(
          builder: (context) {
            final k = context.k;
            return SafeArea(
              top: false,
              child: SizedBox(
                height: preferredSize.height,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 362),
                      child: DecoratedBox(
                        key: const ValueKey('garden-voice-parent-navigation'),
                        decoration: BoxDecoration(
                          color: k.surface,
                          border: Border.all(color: k.line),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A0D1F1C),
                              offset: Offset(0, 3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          height: 60,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              children: [
                              _item(
                                context,
                                destination: GardenVoiceParentDestination.home,
                                label: 'Tổng quan',
                                activeAsset:
                                    'assets/garden_voice/parent_nav_home_active.svg',
                                inactiveAsset:
                                    'assets/garden_voice/parent_nav_home_inactive.svg',
                              ),
                              _item(
                                context,
                                destination:
                                    GardenVoiceParentDestination.reports,
                                label: 'Báo cáo',
                                activeAsset:
                                    'assets/garden_voice/parent_nav_reports_active.svg',
                                inactiveAsset:
                                    'assets/garden_voice/parent_nav_reports_inactive.svg',
                              ),
                              _item(
                                context,
                                destination:
                                    GardenVoiceParentDestination.notifications,
                                label: 'Thông báo',
                                tooltip: 'Mở thông báo',
                                activeAsset:
                                    'assets/garden_voice/parent_nav_notifications_active.svg',
                                inactiveAsset:
                                    'assets/garden_voice/parent_nav_notifications_inactive.svg',
                              ),
                              _item(
                                context,
                                destination:
                                    GardenVoiceParentDestination.account,
                                label: 'Tài khoản',
                                activeAsset:
                                    'assets/garden_voice/parent_nav_account_active.svg',
                                inactiveAsset:
                                    'assets/garden_voice/parent_nav_account_inactive.svg',
                                size: 29,
                              ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _item(
    BuildContext context, {
    required GardenVoiceParentDestination destination,
    required String label,
    required String activeAsset,
    required String inactiveAsset,
    String? tooltip,
    double size = 28,
  }) {
    final isSelected = selected == destination;
    return Expanded(
      child: Tooltip(
        message: tooltip ?? label,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(destination),
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 48,
                child: Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          isSelected ? context.k.brandTint : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: ExcludeSemantics(
                      child: SvgPicture.asset(
                        isSelected ? activeAsset : inactiveAsset,
                        width: size,
                        height: size,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
