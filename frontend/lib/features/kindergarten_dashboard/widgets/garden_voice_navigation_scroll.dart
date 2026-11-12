import 'package:flutter/material.dart';

/// Overlay giữ viewport cố định; chỉ padding cuối *bên trong* danh sách chừa nav.
class GardenVoiceNavigationFrame extends StatefulWidget {
  const GardenVoiceNavigationFrame(
      {super.key,
      required this.body,
      required this.navigation,
      required this.activeTab,
      required this.autoHide});
  final Widget body;
  final Widget navigation;
  final Object activeTab;
  final bool autoHide;

  static double bottomPaddingOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NavigationInset>()?.overlay ==
              true
          ? 76
          : 0;

  @override
  State<GardenVoiceNavigationFrame> createState() =>
      _GardenVoiceNavigationFrameState();
}

class _GardenVoiceNavigationFrameState
    extends State<GardenVoiceNavigationFrame> {
  bool _hidden = false;
  double _distance = 0;

  @override
  void didUpdateWidget(GardenVoiceNavigationFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTab != widget.activeTab || !widget.autoHide) {
      _hidden = false;
      _distance = 0;
    }
  }

  void _show() {
    _distance = 0;
    if (_hidden) setState(() => _hidden = false);
  }

  bool _scroll(ScrollNotification event) {
    if (!widget.autoHide ||
        event.depth != 0 ||
        event.metrics.axis != Axis.vertical) {
      return false;
    }
    if (event.context != null && !TickerMode.of(event.context!)) {
      return false;
    }
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _show();
      return false;
    }
    final metrics = event.metrics;
    if (metrics.pixels <= metrics.minScrollExtent ||
        metrics.maxScrollExtent <= metrics.minScrollExtent) {
      _show();
    } else if (event is ScrollStartNotification) {
      _distance = 0;
    } else if (event is ScrollUpdateNotification &&
        event.dragDetails != null &&
        !metrics.outOfRange) {
      final delta = event.scrollDelta ?? 0;
      if (delta.sign != _distance.sign) _distance = 0;
      _distance += delta;
      if (_distance.abs() >= 20) {
        final hidden = _distance > 0;
        if (hidden != _hidden) setState(() => _hidden = hidden);
        _distance = 0;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final hidden =
        _hidden && !media.disableAnimations && !media.accessibleNavigation;
    return Stack(fit: StackFit.expand, children: [
      Padding(
        padding: EdgeInsets.only(
            bottom: media.padding.bottom + (widget.autoHide ? 0 : 76)),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: _NavigationInset(
              overlay: widget.autoHide,
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (event) {
                  if (event.depth == 0 &&
                      TickerMode.of(event.context) &&
                      event.metrics.axis == Axis.vertical &&
                      event.metrics.maxScrollExtent <=
                          event.metrics.minScrollExtent) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _show();
                    });
                  }
                  return false;
                },
                child: NotificationListener<ScrollNotification>(
                    onNotification: _scroll, child: widget.body),
              )),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: ExcludeFocus(
          excluding: hidden,
          child: ExcludeSemantics(
            excluding: hidden,
            child: IgnorePointer(
              ignoring: hidden,
              child: AnimatedSlide(
                offset: hidden ? const Offset(0, 1.3) : Offset.zero,
                duration: media.disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: widget.navigation,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _NavigationInset extends InheritedWidget {
  const _NavigationInset({required this.overlay, required super.child});
  final bool overlay;
  @override
  bool updateShouldNotify(_NavigationInset oldWidget) =>
      oldWidget.overlay != overlay;
}
