import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'l10n/strings.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final language = LocaleProvider();
  await language.init();
  runApp(MyApp(language: language));
}

class MyApp extends StatelessWidget {
  final LocaleProvider? language;
  const MyApp({super.key, this.language});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModeProvider()..init()),
        ChangeNotifierProvider(
            create: (_) => language ?? (LocaleProvider()..init())),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer3<ThemeModeProvider, AuthProvider, LocaleProvider>(
        builder: (context, theme, auth, language, _) => TenantScope(
          key: ValueKey('${auth.user?.id}:${auth.user?.tenantId}'),
          child: MaterialApp(
            locale: language.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            title: 'qontract',
            themeMode: theme.themeMode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            routes: AppRoutes.routes,
            onGenerateInitialRoutes: (name) {
              final reset = AppRoutes.resetLinkRoute(name);
              if (reset != null) return [reset];
              return [
                MaterialPageRoute<void>(
                  settings: RouteSettings(name: name),
                  builder: AppRoutes.routes[name] ?? (_) => const HomeGate(),
                )
              ];
            },
            onGenerateRoute: (settings) =>
                AppRoutes.resetLinkRoute(settings.name ?? ''),
          ),
        ),
      ),
    );
  }
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final auth = context.watch<AuthProvider>();
    return auth.isAuthenticated ? const DashboardScreen() : const LoginScreen();
  }
}
