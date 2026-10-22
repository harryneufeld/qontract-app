import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/widgets/coach_marks.dart';

void main() {
  testWidgets('tour walks through the steps, skips hidden targets and ends',
      (tester) async {
    final first = GlobalKey();
    final hidden = GlobalKey();
    final last = GlobalKey();
    var finished = 0;
    late BuildContext inner;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(builder: (context) {
          inner = context;
          return Column(children: [
            ElevatedButton(key: first, onPressed: () {}, child: const Text('A')),
            ElevatedButton(key: last, onPressed: () {}, child: const Text('B')),
          ]);
        }),
      ),
    ));
    CoachMarks.show(inner, [
      CoachStep(target: first, title: 'One', body: 'first body'),
      CoachStep(target: hidden, title: 'Gone', body: 'never shown'),
      CoachStep(target: last, title: 'Two', body: 'last body'),
    ], onFinished: () => finished++);
    await tester.pump();
    expect(find.text('One'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coachNext')));
    await tester.pump();
    await tester.pump(); // the hidden step advances itself
    expect(find.text('Gone'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coachNext')));
    await tester.pump();
    expect(find.byKey(const Key('coachBubble')), findsNothing);
    expect(finished, 1);
  });

  testWidgets('skipping closes the tour once', (tester) async {
    final target = GlobalKey();
    var finished = 0;
    late BuildContext inner;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(builder: (context) {
          inner = context;
          return Center(
              child: SizedBox(key: target, width: 40, height: 40));
        }),
      ),
    ));
    CoachMarks.show(inner, [
      CoachStep(target: target, title: 'One', body: 'a'),
      CoachStep(target: target, title: 'Two', body: 'b'),
    ], onFinished: () => finished++);
    await tester.pump();
    await tester.tap(find.byKey(const Key('coachSkip')));
    await tester.pump();
    expect(find.byKey(const Key('coachBubble')), findsNothing);
    expect(finished, 1);
  });
}
