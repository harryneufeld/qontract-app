import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/auth_provider.dart';
import '../screens/account/two_factor_screen.dart';
import '../services/api_service.dart';
import 'app_design.dart';

/// A non-blocking security suggestion, dismissed for the current login.
class TwoFactorReminder extends StatelessWidget {
  final ApiService? api;
  const TwoFactorReminder({super.key, this.api});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.showTwoFactorReminder) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.group),
      child: AppPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(builder: (context, constraints) {
          final inline = constraints.maxWidth /
                  MediaQuery.textScalerOf(context).scale(1) >=
              640;
          final setup = TextButton(
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(horizontal: inline ? 12 : 0)),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => TwoFactorScreen(api: api)));
              if (context.mounted) await auth.refreshTwoFactorReminder();
            },
            child: Text(context.l10n.twoFactorReminderSetup),
          );
          return Row(
            crossAxisAlignment:
                inline ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.twoFactorReminderTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(context.l10n.twoFactorReminderDescription),
                  if (!inline)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: setup,
                      ),
                    ),
                ],
              )),
              const SizedBox(width: AppSpace.control),
              if (inline) ...[setup, const SizedBox(width: AppSpace.control)],
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: context.l10n.twoFactorReminderDismiss,
                onPressed: auth.dismissTwoFactorReminder,
                icon: const Icon(Icons.close),
              ),
            ],
          );
        }),
      ),
    );
  }
}
