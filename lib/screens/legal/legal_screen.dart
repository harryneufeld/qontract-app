import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../widgets/app_design.dart';
import 'legal_content.dart';

enum LegalPage { imprint, privacy }

/// Imprint and privacy policy. Reachable without signing in.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.page});

  final LegalPage page;

  static Future<void> open(BuildContext context, LegalPage page) =>
      Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => LegalScreen(page: page)));

  @override
  Widget build(BuildContext context) {
    final german = Localizations.localeOf(context).languageCode == 'de';
    final sections = switch (page) {
      LegalPage.imprint => german ? imprintDe : imprintEn,
      LegalPage.privacy => german ? privacyDe : privacyEn,
    };
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
          title: Text(page == LegalPage.imprint
              ? context.l10n.imprint
              : context.l10n.privacyPolicy)),
      body: AppPageListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          for (final section in sections) ...[
            if (section.heading != null)
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Semantics(
                  header: true,
                  child: Text(section.heading!,
                      style: theme.textTheme.titleMedium),
                ),
              ),
            for (final paragraph in section.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText(paragraph,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              ),
          ],
        ],
      ),
    );
  }
}
