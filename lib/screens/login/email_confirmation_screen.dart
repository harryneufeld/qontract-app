import 'dart:async';

import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/legal_footer.dart';

/// Shown after signup when the server activates accounts only after the
/// address is confirmed: the user types the emailed 6-digit code (or taps the
/// link in the same email) and is signed in straight away.
class EmailConfirmationSentScreen extends StatefulWidget {
  final String email;
  const EmailConfirmationSentScreen({super.key, required this.email});

  @override
  State<EmailConfirmationSentScreen> createState() =>
      _EmailConfirmationSentScreenState();
}

class _EmailConfirmationSentScreenState
    extends State<EmailConfirmationSentScreen> {
  static const _resendCooldown = 60;
  final _code = TextEditingController();
  Timer? _timer;
  int _cooldown = _resendCooldown;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _cooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      setState(() => _cooldown--);
    });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading || _code.text.length != 6) return;
    setState(() => _error = null);
    final ok = await auth.confirmEmailCode(widget.email, _code.text);
    // On success the session change rebuilds the app into the first-run setup.
    if (ok || !mounted) return;
    setState(() {
      _error = auth.errorMessage ?? context.l10n.codeInvalidOrExpired;
      _code.clear();
    });
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.resendEmailConfirmation(widget.email);
    if (!mounted) return;
    setState(() => _resending = false);
    if (ok) _startCooldown();
    showToast(
      context,
      ok
          ? context.l10n.confirmationEmailResent
          : auth.errorMessage ??
              context.l10n.unableToCompleteThisRequestPleaseTryAgain,
      style: ok ? ToastStyle.success : ToastStyle.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      appBar: AppBar(
        actions: const [LanguagePicker(compact: true)],
        title: Text(context.l10n.checkYourInbox),
      ),
      body: SafeArea(
        top: false,
        child: LegalFooterLayout(
          maxWidth: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 48),
              const SizedBox(height: 24),
              Text(context.l10n.codeSentTo(widget.email)),
              const SizedBox(height: 24),
              TextField(
                key: const Key('confirmationCode'),
                controller: _code,
                enabled: !busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(letterSpacing: 8),
                decoration: InputDecoration(
                  labelText: context.l10n.confirmationCode,
                  errorText: _error,
                  counterText: '',
                ),
                onChanged: (value) {
                  if (_error != null) setState(() => _error = null);
                  if (value.length == 6) _submit();
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('confirmCode'),
                onPressed: busy ? null : _submit,
                child: Text(context.l10n.confirmCodeAction),
              ),
              TextButton(
                key: const Key('resendConfirmation'),
                onPressed: _resending || _cooldown > 0 ? null : _resend,
                child: Text(_cooldown > 0
                    ? context.l10n.sendNewCodeIn(_cooldown)
                    : context.l10n.sendNewCode),
              ),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false),
                child: Text(context.l10n.backToLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opened from the emailed link; confirms the address once and signs the user
/// in. Servers that only confirm the address fall back to a sign-in prompt.
class ConfirmEmailScreen extends StatefulWidget {
  final String? token;
  final String? language;
  final ApiService? api;
  const ConfirmEmailScreen({super.key, this.token, this.language, this.api});

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  bool? _confirmed;

  bool get _validLink =>
      widget.token != null && RegExp(r'^[0-9A-F]{64}$').hasMatch(widget.token!);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.language != null) {
        Provider.of<LocaleProvider?>(context, listen: false)
            ?.useLinkLanguage(widget.language);
      }
      _confirm();
    });
  }

  Future<void> _confirm() async {
    if (!_validLink) {
      setState(() => _confirmed = false);
      return;
    }
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    try {
      if (auth == null || widget.api != null) {
        await _api.confirmEmail(widget.token!);
        if (mounted) setState(() => _confirmed = true);
        return;
      }
      // A session change rebuilds the whole app, which would re-open this link
      // from the initial route, so the token is retired before it is used.
      AppRoutes.retireLink(widget.token!);
      final outcome = await auth.confirmEmailLink(widget.token!);
      if (mounted) {
        setState(() => _confirmed = outcome != LinkConfirmation.failed);
      }
    } catch (_) {
      if (mounted) setState(() => _confirmed = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          actions: const [LanguagePicker(compact: true)],
          title: Text(context.l10n.confirmEmailTitle),
        ),
        body: SafeArea(
          top: false,
          child: LegalFooterLayout(
            maxWidth: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _confirmed == false
                      ? Icons.link_off_outlined
                      : Icons.mark_email_read_outlined,
                  size: 48,
                ),
                const SizedBox(height: 24),
                if (_confirmed == null) ...[
                  Text(context.l10n.confirmingEmail),
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ] else ...[
                  Text(
                    _confirmed!
                        ? context.l10n.emailConfirmed
                        : context.l10n.emailConfirmationFailed,
                    key: const Key('confirmEmailResult'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false),
                    child: Text(context.l10n.backToLogin),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}
