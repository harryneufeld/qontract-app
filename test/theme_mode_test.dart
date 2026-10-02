import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/app_routes.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:qontract_app/main.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contract_stats.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/providers/theme_mode_provider.dart';
import 'package:qontract_app/screens/dashboard/dashboard_screen.dart';
import 'package:qontract_app/screens/login/login_screen.dart';
import 'package:qontract_app/screens/settings/settings_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/storage_service.dart';

/// Provider: persistence + fallback behaviour (issue #22).
void main() {
  group('ThemeModeProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to system when nothing is stored', () async {
      final provider = ThemeModeProvider();
      await provider.init();
      expect(provider.themeMode, ThemeMode.system);
    });

    test('init restores a stored mode', () async {
      SharedPreferences.setMockInitialValues(
        {ThemeModeProvider.storageKey: 'dark'},
      );
      final provider = ThemeModeProvider();
      await provider.init();
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('init falls back to system for unknown values', () async {
      SharedPreferences.setMockInitialValues(
        {ThemeModeProvider.storageKey: 'neon'},
      );
      final provider = ThemeModeProvider();
      await provider.init();
      expect(provider.themeMode, ThemeMode.system);
    });

    test('setThemeMode notifies and persists', () async {
      final provider = ThemeModeProvider();
      await provider.init();
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);
      expect(notified, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeModeProvider.storageKey), 'light');
    });

    test(
        'setThemeMode keeps the previous value across a new provider '
        '(simulated app restart)', () async {
      final first = ThemeModeProvider();
      await first.init();
      await first.setThemeMode(ThemeMode.dark);

      final second = ThemeModeProvider();
      await second.init();
      expect(second.themeMode, ThemeMode.dark);
    });
  });

  group('Settings screen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Brightness effectiveBrightness(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

    testWidgets('switch between light / dark / system and persist',
        (tester) async {
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
      final theme = ThemeModeProvider();
      await tester.pumpWidget(_settingsHarness(theme));
      await tester.pumpAndSettle();

      // system + light platform => light.
      expect(effectiveBrightness(tester), Brightness.light);

      // Switch to dark: the whole app goes dark immediately.
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(effectiveBrightness(tester), Brightness.dark);
      expect(
        (await SharedPreferences.getInstance())
            .getString(ThemeModeProvider.storageKey),
        'dark',
      );

      // Switch to light.
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(effectiveBrightness(tester), Brightness.light);

      // Switch to system and follow a dark platform.
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(effectiveBrightness(tester), Brightness.dark);
      expect(
        (await SharedPreferences.getInstance())
            .getString(ThemeModeProvider.storageKey),
        'system',
      );
    });
  });

  group('App wiring', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('MyApp applies the stored theme mode at startup',
        (tester) async {
      SharedPreferences.setMockInitialValues(
        {ThemeModeProvider.storageKey: 'dark'},
      );
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.darkTheme, isNotNull);
      // Dark theme is actually effective on the shown screen (login,
      // since no session is seeded).
      expect(
        Theme.of(tester.element(find.byType(LoginScreen))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('dashboard opens settings from app bar and drawer',
        (tester) async {
      final auth = await _seededAuth();
      final api = _FakeApiService(contracts: [], contractors: []);
      final contracts = ContractProvider(api: api);
      final contractors = ContractorProvider(api: api);
      final theme = ThemeModeProvider();
      await theme.init();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ContractProvider>.value(value: contracts),
            ChangeNotifierProvider<ContractorProvider>.value(
                value: contractors),
            ChangeNotifierProvider<ThemeModeProvider>.value(value: theme),
          ],
          // Mirrors main.dart: providers above MaterialApp so pushed
          // routes can see them too.
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: theme.themeMode,
            routes: AppRoutes.routes,
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App bar entry.
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Drawer entry (the app bar's leading drawer button).
      await tester.tap(find.byType(DrawerButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Settings'), 100,
          scrollable: find
              .descendant(
                  of: find.byType(Drawer), matching: find.byType(Scrollable))
              .first);
    });
  });
}

/// Settings screen wired to the theme provider like the real app.
class _SettingsRoot extends StatelessWidget {
  const _SettingsRoot();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeModeProvider>();
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.themeMode,
      home: const _SettingsTarget(),
    );
  }
}

class _SettingsTarget extends StatelessWidget {
  const _SettingsTarget();

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}

Widget _settingsHarness(ThemeModeProvider theme) {
  return ChangeNotifierProvider<ThemeModeProvider>.value(
    value: theme,
    child: const _SettingsRoot(),
  );
}

// ---------------------------------------------------------------- fakes

User _user() => User(
      id: 1,
      name: 'Test User',
      email: 'test@example.com',
      role: 'User',
      tenantId: 7,
      createdAt: DateTime.utc(2026, 1, 1),
    );

class _FakeApiService extends ApiService {
  _FakeApiService({
    required List<Contract> contracts,
    required List<Contractor> contractors,
  })  : _contracts = contracts,
        _contractors = contractors,
        super(baseUrl: 'http://localhost');

  final List<Contract> _contracts;
  final List<Contractor> _contractors;

  @override
  Future<User> me() async => _user();

  @override
  Future<List<Contract>> getContracts(
      {int page = 0, int pageSize = 0, String? status}) async {
    if (page == 0 || pageSize == 0) return _contracts;
    final start = (page - 1) * pageSize;
    if (start >= _contracts.length) return [];
    return _contracts.sublist(
        start, (start + pageSize).clamp(0, _contracts.length));
  }

  @override
  Future<List<Contract>> getContractList() async => _contracts;
  @override
  Future<ContractStats> getContractStats() async =>
      throw ApiException(message: 'stats not stubbed', statusCode: 404);

  @override
  Future<List<Contractor>> getContractors() async => _contractors;
}

Future<AuthProvider> _seededAuth() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user', jsonEncode(_user().toJson()));
  final api = _FakeApiService(contracts: [], contractors: []);
  final auth = AuthProvider(api: api, storage: StorageService());
  await auth.checkSession();
  return auth;
}
