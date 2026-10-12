import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/legal_footer.dart';
import '../../providers/locale_provider.dart';

class PasswordResetScreen extends StatefulWidget {
  final bool complete;
  final String? token;
  final ApiService? api;
  final String? language;
  const PasswordResetScreen(
      {super.key, this.complete = false, this.token, this.api, this.language});
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.language != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<LocaleProvider?>(context, listen: false)
              ?.useLinkLanguage(widget.language);
        }
      });
    }
  }

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final ApiService _api = widget.api ?? ApiService();
  bool _busy = false;
  bool _done = false;
  String? _error;
  bool get _validLink =>
      widget.token != null && RegExp(r'^[0-9A-F]{64}$').hasMatch(widget.token!);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.complete) {
        await _api.resetPassword(widget.token!, _password.text);
        if (!mounted) return;
        await context.read<AuthProvider>().clearRevokedSession();
      } else {
        await _api.requestPasswordReset(_email.text.trim());
      }
      if (mounted) {
        _password.clear();
        _confirmation.clear();
        setState(() => _done = true);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = context.l10n.unableToCompleteThisRequestPleaseTryAgain);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            actions: const [LanguagePicker(compact: true)],
            title: Text(widget.complete
                ? context.l10n.setPassword
                : context.l10n.resetPassword)),
        body: SafeArea(
            top: false,
            child: LegalFooterLayout(
              maxWidth: 480,
              child: Form(
                key: _form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_reset_outlined, size: 48),
                      const SizedBox(height: 24),
                      if (_done) ...[
                        Text(widget.complete
                            ? context
                                .l10n.passwordUpdatedSignInWithYourNewPassword
                            : context
                                .l10n.ifThisAccountIsEligibleAPasswordReset),
                        const SizedBox(height: 20),
                        FilledButton(
                            onPressed: () => Navigator.of(context)
                                .pushNamedAndRemoveUntil(
                                    AppRoutes.login, (_) => false),
                            child: Text(context.l10n.backToLogin)),
                      ] else if (widget.complete && !_validLink) ...[
                        Text(
                            context.l10n.thisLinkIsIncompleteOrInvalidRequestA),
                        const SizedBox(height: 20),
                        TextButton(
                            onPressed: () => Navigator.of(context)
                                .pushReplacementNamed(AppRoutes.forgotPassword),
                            child: Text(context.l10n.requestANewLink)),
                      ] else ...[
                        Text(widget.complete
                            ? context.l10n.chooseANewPasswordForYourAccount
                            : context.l10n.enterYourAccountEmailToReceiveALink),
                        const SizedBox(height: 24),
                        if (!widget.complete)
                          TextFormField(
                            key: const Key('resetEmail'),
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration:
                                InputDecoration(labelText: context.l10n.email),
                            validator: (v) =>
                                v == null || !v.trim().contains('@')
                                    ? context.l10n.enterAValidEmail
                                    : null,
                          ),
                        if (widget.complete) ...[
                          TextFormField(
                              key: const Key('resetNewPassword'),
                              controller: _password,
                              enabled: !_busy,
                              obscureText: true,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: InputDecoration(
                                  labelText: context.l10n.newPassword),
                              validator: (v) => v == null || v.length < 6
                                  ? context.l10n.useAtLeast6Characters
                                  : v.length > 255
                                      ? context.l10n.useAtMost255Characters
                                      : null),
                          const SizedBox(height: 16),
                          TextFormField(
                              key: const Key('resetConfirmPassword'),
                              controller: _confirmation,
                              enabled: !_busy,
                              obscureText: true,
                              decoration: InputDecoration(
                                  labelText: context.l10n.confirmPassword),
                              validator: (v) => v != _password.text
                                  ? context.l10n.passwordsDoNotMatch
                                  : null),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!,
                              semanticsLabel: _error,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                            key: const Key('submitPasswordReset'),
                            onPressed: _busy ? null : _submit,
                            child: Text(_busy
                                ? context.l10n.pleaseWait
                                : widget.complete
                                    ? context.l10n.setPassword
                                    : context.l10n.sendResetLink)),
                        if (widget.complete)
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context)
                                      .pushReplacementNamed(
                                          AppRoutes.forgotPassword),
                              child: Text(context.l10n.requestANewLink)),
                      ],
                    ]),
              ),
            )),
      );
}
