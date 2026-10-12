import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/config/app_info.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/widgets/legal_footer.dart';

Widget _layout(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home:
          const Scaffold(body: LegalFooterLayout(child: SizedBox(height: 200))),
    );

double _top(WidgetTester tester, String key) =>
    tester.getCenter(find.byKey(Key(key))).dy;

Widget _app(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const Scaffold(
          body: SingleChildScrollView(child: Center(child: LegalFooter()))),
    );

void main() {
  testWidgets('footer shows version, copyright and powered-by links',
      (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    expect(find.text('Version $kAppVersion'), findsOneWidget);
    expect(find.text('© ${DateTime.now().year}'), findsOneWidget);
    expect(find.text(kCopyrightHolder), findsOneWidget);
    expect(find.text('Powered by'), findsOneWidget);
    expect(find.text(kPoweredByLabel), findsOneWidget);
    for (final key in [
      'imprintLink',
      'privacyLink',
      'copyrightLink',
      'poweredByLink'
    ]) {
      expect(
          tester.getSize(find.byKey(Key(key))).height, greaterThanOrEqualTo(48),
          reason: key);
    }
  });

  testWidgets('German imprint matches the publisher details', (tester) async {
    await tester.pumpWidget(_app(const Locale('de')));
    await tester.tap(find.text('Impressum'));
    await tester.pumpAndSettle();
    expect(find.text('Angaben gemäß §\u00a05 DDG'), findsOneWidget);
    expect(find.textContaining('Wegscheid 25'), findsOneWidget);
    expect(find.textContaining('DE341000017'), findsOneWidget);
  });

  testWidgets('privacy policy opens in English', (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.text('1. Controller'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('7. Your rights'), findsOneWidget);
  });

  for (final width in [320.0, 375.0]) {
    testWidgets('phone ${width.toInt()}: credits on one line, legal links last',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_layout(const Locale('de')));
      expect(tester.takeException(), isNull);
      expect(_top(tester, 'copyrightLink'), _top(tester, 'poweredByLink'));
      expect(_top(tester, 'imprintLink'),
          greaterThan(_top(tester, 'poweredByLink')));
      expect(_top(tester, 'privacyLink'), _top(tester, 'imprintLink'));
      // Footer sits at the bottom of the screen.
      expect(
          tester.getBottomLeft(find.byKey(const Key('legalFooter'))).dy, 700);
    });
  }

  testWidgets('desktop: one row stretched to both edges', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_layout(const Locale('en')));
    expect(_top(tester, 'copyrightLink'), _top(tester, 'imprintLink'));
    expect(tester.getTopLeft(find.text('© ${DateTime.now().year}')).dx,
        lessThan(40));
    expect(tester.getTopRight(find.byKey(const Key('appVersion'))).dx,
        greaterThan(1240));
    expect(tester.getBottomLeft(find.byKey(const Key('legalFooter'))).dy, 800);
  });
}
