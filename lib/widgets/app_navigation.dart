import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_routes.dart';
import '../providers/auth_provider.dart';
import 'app_design.dart';
import 'wordmark.dart';

class AppNavigation extends StatelessWidget {
  final String selectedRoute;
  const AppNavigation({super.key, required this.selectedRoute});
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    const destinations = [
      (AppRoutes.dashboard, 'Dashboard', Icons.space_dashboard_outlined),
      (AppRoutes.contractList, 'Contracts', Icons.description_outlined),
      (AppRoutes.contractorList, 'Contractors', Icons.business_outlined),
      (AppRoutes.account, 'Account', Icons.person_outline),
      (AppRoutes.settings, 'Settings', Icons.settings_outlined),
    ];
    return Drawer(
        child: SafeArea(
            child: ListTileTheme(
                data: ListTileTheme.of(context).copyWith(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    minVerticalPadding: 0,
                    minTileHeight: 48),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpace.group),
                  children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.section),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const QontractWordmark(size: 28),
                              const SizedBox(height: AppSpace.group),
                              Text(auth.user?.email ?? 'Signed in',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                            ])),
                    for (final entry in destinations) ...[
                      ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        leading: Icon(entry.$3),
                        title: Text(entry.$2),
                        selected: selectedRoute == entry.$1,
                        selectedTileColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        onTap: () {
                          Navigator.of(context).pop();
                          if (selectedRoute != entry.$1) {
                            Navigator.of(context).pushNamed(entry.$1);
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                    ],
                    const Divider(),
                    ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Logout'),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          await auth.logout();
                          if (context.mounted) {
                            navigator.pushNamedAndRemoveUntil(
                                AppRoutes.login, (_) => false);
                          }
                        }),
                  ],
                ))));
  }
}
