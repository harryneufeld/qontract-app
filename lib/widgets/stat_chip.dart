import 'package:flutter/material.dart';

/// Compact, tappable stat chip for the dashboard overview row.
///
/// Shows icon + count + short label in one small pill (~54px tall) that
/// can scroll horizontally — part of the compact stats redesign (issue
/// #20) replacing the large stacked stat cards.
class StatChip extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback? onTap;

  const StatChip({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = active ? color : theme.colorScheme.surface;
    final valueColor = active ? Colors.white : color;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? color : theme.dividerColor,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: valueColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: active ? Colors.white : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: chip,
        ),
      ),
    );
  }
}
