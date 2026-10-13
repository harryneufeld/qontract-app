import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../app_routes.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/wordmark.dart';
import 'register_screen.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/legal_footer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _allowPublic = false;

  @override
  void initState() {
    super.initState();
    _loadRegistrationPolicy();
  }

  Future<void> _loadRegistrationPolicy() async {
    try {
      final allowed = await ApiService().publicRegistrationAllowed();
      if (mounted) setState(() => _allowPublic = allowed);
    } on ApiException {
      // Keep public signup hidden when the policy cannot be checked.
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (context.read<AuthProvider>().isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success) TextInput.finishAutofillContext(shouldSave: true);
    if (!mounted) return;
    if (success) {
      // The session gate watches AuthProvider — replace the whole stack so
      // a back-swipe can't return to the login screen.
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      showToast(
        context,
        auth.errorMessage ?? context.l10n.loginFailed603,
        style: ToastStyle.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LegalFooterLayout(
          child: AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: LanguagePicker(compact: true),
                  ),
                  Image.asset(
                    'assets/brand/brand_icon.png',
                    width: 88,
                    height: 88,
                  ),
                  const SizedBox(height: 20),
                  const QontractWordmark(size: 34, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.contractManagement,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: context.l10n.email,
                      prefixIcon: const Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.l10n.pleaseEnterYourEmail;
                      }
                      if (!value.contains('@')) {
                        return context.l10n.pleaseEnterAValidEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    autofillHints: const [AutofillHints.password],
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: context.l10n.password,
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? context.l10n.showPassword
                            : context.l10n.hidePassword,
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.l10n.pleaseEnterYourPassword;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      if (auth.isLoading) {
                        return const SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(context.l10n.login),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_allowPublic)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: Text(context.l10n.createAccount),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.forgotPassword),
                    child: Text(context.l10n.forgotPassword),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const RegisterScreen(invitationOnly: true),
                      ),
                    ),
                    child: Text(context.l10n.joinWithInvitation),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
