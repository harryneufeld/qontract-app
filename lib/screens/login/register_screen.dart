import '../../l10n/strings.dart';
import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/legal_footer.dart';

class RegisterScreen extends StatefulWidget {
  final bool invitationOnly;
  const RegisterScreen({super.key, this.invitationOnly = false});

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
    final auth = context.read<AuthProvider>();
    final ok = await auth.register({
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
      if (!widget.invitationOnly) 'tenantName': _tenant.text.trim(),
      if (!widget.invitationOnly) 'tenantType': _type,
      if (widget.invitationOnly) 'invitationCode': _code.text.trim(),
    });
    if (ok) TextInput.finishAutofillContext(shouldSave: true);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
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
                          AutofillHints.newUsername,
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
                      const SizedBox(height: 24),
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
