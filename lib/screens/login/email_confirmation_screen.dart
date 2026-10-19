import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/language_picker.dart';
import '../../widgets/legal_footer.dart';

/// Shown after signup when the server activates accounts only by email link.
class EmailConfirmationSentScreen extends StatefulWidget {
  final String email;
  const EmailConfirmationSentScreen({super.key, required this.email});

  @override
  State<EmailConfirmationSentScreen> createState() =>
      _EmailConfirmationSentScreenState();
}

class _EmailConfirmationSentScreenState
    extends State<EmailConfirmationSentScreen> {
  bool _busy = false;

  Future<void> _resend() async {
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.resendEmailConfirmation(widget.email);
    if (!mounted) return;
    setState(() => _busy = false);
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
  Widget build(BuildContext context) => Scaffold(
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
                Text(context.l10n.confirmationSentTo(widget.email)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false),
                  child: Text(context.l10n.backToLogin),
                ),
                TextButton(
                  key: const Key('resendConfirmation'),
                  onPressed: _busy ? null : _resend,
                  child: Text(context.l10n.resendConfirmationEmail),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Opened from the emailed link; confirms the address once, then offers sign-in.
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
    try {
      await _api.confirmEmail(widget.token!);
      if (mounted) setState(() => _confirmed = true);
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
