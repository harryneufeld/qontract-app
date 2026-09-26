import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qontract_app/widgets/wordmark.dart';

void main() {
  Widget host(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );
  }

  /// The root span actually rendered: Text.rich applies its [TextStyle]
  /// at the RichText level, so read the span from there.
  TextSpan rootSpan(WidgetTester tester) {
    final rich = tester.widget<RichText>(find.byType(RichText));
    var span = rich.text as TextSpan;
    // Text.rich wraps the passed span under a styled root span.
    if (span.children?.length == 1 && span.children!.first is TextSpan) {
      span = span.children!.first as TextSpan;
    }
    return span;
  }

  List<TextSpan> spans(WidgetTester tester) =>
      rootSpan(tester).children!.cast<TextSpan>().toList();

  testWidgets('renders "qontract" in the brand slab font', (tester) async {
    await tester.pumpWidget(host(const QontractWordmark()));

    final rich = tester.widget<RichText>(find.byType(RichText));
    final span = rich.text as TextSpan;
    expect(span.toPlainText(), 'qontract');
    expect(span.style?.fontFamily, 'RobotoSlab');
    expect(span.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('light background: purple q + black ontract', (tester) async {
    await tester.pumpWidget(
        host(const QontractWordmark(), brightness: Brightness.light));

    final s = spans(tester);
    expect(s[0].text, 'q');
    expect(s[0].style!.color, kQontractPurple);
    expect(s[1].text, 'ontract');
    expect(s[1].style!.color, Colors.black);
  });

  testWidgets('dark background: black q + white ontract', (tester) async {
    await tester.pumpWidget(
        host(const QontractWordmark(), brightness: Brightness.dark));

    final s = spans(tester);
    expect(s[0].style!.color, Colors.black);
    expect(s[1].style!.color, Colors.white);
  });

  testWidgets('backgroundIsDark overrides the theme brightness',
      (tester) async {
    await tester.pumpWidget(host(
      const QontractWordmark(backgroundIsDark: true),
      brightness: Brightness.light,
    ));

    final s = spans(tester);
    expect(s[0].style!.color, Colors.black);
    expect(s[1].style!.color, Colors.white);
  });
}
