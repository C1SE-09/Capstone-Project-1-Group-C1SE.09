import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum GardenVoiceTeacherDestination {
  home,
  classList,
  record,
  reports,
  account,
}

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
  Widget build(BuildContext context) {
    return GardenVoiceScope(
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
                      key: const ValueKey('garden-voice-teacher-navigation'),
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
                        child: Row(
                          children: [
                            _item(
                              context,
                              destination: GardenVoiceTeacherDestination.home,
                              label: 'Tổng quan',
                              activeAsset:
                                  'assets/garden_voice/nav_home_active.svg',
                              inactiveAsset:
                                  'assets/garden_voice/nav_home_inactive.svg',
                            ),
                            _item(
                              context,
                              destination:
                                  GardenVoiceTeacherDestination.classList,
                              label: 'Lớp',
                              activeAsset:
                                  'assets/garden_voice/nav_class_active.svg',
                              inactiveAsset:
                                  'assets/garden_voice/nav_class_inactive.svg',
                            ),
                            _item(
                              context,
                              destination: GardenVoiceTeacherDestination.record,
                              label: 'Ghi âm',
                              activeAsset:
                                  'assets/garden_voice/nav_mic_action.svg',
                              inactiveAsset:
                                  'assets/garden_voice/nav_mic_action.svg',
                              size: 30,
                            ),
                            _item(
                              context,
                              destination:
                                  GardenVoiceTeacherDestination.reports,
                              label: 'Báo cáo',
                              activeAsset:
                                  'assets/garden_voice/nav_reports_active.svg',
                              inactiveAsset:
                                  'assets/garden_voice/nav_reports_inactive.svg',
                            ),
                            _item(
                              context,
                              destination:
                                  GardenVoiceTeacherDestination.account,
                              label: 'Tài khoản',
                              activeAsset:
                                  'assets/garden_voice/nav_account_active.svg',
                              inactiveAsset:
                                  'assets/garden_voice/nav_account_inactive.svg',
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
          );
        },
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required GardenVoiceTeacherDestination destination,
    required String label,
    required String activeAsset,
    required String inactiveAsset,
    double size = 28,
  }) {
    final k = context.k;
    final isAction = destination == GardenVoiceTeacherDestination.record;
    final isSelected = !isAction && selected == destination;
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(destination),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? k.brandTint : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
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
    );
  }
}
