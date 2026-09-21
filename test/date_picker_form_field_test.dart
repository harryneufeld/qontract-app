import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/widgets/date_picker_form_field.dart';

void main() {
  group('DatePickerFormField', () {
    testWidgets('renders text field with calendar suffix icon',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatePickerFormField(
              controller: controller,
              labelText: 'Test Date',
            ),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.text('Test Date'), findsOneWidget);
    });

    testWidgets('accepts manual text input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: DatePickerFormField(
                controller: controller,
                labelText: 'Date',
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '2025-12-31');
      await tester.pump();
      expect(controller.text, '2025-12-31');
    });

    testWidgets('rejects invalid date string on validation', (tester) async {
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: DatePickerFormField(
                controller: controller,
                labelText: 'Date',
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'not-a-date');
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
    });

    testWidgets('calls onDateSelected when date is picked via dialog',
        (tester) async {
      final controller = TextEditingController();
      DateTime? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatePickerFormField(
              controller: controller,
              labelText: 'Date',
              onDateSelected: (d) => selected = d,
            ),
          ),
        ),
      );

      // Use a predictable initial date for the dialog
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();

      // Tap the OK button in the date picker dialog (accepts initial date)
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(controller.text.isNotEmpty, isTrue);
      expect(selected, isNotNull);
    });
  });
}
