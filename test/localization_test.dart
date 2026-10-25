import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:qontract_app/app_routes.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/document.dart';
import 'package:qontract_app/models/invoice.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/app_lock_provider.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/providers/locale_provider.dart';
import 'package:qontract_app/providers/theme_mode_provider.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/providers/document_provider.dart';
import 'package:qontract_app/screens/account/account_screen.dart';
import 'package:qontract_app/screens/settings/settings_screen.dart';
import 'package:qontract_app/screens/login/login_screen.dart';
import 'package:qontract_app/screens/login/register_screen.dart';
import 'package:qontract_app/screens/login/password_reset_screen.dart';
import 'package:qontract_app/screens/contract/contract_form_screen.dart';
import 'package:qontract_app/screens/contract/contract_list_screen.dart';
import 'package:qontract_app/screens/contract/contract_detail_screen.dart';
import 'package:qontract_app/screens/contractor/contractor_list_screen.dart';
import 'package:qontract_app/screens/contractor/contractor_form_screen.dart';
import 'package:qontract_app/screens/dashboard/dashboard_screen.dart';
import 'package:qontract_app/screens/document/document_list_screen.dart';
import 'package:qontract_app/screens/invoice/invoices_screen.dart';
import 'package:qontract_app/screens/tenant/tenants_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/utils/amount_format.dart';
import 'package:qontract_app/utils/localized_input.dart';
import 'package:qontract_app/widgets/date_picker_form_field.dart';
import 'package:qontract_app/widgets/decimal_form_field.dart';

final _user = User(
    id: 1,
    name: 'Alex Beispiel',
    email: 'alex@example.test',
    role: 'TenantAdmin',
    tenantId: 7,
    createdAt: DateTime.utc(2026, 1, 1));
final _contract = Contract(
    id: 1,
    title: 'Subscription',
    status: 'Active',
    type: 'Subscription',
    value: '1234.56',
    currency: 'EUR',
    billingPeriod: 'Monthly',
    startDate: '2026-10-12',
    endDate: '2027-12-31',
    documentCount: 1,
    responsibleUserId: 1,
    responsibleUserName: 'Alex Beispiel',
    createdAt: DateTime.utc(2026, 1, 1),
    modifiedAt: DateTime.utc(2026, 10, 12));
final _document = Document(
    id: 1,
    fileName: 'Original.pdf',
    fileType: 'application/pdf',
    fileSize: 1536,
    contractId: 1,
    uploadedAt: DateTime.utc(2026, 10, 12),
    version: 1,
    title: 'Lease agreement',
    category: 'Subscription');

class _Api extends ApiService {
  _Api() : super(baseUrl: 'http://localhost');
  Contract? savedContract;
  Map<String, dynamic>? savedInvoice;
  @override
  Future<User> me() async => _user;
  @override
  Future<List<Contract>> getContracts(
          {int page = 0, int pageSize = 0, String? status}) async =>
      [_contract];
  @override
  Future<List<Contract>> getContractList() async => [_contract];
  @override
  Future<List<Contract>> getContractTrash() async => [];
  @override
  Future<Contract> getContract(int id) async => _contract;
  @override
  Future<List<Contractor>> getContractors() async => [];
  @override
  Future<String> getDefaultCurrency() async => 'EUR';
  @override
  Future<List<Map<String, dynamic>>> getResponsibleMembers() async => [
        {'id': 1, 'name': _user.name}
      ];
  @override
  Future<List<Document>> getDocuments(int contractId) async => [_document];
  @override
  Future<List<Document>> getLibraryDocuments(
          {String scope = 'Tenant',
          bool deleted = false,
          int page = 1}) async =>
      [_document];
  @override
  Future<List<Invoice>> getInvoices(
          {int? contractId, bool deleted = false, int page = 1}) async =>
      [
        Invoice(
            id: '1',
            invoiceDate: '2026-10-12',
            dueDate: '2026-10-31',
            amount: '1234.56',
            currency: 'EUR',
            invoiceNumber: 'Original invoice')
      ];
  @override
  Future<List<Map<String, dynamic>>> getMemberships() async => [
        {
          'tenantId': 7,
          'name': 'Familie Beispiel',
          'role': 'TenantAdmin',
          'type': 'Family'
        }
      ];
  @override
  Future<Map<String, dynamic>> getTenantDetails(int id) async =>
      {'name': 'Familie Beispiel', 'settings': '{}'};
  @override
  Future<List<Map<String, dynamic>>> getTenantMembers(int id) async => [
        {
          'id': 1,
          'name': _user.name,
          'email': _user.email,
          'role': 'TenantAdmin',
          'isActive': true
        }
      ];
  @override
  Future<List<Map<String, dynamic>>> getTenantInvitations(int id) async => [];
  @override
  Future<Contract> createContract(Contract contract) async {
    savedContract = contract;
    return contract;
  }

  @override
  Future<Contract> updateContract(int id, Contract contract) async {
    savedContract = contract;
    return contract;
  }

  @override
  Future<Invoice> saveInvoice(Map<String, dynamic> data, {String? id}) async {
    savedInvoice = data;
    return Invoice(
        id: '1', invoiceDate: data['invoiceDate'], amount: data['amount']);
  }
}

class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(
        {'user': jsonEncode(_user.toJson())});
    S.languageCode = 'en';
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() {
    S.languageCode = 'en';
    Intl.defaultLocale = 'en_US';
  });

  test('catalogs have identical keys and complete translations', () async {
    final english =
        jsonDecode(await File('lib/l10n/app_en.arb').readAsString()) as Map;
    final german =
        jsonDecode(await File('lib/l10n/app_de.arb').readAsString()) as Map;
    expect(german.keys.toSet(), english.keys.toSet());
    for (final entry in german.entries) {
      if (!entry.key.toString().startsWith('@')) {
        expect((entry.value as String).trim(), isNotEmpty, reason: entry.key);
      }
    }
    final de = lookupAppLocalizations(const Locale('de'));
    expect(de.documentCountLabel(1), '1 Dokument');
    expect(de.documentCountLabel(2), '2 Dokumente');
    expect(de.resultCountLabel(1), '1 Ergebnis');
    expect(de.contractCountLabel(1), '1 Vertrag');
  });
  test('German presentation never changes enum values or user content', () {
    S.languageCode = 'de';
    Intl.defaultLocale = 'de_DE';
    expect(billingPeriods['Monthly'], 'Monatlich');
    expect(contractTypes['Subscription'], 'Abonnement');
    expect(ContractStatusStyle.label('Active'), 'Aktiv');
    expect(_contract.title, 'Subscription');
    expect(_contract.toJson()['type'], 'Subscription');
    expect(_contract.toJson()['billingPeriod'], 'Monthly');
    expect(_contract.toJson()['startDate'], '2026-10-12');
    expect(_contract.value, '1234.56');
    expect(formatAmount(_contract.value, 'EUR'), contains('1.234,56'));
    expect(S.dateText('2026-10-12'), '12.10.2026');
    expect(_document.category, 'Subscription');
    expect(_document.fileSizeFormatted, '1,5 KB');
  });
  test('strict dates and exact decimal strings preserve API formats', () {
    expect(
        isoDate(parseDateInput('12.10.2026', language: 'de')!), '2026-10-12');
    expect(parseDateInput('31.02.2026', language: 'de'), isNull);
    expect(parseDateInput('2026-02-31', language: 'en'), isNull);
    expect(parseDateInput('29.02.2024', language: 'de'), isNotNull);
    expect(parseDateInput('29.02.2025', language: 'de'), isNull);
    expect(canonicalDecimal('-1234,567890123456789'), '-1234.567890123456789');
    expect(canonicalDecimal('1.234,56'), isNull);
    expect(canonicalDecimal('1,234.56'), isNull);
  });
  test(
      'existing HTTP clients follow language changes and older errors fall back safely',
      () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final languages = <String?>[];
      var modern = true;
      server.listen((request) async {
        languages.add(request.headers.value('Accept-Language'));
        request.response.headers.contentType = ContentType.json;
        if (modern) {
          request.response.headers.set(
              'Content-Language', request.headers.value('Accept-Language')!);
        }
        request.response.statusCode = 400;
        request.response.write(jsonEncode({
          'errors': {
            'NewPassword': [
              request.headers.value('Accept-Language') == 'de' && modern
                  ? 'Neues Passwort ist erforderlich.'
                  : 'New password is required.'
            ]
          }
        }));
        await request.response.close();
      });
      try {
        final api = ApiService(baseUrl: 'http://127.0.0.1:${server.port}/api');
        S.languageCode = 'de';
        await expectLater(
            api.resetPassword('A' * 64, 'new-password'),
            throwsA(isA<ApiException>().having((e) => e.message,
                'German detail', 'Neues Passwort ist erforderlich.')));
        S.languageCode = 'en';
        await expectLater(
            api.resetPassword('A' * 64, 'new-password'),
            throwsA(isA<ApiException>().having((e) => e.message,
                'English detail', 'New password is required.')));
        S.languageCode = 'de';
        modern = false;
        await expectLater(
            api.resetPassword('A' * 64, 'new-password'),
            throwsA(isA<ApiException>().having(
                (e) => e.message, 'localized fallback', 'Ungültige Anfrage.')));
        expect(languages, ['de', 'en', 'de']);
      } finally {
        await server.close(force: true);
      }
    }, _RealHttp());
  });
  testWidgets('locale follows device, persists selection and falls back safely',
      (tester) async {
    tester.binding.platformDispatcher.localesTestValue = [
      const Locale('de', 'DE')
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    final prefs = await SharedPreferences.getInstance();
    final language = LocaleProvider(prefs: prefs);
    addTearDown(language.dispose);
    await language.init();
    expect(language.locale, const Locale('de'));
    await language.setLanguage('en');
    expect(prefs.getString(LocaleProvider.storageKey), 'en');
    tester.binding.platformDispatcher.localesTestValue = [
      const Locale('de', 'AT')
    ];
    expect(language.locale, const Locale('en'));
    final restored = LocaleProvider(prefs: prefs);
    addTearDown(restored.dispose);
    await restored.init();
    expect(restored.selection, 'en');
    await restored.setLanguage(null);
    expect(restored.locale, const Locale('de'));
    expect(prefs.containsKey(LocaleProvider.storageKey), false);
    tester.binding.platformDispatcher.localesTestValue = [const Locale('fr')];
    expect(restored.locale, const Locale('en'));
    await prefs.setString(LocaleProvider.storageKey, 'invalid');
    final corrupted = LocaleProvider(prefs: prefs);
    addTearDown(corrupted.dispose);
    await corrupted.init();
    expect(corrupted.selection, isNull);
    expect(corrupted.locale, const Locale('en'));
    tester.binding.platformDispatcher.localesTestValue = [
      const Locale('fr'),
      const Locale('de')
    ];
    expect(corrupted.locale, const Locale('de'));
  });

  Future<LocaleProvider> pump(WidgetTester tester, Widget page,
      {Size size = const Size(375, 812),
      bool dark = false,
      double scale = 1,
      String languageCode = 'de',
      _Api? api}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final language = LocaleProvider();
    await language.setLanguage(languageCode);
    final service = api ?? _Api();
    final auth = AuthProvider(api: service);
    await auth.checkSession();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeModeProvider()),
          ChangeNotifierProvider(create: (_) => AppLockProvider()),
          ChangeNotifierProvider(create: (_) => ContractProvider(api: service)),
          ChangeNotifierProvider(
              create: (_) => ContractorProvider(api: service)),
          ChangeNotifierProvider(create: (_) => DocumentProvider(api: service)),
        ],
        child: Consumer<LocaleProvider>(
            builder: (context, locale, _) => MaterialApp(
                  locale: locale.locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  theme: dark ? AppTheme.dark : AppTheme.light,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale),
                          disableAnimations: true),
                      child: child!),
                  home: RepaintBoundary(key: const Key('capture'), child: page),
                  routes: {
                    '/login': (_) =>
                        const Scaffold(body: Text('Login destination'))
                  },
                ))));
    await tester.pumpAndSettle();
    return language;
  }

  Future<void> clean(WidgetTester tester, LocaleProvider language) async {
    await tester.pumpWidget(const SizedBox());
    language.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets(
      'settings switches live and persists without resetting an open route',
      (tester) async {
    final language = await pump(tester, const SettingsScreen());
    expect(find.text('Einstellungen'), findsOneWidget);
    await language.setLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance())
            .getString(LocaleProvider.storageKey),
        'de');
    expect(tester.takeException(), isNull);
    await clean(tester, language);
  });
  testWidgets(
      'German date/decimal display yields invariant controllers across language switch',
      (tester) async {
    final date = TextEditingController(text: '2026-10-12');
    final amount = TextEditingController(text: '1234.56');
    final form = GlobalKey<FormState>();
    final language = await pump(
        tester,
        Scaffold(
            body: Form(
                key: form,
                child: Column(children: [
                  DatePickerFormField(
                      controller: date,
                      labelText: 'Datum',
                      firstDate: DateTime(2026, 1, 1),
                      lastDate: DateTime(2026, 12, 31)),
                  DecimalFormField(
                      controller: amount,
                      decoration: const InputDecoration(labelText: 'Betrag')),
                ]))));
    expect(find.text('12.10.2026'), findsOneWidget);
    expect(find.text('1234,56'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Datum'), '31.02.2026');
    expect(form.currentState!.validate(), false);
    await tester.pump();
    expect(find.textContaining('gültiges Datum'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Datum'), '31.12.2026');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Betrag'), '-12,34567890123456789');
    expect(date.text, '2026-12-31');
    expect(amount.text, '-12.34567890123456789');
    expect(form.currentState!.validate(), true);
    await language.setLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text('2026-12-31'), findsOneWidget);
    expect(find.text('-12.34567890123456789'), findsOneWidget);
    expect(date.text, '2026-12-31');
    expect(tester.takeException(), isNull);
    await clean(tester, language);
    date.dispose();
    amount.dispose();
  });
  testWidgets('German calendar uses Flutter localized standard actions',
      (tester) async {
    final date = TextEditingController(text: '2026-10-12');
    final language = await pump(
        tester,
        Scaffold(
            body: DatePickerFormField(controller: date, labelText: 'Datum')));
    await tester.tap(find.byTooltip('Datum auswählen'));
    await tester.pumpAndSettle();
    expect(find.text('Abbrechen'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(date.text, '2026-10-12');
    expect(find.text('12.10.2026'), findsOneWidget);
    await clean(tester, language);
    date.dispose();
  });
  testWidgets(
      'German contract editing saves exact ISO/decimal and original enum values',
      (tester) async {
    final api = _Api();
    final language = await pump(
        tester, ContractFormScreen(api: api, contract: _contract),
        api: api);
    Future<void> enter(String label, String value) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.scrollUntilVisible(field, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.enterText(field, value);
    }

    await enter('Startdatum', '12.10.2026');
    await enter('Enddatum', '31.12.2027');
    await enter('Abrechnungsbetrag', '1234,567890123456789');
    final save = find.widgetWithText(ElevatedButton, 'Vertrag aktualisieren');
    await tester.scrollUntilVisible(save, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final valid = tester.state<FormState>(find.byType(Form)).validate();
    await tester.pumpAndSettle();
    expect(valid, true,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.savedContract!.startDate, '2026-10-12');
    expect(api.savedContract!.endDate, '2027-12-31');
    expect(api.savedContract!.value, '1234.567890123456789');
    expect(api.savedContract!.billingPeriod, 'Monthly');
    expect(api.savedContract!.type, 'Subscription');
    expect(api.savedContract!.title, 'Subscription');
    expect(tester.takeException(), isNull);
    await clean(tester, language);
  });
  testWidgets('German invoice editing saves ISO dates and signed exact amounts',
      (tester) async {
    final api = _Api();
    final language =
        await pump(tester, Scaffold(body: InvoiceEditor(api: api)));
    Future<void> enter(String label, String value) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await enter('Rechnungsdatum', '12.10.2026');
    await enter('Fällig am (optional)', '31.10.2026');
    await enter('Betrag', '-100,123456789');
    await tester.ensureVisible(find.text('Speichern'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(api.savedInvoice!['invoiceDate'], '2026-10-12');
    expect(api.savedInvoice!['dueDate'], '2026-10-31');
    expect(api.savedInvoice!['amount'], '-100.123456789');
    expect(tester.takeException(), isNull);
    await clean(tester, language);
  });
  testWidgets(
      'reset link language is session-only and leaves stored device choice intact',
      (tester) async {
    final route =
        AppRoutes.resetLinkRoute('/reset-password?token=${'A' * 64}&lang=de')!;
    final screen = (route as MaterialPageRoute).builder;
    final language =
        await pump(tester, Builder(builder: screen), languageCode: 'en');
    expect(find.text('Passwort festlegen'), findsNWidgets(2));
    expect(language.locale, const Locale('de'));
    expect(
        (await SharedPreferences.getInstance())
            .getString(LocaleProvider.storageKey),
        'en');
    expect(tester.takeException(), isNull);
    await clean(tester, language);
  });

  const capture = bool.fromEnvironment('QONTRACT_CAPTURE_LOCALIZATION');
  const previewDir = String.fromEnvironment('QONTRACT_PREVIEW_DIR');
  const fontDir = String.fromEnvironment('QONTRACT_PREVIEW_FONT_DIR',
      defaultValue: '../flutter-sdk/bin/cache/artifacts/material_fonts');
  final pages = <String, Widget Function(_Api)>{
    'settings': (_) => const SettingsScreen(),
    'login': (_) => const LoginScreen(),
    'register': (_) => const RegisterScreen(),
    'reset': (_) => const PasswordResetScreen(),
    'account': (api) => AccountScreen(api: api),
    'contracts': (_) => const ContractListScreen(),
    'contract-form': (api) => ContractFormScreen(api: api, contract: _contract),
    'contract-detail': (_) => ContractDetailScreen(contract: _contract),
    'contractors': (_) => const ContractorListScreen(),
    'contractor-form': (_) => const ContractorFormScreen(),
    'dashboard': (api) => DashboardScreen(api: api),
    'files': (api) => DocumentListScreen(api: api),
    'invoices': (api) => InvoicesScreen(api: api),
    'workspaces': (api) => TenantsScreen(api: api),
  };
  for (final scenario in [
    (const Size(375, 812), 1.0, false),
    (const Size(812, 375), 1.0, true),
    (const Size(320, 800), 2.0, true),
    (const Size(1024, 768), 1.0, false)
  ]) {
    testWidgets(
        'German pages fit ${scenario.$1} scale ${scenario.$2} dark ${scenario.$3}',
        (tester) async {
      if (capture) {
        await tester.runAsync(() async {
          final font = FontLoader('Roboto')
            ..addFont(Future.value(ByteData.sublistView(
                await File('$fontDir/roboto-regular.ttf').readAsBytes())));
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(Future.value(ByteData.sublistView(
                await File('$fontDir/materialicons-regular.otf')
                    .readAsBytes())));
          await icons.load();
          final slab = FontLoader('RobotoSlab')
            ..addFont(Future.value(ByteData.sublistView(
                await File('assets/fonts/RobotoSlab-Bold.ttf').readAsBytes())));
          await slab.load();
        });
      }
      for (final entry in pages.entries) {
        final api = _Api();
        final language = await pump(tester, entry.value(api),
            size: scenario.$1, scale: scenario.$2, dark: scenario.$3, api: api);
        if (capture && entry.key == 'login') {
          await tester.runAsync(() => precacheImage(
              const AssetImage('assets/brand/brand_icon.png'),
              tester.element(find.byType(LoginScreen))));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: entry.key);
        if (capture && previewDir.isNotEmpty) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('capture')));
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(previewDir).create(recursive: true);
            await File(
                    '$previewDir/${entry.key}-${scenario.$1.width.toInt()}-${scenario.$2}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final scrollable = find.byType(Scrollable).first;
        if (scrollable.evaluate().isNotEmpty) {
          for (var i = 0; i < 4; i++) {
            await tester.drag(scrollable, const Offset(0, -300));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull,
                reason: '${entry.key} scroll $i');
          }
        }
        await clean(tester, language);
      }
    });
  }
}
