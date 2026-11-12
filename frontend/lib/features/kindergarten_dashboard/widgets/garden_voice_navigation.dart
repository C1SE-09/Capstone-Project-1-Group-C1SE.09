import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GardenVoiceNavigationItem {
  const GardenVoiceNavigationItem({
    required this.label,
    required this.activeAsset,
    required this.inactiveAsset,
    this.tooltip,
    this.size = 28,
    this.action = false,
  });

  final String label;
  final String activeAsset;
  final String inactiveAsset;
  final String? tooltip;
  final double size;
  final bool action;
}

/// Capsule dùng chung; wrapper từng vai trò giữ enum và callback nghiệp vụ.
class GardenVoiceNavigation extends StatelessWidget {
  const GardenVoiceNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.parent,
  });

  final List<GardenVoiceNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool parent;

  @override
  Widget build(BuildContext context) => Theme(
        data: gardenVoiceNavigationTheme(Theme.of(context)),
        child: Builder(builder: (context) {
          final k = context.k;
          return SafeArea(
            top: false,
            child: SizedBox(
              height: 76,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 362),
                    child: DecoratedBox(
                      key: ValueKey(
                          'garden-voice-${parent ? 'parent' : 'teacher'}-navigation'),
                      decoration: BoxDecoration(
                        color: k.navigationSurface,
                        border: Border.all(color: k.lineStrong),
                        borderRadius: BorderRadius.circular(parent ? 24 : 30),
                        boxShadow: [
                          BoxShadow(
                            color: k.navigationShadow,
                            offset: const Offset(0, 3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 60,
                        child: Padding(
                          // 5dp Auto Layout + 1dp stroke trong node Figma.
                          padding: const EdgeInsets.all(6),
                          child: LayoutBuilder(builder: (context, constraints) {
                            final hasSelection = selectedIndex >= 0 &&
                                selectedIndex < items.length &&
                                !items[selectedIndex].action;
                            final borderWidth =
                                parent && hasSelection ? 2.0 : 0.0;
                            final width = (constraints.maxWidth -
                                    3 * (items.length - 1) -
                                    borderWidth) /
                                items.length;
                            final duration =
                                MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 220);
                            return Stack(
                              children: [
                                if (hasSelection)
                                  AnimatedPositioned(
                                    duration: duration,
                                    curve: Curves.easeOut,
                                    left: selectedIndex * (width + 3),
                                    top: 0,
                                    width: width + borderWidth,
                                    height: 48,
                                    child: DecoratedBox(
                                      key: const ValueKey(
                                          'navigation-selected-indicator'),
                                      decoration: BoxDecoration(
                                        color: k.navigationSelected,
                                        border: parent
                                            ? Border.all(
                                                color:
                                                    k.navigationSelectedBorder)
                                            : null,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                  ),
                                Row(spacing: 3, children: [
                                  for (var index = 0;
                                      index < items.length;
                                      index++)
                                    _item(
                                        context,
                                        index,
                                        width +
                                            (index == selectedIndex
                                                ? borderWidth
                                                : 0)),
                                ]),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      );

  Widget _item(BuildContext context, int index, double width) {
    final k = context.k;
    final item = items[index];
    final selected = index == selectedIndex && !item.action;
    return SizedBox(
      width: width,
      height: 48,
      child: Tooltip(
        message: item.tooltip ?? item.label,
        child: Semantics(
          button: true,
          selected: selected,
          label: item.label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(24),
              child: Center(
                child: ExcludeSemantics(
                  child: item.action
                      ? _NavigationAction(item: item, palette: k)
                      : TweenAnimationBuilder<double>(
                          tween: Tween(end: selected ? 1 : 0),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          builder: (context, value, _) => SizedBox(
                            width: item.size,
                            height: item.size,
                            child: Stack(children: [
                              Opacity(
                                  opacity: 1 - value,
                                  child: SvgPicture(
                                      SvgAssetLoader(item.inactiveAsset,
                                          colorMapper: _NavigationColors(k)),
                                      width: item.size,
                                      height: item.size)),
                              Opacity(
                                  opacity: value,
                                  child: SvgPicture(
                                      SvgAssetLoader(item.activeAsset,
                                          colorMapper: _NavigationColors(k)),
                                      width: item.size,
                                      height: item.size)),
                            ]),
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

class _NavigationAction extends StatefulWidget {
  const _NavigationAction({required this.item, required this.palette});
  final GardenVoiceNavigationItem item;
  final KPalette palette;
  @override
  State<_NavigationAction> createState() => _NavigationActionState();
}

class _NavigationActionState extends State<_NavigationAction> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .96 : 1,
          duration: const Duration(milliseconds: 100),
          child: SvgPicture(
              SvgAssetLoader(widget.item.inactiveAsset,
                  colorMapper: _NavigationColors(widget.palette)),
              width: widget.item.size,
              height: widget.item.size),
        ),
      );
}

class _NavigationColors extends ColorMapper {
  const _NavigationColors(this.palette);
  final KPalette palette;

  @override
  Color substitute(
      String? id, String elementName, String attributeName, Color color) {
    const source = KPalette.gardenVoice;
    if (color == source.brand) return palette.brand;
    if (color == source.inkSoft) return palette.inkSoft;
    if (color == source.navigationSelected) return palette.navigationSelected;
    if (color == source.navigationPortrait) return palette.navigationPortrait;
    return color;
  }

  @override
  bool operator ==(Object other) =>
      other is _NavigationColors && other.palette == palette;

  @override
  int get hashCode => palette.hashCode;
}
