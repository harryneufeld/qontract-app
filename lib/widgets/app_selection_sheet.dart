import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import 'app_design.dart';

/// Focused choices open within thumb reach on phones and in a dialog on desktop.
Future<T?> showAppSelection<T>(
    {required BuildContext context,
    required String title,
    required WidgetBuilder builder}) {
  Widget content(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: (MediaQuery.sizeOf(context).height * .85 -
                    MediaQuery.viewInsetsOf(context).bottom)
                .clamp(120, 900)),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(title,
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                        tooltip: context.l10n.cancel,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close))
                  ]),
                  const SizedBox(height: AppSpace.group),
                  Flexible(child: builder(context)),
                ])),
      );
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: content(context)));
  }
  return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: content(context))));
}
