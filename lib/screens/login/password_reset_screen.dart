import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class PasswordResetScreen extends StatefulWidget {
  final bool complete;
  final String? token;
  final ApiService? api;
  const PasswordResetScreen(
      {super.key, this.complete = false, this.token, this.api});
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
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
            _error = 'Unable to complete this request. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.complete ? 'Set password' : 'Reset password')),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_reset_outlined, size: 48),
                      const SizedBox(height: 24),
                      if (_done) ...[
                        Text(widget.complete
                            ? 'Password updated. Sign in with your new password. If you use an authenticator, it is still required.'
                            : 'If this account is eligible, a password reset link will be sent. Check your inbox and spam folder.'),
                        const SizedBox(height: 20),
                        FilledButton(
                            onPressed: () => Navigator.of(context)
                                .pushNamedAndRemoveUntil(
                                    AppRoutes.login, (_) => false),
                            child: const Text('Back to login')),
                      ] else if (widget.complete && !_validLink) ...[
                        const Text(
                            'This link is incomplete or invalid. Request a new link.'),
                        const SizedBox(height: 20),
                        TextButton(
                            onPressed: () => Navigator.of(context)
                                .pushReplacementNamed(AppRoutes.forgotPassword),
                            child: const Text('Request a new link')),
                      ] else ...[
                        Text(widget.complete
                            ? 'Choose a new password for your account.'
                            : 'Enter your account email to receive a link. The link expires after 30 minutes.'),
                        const SizedBox(height: 24),
                        if (!widget.complete)
                          TextFormField(
                            key: const Key('resetEmail'),
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                            validator: (v) =>
                                v == null || !v.trim().contains('@')
                                    ? 'Enter a valid email.'
                                    : null,
                          ),
                        if (widget.complete) ...[
                          TextFormField(
                              key: const Key('resetNewPassword'),
                              controller: _password,
                              enabled: !_busy,
                              obscureText: true,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: const InputDecoration(
                                  labelText: 'New password'),
                              validator: (v) => v == null || v.length < 6
                                  ? 'Use at least 6 characters.'
                                  : v.length > 255
                                      ? 'Use at most 255 characters.'
                                      : null),
                          const SizedBox(height: 16),
                          TextFormField(
                              key: const Key('resetConfirmPassword'),
                              controller: _confirmation,
                              enabled: !_busy,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'Confirm password'),
                              validator: (v) => v != _password.text
                                  ? 'Passwords do not match.'
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
                                ? 'Please wait…'
                                : widget.complete
                                    ? 'Set password'
                                    : 'Send reset link')),
                        if (widget.complete)
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context)
                                      .pushReplacementNamed(
                                          AppRoutes.forgotPassword),
                              child: const Text('Request a new link')),
                      ],
                    ]),
              )),
        )),
      );
}
