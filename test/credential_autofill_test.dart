import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/screens/login/login_screen.dart';
import 'package:qontract_app/screens/login/register_screen.dart';

class _Auth extends AuthProvider {
  bool succeeds = false;
  int attempts = 0;
  @override
  Future<bool> login(String email, String password) async {
    attempts++;
    return succeeds;
  }

  @override
  Future<RegisterOutcome> register(Map<String, dynamic> fields) async {
    attempts++;
    return succeeds ? RegisterOutcome.signedIn : RegisterOutcome.failed;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(WidgetTester tester, Widget screen, _Auth auth) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {'/dashboard': (_) => const Scaffold(body: Text('Dashboard'))},
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
    tester.testTextInput.log.clear();
  }

  List<MethodCall> finishes(WidgetTester tester) => tester.testTextInput.log
      .where((call) => call.method == 'TextInput.finishAutofillContext')
      .toList();

  testWidgets('login autofills credentials together and saves only on success',
      (tester) async {
    final auth = _Auth();
    await mount(tester, const LoginScreen(), auth);
    final fields = find.byType(TextFormField);
    await tester.tap(fields.first);
    await tester.pump();
    final editable =
        tester.widget<EditableText>(find.byType(EditableText).first);
    final group =
        AutofillGroup.of(tester.element(find.byType(EditableText).first));
    expect(group.autofillClients.length, 2);
    expect(editable.autofillHints, contains(AutofillHints.username));
    final password =
        tester.widget<EditableText>(find.byType(EditableText).last);
    expect(password.autofillHints, [AutofillHints.password]);
    expect(password.autocorrect, isFalse);
    // Simulate a platform/password manager filling the whole credential group.
    final states =
        tester.stateList<EditableTextState>(find.byType(EditableText)).toList();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/textinput',
      const JSONMethodCodec().encodeMethodCall(MethodCall(
        'TextInputClient.updateEditingStateWithTag',
        [
          -1,
          {
            states[0].autofillId:
                const TextEditingValue(text: 'test@example.com').toJSON(),
            states[1].autofillId:
                const TextEditingValue(text: 'saved-password').toJSON(),
          }
        ],
      )),
      (_) {},
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(auth.attempts, 1);
    expect(finishes(tester), isEmpty);
    auth.succeeds = true;
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(
        finishes(tester).where((call) => call.arguments == true), hasLength(1));
    expect(find.text('Dashboard'), findsOneWidget);
  });

  for (final invitation in [false, true]) {
    testWidgets(
        'signup new passwords save only after success (invite=$invitation)',
        (tester) async {
      final auth = _Auth();
      await mount(tester, RegisterScreen(invitationOnly: invitation), auth);
      final fields =
          tester.widgetList<EditableText>(find.byType(EditableText)).toList();
      expect(fields[1].autofillHints, contains(AutofillHints.username));
      expect(fields[2].autofillHints, [AutofillHints.newPassword]);
      expect(fields[3].autofillHints, [AutofillHints.newPassword]);
      await tester.enterText(
          find.byKey(const Key('registerName')), 'Test User');
      await tester.enterText(
          find.byKey(const Key('registerEmail')), 'test@example.com');
      await tester.enterText(
          find.byKey(const Key('registerPassword')), 'new-password-123');
      await tester.enterText(
          find.byType(TextFormField).at(3), 'new-password-123');
      await tester.enterText(
          find.byKey(Key(invitation ? 'registerCode' : 'registerTenant')),
          invitation ? 'a' * 64 : 'Home');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(auth.attempts, 1);
      expect(finishes(tester), isEmpty);
      auth.succeeds = true;
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(finishes(tester).where((call) => call.arguments == true),
          hasLength(1));
      expect(find.text('Dashboard'), findsOneWidget);
    });
  }

  testWidgets('leaving signup cancels saving', (tester) async {
    await mount(tester, const RegisterScreen(), _Auth());
    await tester.enterText(
        find.byKey(const Key('registerEmail')), 'test@example.com');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(finishes(tester).last.arguments, false);
  });
}
