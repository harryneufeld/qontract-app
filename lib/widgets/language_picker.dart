import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/strings.dart';
import '../providers/locale_provider.dart';

/// Native language names remain recognizable even after an accidental choice.
class LanguagePicker extends StatelessWidget {
  final bool compact;
  const LanguagePicker({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final language = Provider.of<LocaleProvider?>(context);
    if (language == null) return const SizedBox.shrink();
    final labels = <String, String>{
      'system': context.l10n.deviceLanguage,
      'en': 'English',
      'de': 'Deutsch',
    };
    if (compact) {
      return PopupMenuButton<String>(
        key: const Key('languageSelector'),
        tooltip: context.l10n.language,
        icon: const Icon(Icons.language),
        initialValue: language.selection ?? 'system',
        onSelected: (value) =>
            language.setLanguage(value == 'system' ? null : value),
        itemBuilder: (_) => [
          for (final entry in labels.entries)
            PopupMenuItem(value: entry.key, child: Text(entry.value))
        ],
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('languageSelector-${language.selection}'),
      initialValue: language.selection ?? 'system',
      isExpanded: true,
      decoration: InputDecoration(
          labelText: context.l10n.language,
          prefixIcon: const Icon(Icons.language)),
      items: [
        for (final entry in labels.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value))
      ],
      onChanged: (value) =>
          language.setLanguage(value == 'system' ? null : value),
    );
  }
}
