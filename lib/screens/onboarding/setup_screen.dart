import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/legal_footer.dart';
import '../../widgets/wordmark.dart';

/// First-run setup right after sign-up: just a name, a currency and the app
/// language. Everything else (workspaces, security) can wait; every account
/// already has its personal workspace.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  /// Currencies offered in the picker; Settings still accepts any ISO code.
  static const currencies = [
    'EUR',
    'USD',
    'GBP',
    'CHF',
    'SEK',
    'NOK',
    'DKK',
    'PLN',
    'CZK',
    'CAD',
    'AUD',
    'JPY',
  ];

  /// A sensible default from the device region; Euro when unknown.
  static String defaultCurrencyFor(String? countryCode) =>
      switch (countryCode) {
        'CH' || 'LI' => 'CHF',
        'GB' => 'GBP',
        'US' => 'USD',
        'SE' => 'SEK',
        'NO' => 'NOK',
        'DK' => 'DKK',
        'PL' => 'PLN',
        'CZ' => 'CZK',
        'CA' => 'CAD',
        'AU' => 'AUD',
        'JP' => 'JPY',
        _ => 'EUR',
      };

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _currency;
  late String _language;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    // Sign-up stores the part before the @ as a placeholder name.
    final placeholder = user.email.split('@').first;
    _name =
        TextEditingController(text: user.name == placeholder ? '' : user.name);
    _currency = user.defaultCurrency ??
        SetupScreen.defaultCurrencyFor(
            WidgetsBinding.instance.platformDispatcher.locale.countryCode);
    _language = S.languageCode == 'de' ? 'de' : 'en';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool skip}) async {
    if (_saving) return;
    if (!skip && !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final locale = context.read<LocaleProvider>();
    if (!skip) await locale.setLanguage(_language);
    final ok = await auth.updateProfile(
      name: skip ? null : _name.text.trim(),
      defaultCurrency: skip ? null : _currency,
      language: skip ? null : _language,
      onboardingCompleted: true,
    );
    if (!mounted) return;
    // On success the signed-in gate swaps this screen for the dashboard.
    if (!ok) {
      setState(() => _saving = false);
      showToast(
        context,
        auth.errorMessage ??
            context.l10n.unableToCompleteThisRequestPleaseTryAgain,
        style: ToastStyle.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LegalFooterLayout(
            maxWidth: 480,
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: QontractWordmark()),
                  const SizedBox(height: AppSpace.section),
                  Text(
                    context.l10n.welcomeToQontract,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpace.control),
                  Text(context.l10n.setupIntro),
                  const SizedBox(height: AppSpace.section),
                  AppFormColumn(
                    children: [
                      TextFormField(
                        key: const Key('setupName'),
                        controller: _name,
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        maxLength: 100,
                        decoration:
                            InputDecoration(labelText: context.l10n.yourName),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? context.l10n.thisFieldIsRequired
                                : null,
                      ),
                      DropdownButtonFormField<String>(
                        key: const Key('setupCurrency'),
                        isExpanded: true,
                        initialValue: _currency,
                        decoration: InputDecoration(
                            labelText: context.l10n.defaultCurrency),
                        items: [
                          for (final code in {
                            ...SetupScreen.currencies,
                            _currency,
                          })
                            DropdownMenuItem(value: code, child: Text(code)),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _currency = value!),
                      ),
                      SegmentedButton<String>(
                        key: const Key('setupLanguage'),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 'en', label: Text('English')),
                          ButtonSegment(value: 'de', label: Text('Deutsch')),
                        ],
                        selected: {_language},
                        onSelectionChanged: _saving
                            ? null
                            : (value) {
                                setState(() => _language = value.single);
                                // Preview the choice immediately.
                                context
                                    .read<LocaleProvider>()
                                    .setLanguage(_language);
                              },
                      ),
                      const SizedBox(height: AppSpace.control),
                      FilledButton(
                        key: const Key('setupContinue'),
                        onPressed: _saving ? null : () => _finish(skip: false),
                        child: Text(context.l10n.getStarted),
                      ),
                      TextButton(
                        key: const Key('setupSkip'),
                        onPressed: _saving ? null : () => _finish(skip: true),
                        child: Text(context.l10n.skipForNow),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
