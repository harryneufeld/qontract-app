import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../l10n/strings.dart';
import '../screens/legal/legal_screen.dart';

/// Imprint/privacy links, version, copyright and "powered by" line for the
/// public authentication screens and settings.
class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key});

  Future<void> _open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final link = TextButton.styleFrom(
      // 48dp tall touch targets; no side padding so gaps stay even with text.
      minimumSize: const Size(48, 48),
      padding: EdgeInsets.zero,
      textStyle: theme.textTheme.bodySmall,
    );
    Widget separator() => ExcludeSemantics(child: Text('·', style: muted));

    return Column(
      key: const Key('legalFooter'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            TextButton(
              key: const Key('imprintLink'),
              style: link,
              onPressed: () => LegalScreen.open(context, LegalPage.imprint),
              child: Text(context.l10n.imprint),
            ),
            separator(),
            TextButton(
              key: const Key('privacyLink'),
              style: link,
              onPressed: () => LegalScreen.open(context, LegalPage.privacy),
              child: Text(context.l10n.privacyPolicy),
            ),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text('© ${DateTime.now().year}', style: muted),
            TextButton(
              key: const Key('copyrightLink'),
              style: link,
              onPressed: () => _open(kCopyrightUrl),
              child: const Text(kCopyrightHolder),
            ),
            separator(),
            Text(context.l10n.appVersion(kAppVersion),
                key: const Key('appVersion'), style: muted),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(context.l10n.poweredBy, style: muted),
            TextButton(
              key: const Key('poweredByLink'),
              style: link,
              onPressed: () => _open(kPoweredByUrl),
              child: const Text(kPoweredByLabel),
            ),
          ],
        ),
      ],
    );
  }
}
