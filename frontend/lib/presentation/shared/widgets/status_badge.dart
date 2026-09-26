import 'package:flutter/material.dart';

enum StatusType { success, info, warning, error }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusType.info,
  });

  Color _getBadgeColor(BuildContext context) {
    switch (type) {
      case StatusType.success:
        return Colors.green.withOpacity(0.1);
      case StatusType.info:
        return Theme.of(context).colorScheme.primary.withOpacity(0.1);
      case StatusType.warning:
        return Colors.orange.withOpacity(0.1);
      case StatusType.error:
        return Colors.red.withOpacity(0.1);
    }
  }

  Color _getTextColor(BuildContext context) {
    switch (type) {
      case StatusType.success:
        return Colors.green.shade700;
      case StatusType.info:
        return Theme.of(context).colorScheme.primary;
      case StatusType.warning:
        return Colors.orange.shade800;
      case StatusType.error:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _getBadgeColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getTextColor(context).withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _getTextColor(context),
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}