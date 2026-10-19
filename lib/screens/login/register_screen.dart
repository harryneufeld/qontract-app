import '../../l10n/strings.dart';
import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../legal/legal_screen.dart';
import 'email_confirmation_screen.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/legal_footer.dart';

class RegisterScreen extends StatefulWidget {
  final bool invitationOnly;
  final ApiService? api;
  const RegisterScreen({super.key, this.invitationOnly = false, this.api});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _tenant = TextEditingController();
  final _code = TextEditingController();
  String _type = 'Family';
  late final ApiService _api = widget.api ?? ApiService();
  RegistrationPolicy? _policy;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<RegistrationPolicy?> _loadPolicy() async {
    try {
      final policy = await _api.registrationPolicy();
      if (mounted) setState(() => _policy = policy);
      return policy;
    } catch (_) {
      // Older servers or offline: the server still rejects missing acceptance.
      return null;
    }
  }

  Future<void> _openTerms() async {
    final url = Uri.tryParse(_policy?.termsUrl ?? '');
    if (url != null &&
        await launchUrl(url, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (mounted) {
      showToast(context, context.l10n.couldNotOpenTermsOfUse,
          style: ToastStyle.error);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _password,
      _confirm,
      _tenant,
      _code,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (context.read<AuthProvider>().isLoading) return;
    if (!_form.currentState!.validate()) return;
    // A policy that failed to load may hide terms the server requires.
    if (_policy == null && (await _loadPolicy())?.hasTerms == true) return;
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final email = _email.text.trim();
    final outcome = await auth.register({
      'name': _name.text.trim(),
      'email': email,
      'password': _password.text,
      if (!widget.invitationOnly) 'tenantName': _tenant.text.trim(),
      if (!widget.invitationOnly) 'tenantType': _type,
      if (widget.invitationOnly) 'invitationCode': _code.text.trim(),
      if (_policy?.hasTerms == true) 'acceptedTermsVersion': _policy!.termsVersion,
    });
    if (outcome != RegisterOutcome.failed) {
      TextInput.finishAutofillContext(shouldSave: true);
    }
    if (!mounted) return;
    if (outcome == RegisterOutcome.signedIn) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
    } else if (outcome == RegisterOutcome.confirmationRequired) {
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => EmailConfirmationSentScreen(email: email),
      ));
    } else {
      showToast(
        context,
        auth.errorMessage ?? context.l10n.couldNotCreateYourAccount,
        style: ToastStyle.error,
      );
    }
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.l10n.thisFieldIsRequired
      : null;

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      appBar: AppBar(
        actions: const [LanguagePicker(compact: true)],
        title: Text(
          widget.invitationOnly
              ? context.l10n.joinWithInvitation
              : context.l10n.createAccount,
        ),
      ),
      body: SafeArea(
        top: false,
        child: LegalFooterLayout(
          maxWidth: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.invitationOnly
                    ? context.l10n.createAnAccountToJoinTheTenantThat
                    : context.l10n.createYourAccountAndYourFirstTenant,
              ),
              const SizedBox(height: 20),
              AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Form(
                  key: _form,
                  child: AppFormColumn(
                    children: [
                      TextFormField(
                        key: const Key('registerName'),
                        controller: _name,
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: context.l10n.yourName,
                        ),
                        validator: _required,
                      ),
                      TextFormField(
                        key: const Key('registerEmail'),
                        controller: _email,
                        autofillHints: const [
                              AutofillHints.username,
                          AutofillHints.email,
                        ],
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.none,
                        textInputAction: TextInputAction.next,
                        maxLength: 100,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: context.l10n.email,
                        ),
                        validator: (value) =>
                            _required(value) ??
                            ((value!.contains('@') && value.contains('.'))
                                ? null
                                : context.l10n.enterAValidEmail),
                      ),
                      TextFormField(
                        key: const Key('registerPassword'),
                        controller: _password,
                        autofillHints: const [AutofillHints.newPassword],
                        keyboardType: TextInputType.visiblePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        obscureText: true,
                        maxLength: 255,
                        decoration: InputDecoration(
                          labelText: context.l10n.password,
                          helperText: context.l10n.atLeast10Characters,
                        ),
                        validator: (value) => (value?.length ?? 0) < 10
                            ? context.l10n.useAtLeast10Characters
                            : null,
                      ),
                      TextFormField(
                        controller: _confirm,
                        autofillHints: const [AutofillHints.newPassword],
                        keyboardType: TextInputType.visiblePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: context.l10n.confirmPassword,
                        ),
                        validator: (value) => value != _password.text
                            ? context.l10n.passwordsDoNotMatch
                            : null,
                      ),
                      if (widget.invitationOnly)
                        TextFormField(
                          key: const Key('registerCode'),
                          controller: _code,
                          decoration: InputDecoration(
                            labelText: context.l10n.invitationCode,
                          ),
                          validator: (value) => value?.trim().length != 64
                              ? context.l10n.pasteTheCompleteInvitationCode
                              : null,
                        )
                      else ...[
                        TextFormField(
                          key: const Key('registerTenant'),
                          controller: _tenant,
                          maxLength: 100,
                          decoration: InputDecoration(
                            labelText: context.l10n.tenantName,
                          ),
                          validator: _required,
                        ),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _type,
                          decoration: InputDecoration(
                            labelText: context.l10n.tenantType,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Family',
                              child: Text(context.l10n.standard),
                            ),
                            DropdownMenuItem(
                              value: 'Company',
                              child: Text(context.l10n.company),
                            ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) => setState(() => _type = value!),
                        ),
                      ],
                      if (_policy?.hasTerms == true) ...[
                        const SizedBox(height: 16),
                        FormField<bool>(
                          key: const Key('registerTerms'),
                          validator: (_) => _termsAccepted
                              ? null
                              : context.l10n.acceptTermsToContinue,
                          builder: (field) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: _termsAccepted,
                                onChanged: busy
                                    ? null
                                    : (value) {
                                        setState(() =>
                                            _termsAccepted = value ?? false);
                                        field.didChange(_termsAccepted);
                                      },
                                title: Text(context.l10n.acceptTermsOfUse),
                                subtitle: field.errorText == null
                                    ? null
                                    : Text(
                                        field.errorText!,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                      ),
                              ),
                              TextButton.icon(
                                onPressed: _openTerms,
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: Text(context.l10n.readTermsOfUse),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          alignment: AlignmentDirectional.centerStart,
                        ),
                        onPressed: () =>
                            LegalScreen.open(context, LegalPage.privacy),
                        child: Text(context.l10n.privacyNoticeAtSignup),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : _submit,
                        child: Text(
                          busy
                              ? context.l10n.creatingAccount
                              : widget.invitationOnly
                              ? context.l10n.joinTenant
                              : context.l10n.createAccount,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
