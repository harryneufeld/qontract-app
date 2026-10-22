import '../../l10n/strings.dart';
import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../widgets/api_host_picker.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/legal_footer.dart';
import '../../providers/theme_mode_provider.dart';
import '../../providers/api_host_provider.dart';

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
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: Consumer<ThemeModeProvider>(
        builder: (context, theme, _) {
          return AppPageListView(
            children: [
              _SectionTitle(context.l10n.appearance),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                    builder: (context, size) => size.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(14) > 19
                        ? DropdownButtonFormField<ThemeMode>(
                            key: const Key('themeModeDropdown'),
                            initialValue: theme.themeMode,
                            isExpanded: true,
                            decoration: InputDecoration(
                                labelText: context.l10n.appearance),
                            items: [
                              DropdownMenuItem(
                                  value: ThemeMode.light,
                                  child: Text(context.l10n.light)),
                              DropdownMenuItem(
                                  value: ThemeMode.dark,
                                  child: Text(context.l10n.dark)),
                              DropdownMenuItem(
                                  value: ThemeMode.system,
                                  child: Text(context.l10n.system)),
                            ],
                            onChanged: (value) {
                              if (value != null) theme.setThemeMode(value);
                            },
                          )
                        : SegmentedButton<ThemeMode>(
                            key: const Key('themeModeSelector'),
                            segments: [
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.light,
                                icon: const Icon(Icons.light_mode),
                                label: Text(context.l10n.light),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.dark,
                                icon: const Icon(Icons.dark_mode),
                                label: Text(context.l10n.dark),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.system,
                                icon: const Icon(Icons.brightness_auto),
                                label: Text(context.l10n.system),
                              ),
                            ],
                            selected: {theme.themeMode},
                            onSelectionChanged: (selection) =>
                                theme.setThemeMode(selection.first),
                          )),
              ),
              _SectionTitle(context.l10n.language),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LanguagePicker(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(context.l10n.languageDescription),
              ),
              _SectionTitle(context.l10n.ntfTitle),
              ListTile(
                key: const Key('notificationSettingsTile'),
                leading: const Icon(Icons.notifications_outlined),
                title: Text(context.l10n.ntfSettingsTileTitle),
                subtitle: Text(context.l10n.ntfSettingsTileSubtitle),
                onTap: () => Navigator.of(context)
                    .pushNamed(AppRoutes.notificationSettings),
              ),
              _SectionTitle(context.l10n.account),
              ListTile(
                key: const Key('manageAccountTile'),
                leading: const Icon(Icons.person_outline),
                title: Text(context.l10n.manageAccount),
                subtitle: Text(context.l10n.viewAccountDetailsChangePassword),
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.account);
                },
              ),
              if (Provider.of<ApiHostProvider?>(context)?.switchingEnabled ==
                  true) ...[
                _SectionTitle(context.l10n.server),
                const ApiHostTile(),
              ],
              _SectionTitle(context.l10n.legal),
              const LegalFooter(divider: false),
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
