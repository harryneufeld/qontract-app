import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../providers/theme_mode_provider.dart';

/// Settings screen (issue #22): app-level preferences.
///
/// This is the seed of the account/settings area that grows together
/// with #11 (user account page); for now it hosts the theme mode
/// switch.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<ThemeModeProvider>(
        builder: (context, theme, _) {
          return AppPageListView(
            children: [
              const _SectionTitle('Appearance'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
                  key: const Key('themeModeSelector'),
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Dark'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                      label: Text('System'),
                    ),
                  ],
                  selected: {theme.themeMode},
                  onSelectionChanged: (selection) =>
                      theme.setThemeMode(selection.first),
                ),
              ),
              const _SectionTitle('Account'),
              ListTile(
                key: const Key('manageAccountTile'),
                leading: const Icon(Icons.person_outline),
                title: const Text('Manage account'),
                subtitle: const Text('View account details, change password'),
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.account);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
