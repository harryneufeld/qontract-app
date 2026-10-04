import 'package:flutter/material.dart';

/// The page's primary action stays within reach; creation uses only a plus.
class AppBottomActions extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final List<Widget> secondary;
  const AppBottomActions(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.secondary = const []});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (final action in secondary) ...[action, const SizedBox(width: 8)],
        FloatingActionButton(
            heroTag: tooltip,
            tooltip: tooltip,
            onPressed: onPressed,
            child: Icon(icon)),
      ]);
}
