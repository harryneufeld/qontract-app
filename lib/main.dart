import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'config/licenses.dart';
import 'config/app_info.dart';
import 'l10n/strings.dart';
import 'providers/api_host_provider.dart';
import 'providers/locale_provider.dart';
import 'app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/contract_provider.dart';
import 'providers/contractor_address_provider.dart';
import 'providers/contractor_provider.dart';
import 'providers/document_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/onboarding/setup_screen.dart';
import 'utils/reset_url.dart';
import 'widgets/document_inbox_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadAppInfo();
  registerAppLicenses();
  final language = LocaleProvider();
  await language.init();
  // The saved host must be active before the session restore hits the API.
  final apiHosts = ApiHostProvider();
  await apiHosts.init();
  runApp(MyApp(language: language, apiHosts: apiHosts));
}

class MyApp extends StatelessWidget {
  final LocaleProvider? language;
  final ApiHostProvider? apiHosts;
  const MyApp({super.key, this.language, this.apiHosts});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModeProvider()..init()),
        ChangeNotifierProvider(
          create: (_) => language ?? (LocaleProvider()..init()),
        ),
        ChangeNotifierProvider(
          create: (_) => apiHosts ?? (ApiHostProvider()..init()),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer3<ThemeModeProvider, AuthProvider, LocaleProvider>(
        builder: (context, theme, auth, language, _) => TenantScope(
          key: ValueKey('${auth.user?.id}:${auth.user?.tenantId}'),
          child: TenantApp(themeMode: theme.themeMode, locale: language.locale),
        ),
      ),
    );
  }
}

class TenantApp extends StatefulWidget {
  final ThemeMode themeMode;
  final Locale? locale;
  const TenantApp({super.key, required this.themeMode, this.locale});
  @override
  State<TenantApp> createState() => _TenantAppState();
}

class _TenantAppState extends State<TenantApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigatorKey,
        builder: (_, child) =>
            DocumentInboxListener(navigatorKey: navigatorKey, child: child!),
        locale: widget.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        title: 'qontract',
        themeMode: widget.themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routes: AppRoutes.routes,
        onGenerateInitialRoutes: (name) {
          final reset = AppRoutes.resetLinkRoute(emailedLinkRoute() ?? name);
          if (reset != null) return [reset];
          return [
            MaterialPageRoute<void>(
              settings: RouteSettings(name: name),
              builder: AppRoutes.routes[name] ?? (_) => const HomeGate(),
            ),
          ];
        },
        onGenerateRoute: (settings) =>
            AppRoutes.resetLinkRoute(settings.name ?? ''),
      );
}

/// Recreate all tenant data and navigation when the account/tenant changes.
/// Late responses can only update the discarded providers, never the new tenant.
class TenantScope extends StatelessWidget {
  final Widget child;
  const TenantScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ContractProvider()),
          ChangeNotifierProvider(create: (_) => DocumentProvider()),
          ChangeNotifierProvider(create: (_) => ContractorProvider()),
          ChangeNotifierProvider(create: (_) => ContractorAddressProvider()),
        ],
        child: child,
      );
}

/// Session gate: restores a saved session, then shows either the
/// dashboard (authenticated) or the login screen.
class HomeGate extends StatefulWidget {
  const HomeGate({super.key});

  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restore();
    });
  }

  Future<void> _restore() async {
    await context.read<AuthProvider>().checkSession();
    if (mounted) setState(() => _restoring = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) return const LoginScreen();
    return auth.user!.onboardingCompleted
        ? const DashboardScreen()
        : const SetupScreen();
  }
}
