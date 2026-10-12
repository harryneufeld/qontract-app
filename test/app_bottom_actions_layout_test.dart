import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/widgets/app_bottom_actions.dart';

void main() {
  testWidgets(
      'bottom actions align with centered content on desktop and retain phone inset',
      (tester) async {
    for (final width in [375.0, 1024.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(size: Size(width, 900)),
              child: child!),
          home: Scaffold(
            body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Padding(
                        padding: EdgeInsets.all(width < 600 ? 16 : 24),
                        child: const SizedBox(
                            key: Key('content'),
                            width: double.infinity,
                            height: 100)))),
            floatingActionButton: AppBottomActions(
                icon: Icons.add, tooltip: 'Add', onPressed: () {}),
          )));
      await tester.pumpAndSettle();
      expect(
          tester.getBottomRight(find.byType(FloatingActionButton)).dx,
          closeTo(tester.getBottomRight(find.byKey(const Key('content'))).dx,
              0.01));
    }
    await tester.binding.setSurfaceSize(null);
  });
}
