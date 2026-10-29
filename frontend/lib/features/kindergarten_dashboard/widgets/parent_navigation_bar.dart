import 'package:flutter/material.dart';

import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';

/// Thanh hai tab gọn của phụ huynh, cùng hình thức với mẫu Figma.
class ParentNavigationBar extends StatelessWidget {
  const ParentNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.unreadCount,
    this.backgroundColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadCount;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            KSpace.x5, KSpace.x2, KSpace.x5, KSpace.x4),
        child: Material(
          key: const ValueKey('parent-bottom-navigation'),
          color: backgroundColor ?? k.surface,
          borderRadius: BorderRadius.circular(KRadii.card),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                for (final (index, label) in const [
                  (0, 'Tổng quan'),
                  (1, 'Tài khoản')
                ])
                  Expanded(
                    child: Semantics(
                      selected: selectedIndex == index,
                      child: TextButton(
                        onPressed: () => onSelected(index),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 12),
                          foregroundColor:
                              selectedIndex == index ? k.brand : k.ink,
                          textStyle: TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 12,
                            fontWeight: selectedIndex == index
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        child: index == 0
                            ? Badge(
                                key: ValueKey(selectedIndex == 0
                                    ? 'parent-unread-badge-selected'
                                    : 'parent-unread-badge'),
                                isLabelVisible: unreadCount > 0,
                                label: Text('$unreadCount'),
                                child: Text(label),
                              )
                            : Text(label),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
