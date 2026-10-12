import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../l10n/strings.dart';
import '../screens/legal/legal_screen.dart';

/// Width from which the footer spreads into one left/right row.
const double kLegalFooterWideBreakpoint = 720;

/// Copyright, "powered by", imprint/privacy links and version.
///
/// Narrow: copyright + powered-by on one line, imprint · privacy · version
/// below it at the very bottom. Wide: one row, copyright left, links right.
class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key, this.divider = true});

  /// Draws a hairline above the footer (off when embedded in a list).
  final bool divider;

  Future<void> _open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Tight letter spacing so copyright and "powered by" fit one phone line.
    final small = theme.textTheme.bodySmall?.copyWith(letterSpacing: 0);
    final muted = small?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final link = TextButton.styleFrom(
      // 48dp tall touch targets; no side padding so gaps stay even with text.
      minimumSize: const Size(48, 48),
      padding: EdgeInsets.zero,
      textStyle: small,
    );
    // Enlarged system text may wrap; at normal sizes each group stays on one
    // line and scales down slightly on very narrow screens instead.
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    Widget separator() => ExcludeSemantics(child: Text('·', style: muted));
    Widget line(List<Widget> children, WrapAlignment alignment) {
      if (largeText) {
        return Wrap(
          alignment: alignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: children,
        );
      }
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: switch (alignment) {
          WrapAlignment.start => Alignment.centerLeft,
          WrapAlignment.end => Alignment.centerRight,
          _ => Alignment.center,
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              children[i],
            ],
          ],
        ),
      );
    }

    final credits = [
      Text('© ${DateTime.now().year}', style: muted),
      TextButton(
        key: const Key('copyrightLink'),
        style: link,
        onPressed: () => _open(kCopyrightUrl),
        child: const Text(kCopyrightHolder),
      ),
      separator(),
      Text(context.l10n.poweredBy, style: muted),
      TextButton(
        key: const Key('poweredByLink'),
        style: link,
        onPressed: () => _open(kPoweredByUrl),
        child: const Text(kPoweredByLabel),
      ),
    ];
    final legal = [
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
      separator(),
      TextButton(
        key: const Key('licenseLink'),
        style: link,
        onPressed: () => showLicensePage(
          context: context,
          applicationName: 'qontract',
          applicationVersion: kAppVersion,
          applicationLegalese: '© ${DateTime.now().year} $kCopyrightHolder\n'
              '${context.l10n.licensedUnder(kLicenseName)}',
        ),
        child: Tooltip(
            message: context.l10n.license, child: const Text(kLicenseName)),
      ),
      separator(),
      Text(context.l10n.appVersion(kAppVersion),
          key: const Key('appVersion'), style: muted),
    ];

    return DecoratedBox(
      key: const Key('legalFooter'),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: theme.colorScheme.outlineVariant))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= kLegalFooterWideBreakpoint
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: line(credits, WrapAlignment.start)),
                        const SizedBox(width: 24),
                        line(legal, WrapAlignment.end),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        line(credits, WrapAlignment.center),
                        line(legal, WrapAlignment.center),
                      ],
                    ),
        ),
      ),
    );
  }
}

/// Public-page body that keeps [LegalFooter] at the bottom of the screen and
/// lets it scroll with the content once the content no longer fits.
class LegalFooterLayout extends StatelessWidget {
  const LegalFooterLayout({
    super.key,
    required this.child,
    this.maxWidth = 400,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;

  /// Width limit of [child]; the footer always spans the full width.
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            // spaceBetween with an empty first child centers the content in
            // the space above the footer without measuring intrinsic heights.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox.shrink(),
                Center(
                  child: Padding(
                    padding: padding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: child,
                    ),
                  ),
                ),
                const LegalFooter(),
              ],
            ),
          ),
        ),
      );
}
