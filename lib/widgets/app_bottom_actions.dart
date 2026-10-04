import 'package:flutter/material.dart';

class AppBottomAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool destructive;
  const AppBottomAction(
      {required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.destructive = false});
}

/// The page's primary action stays within reach; creation uses only a plus.
class AppBottomActions extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final List<AppBottomAction> secondary;
  const AppBottomActions(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.secondary = const []});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final action in secondary) ...[
        FloatingActionButton(
            heroTag: '${action.tooltip}-secondary',
            tooltip: action.tooltip,
            onPressed: action.onPressed,
            backgroundColor: action.destructive
                ? scheme.errorContainer
                : scheme.secondaryContainer,
            foregroundColor: action.destructive
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer,
            child: Icon(action.icon)),
        const SizedBox(width: 8),
      ],
      FloatingActionButton(
          heroTag: tooltip,
          tooltip: tooltip,
          onPressed: onPressed,
          child: Icon(icon)),
    ]);
  }
}
