import '../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import 'app_toast.dart';

bool _showing = false;

/// Asks a signed-in user to accept changed terms of use. The only ways out
/// are accepting or signing out; a failed request keeps the dialog open.
Future<void> promptPendingTerms(BuildContext context) async {
  if (_showing || context.read<AuthProvider>().pendingTerms == null) return;
  _showing = true;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TermsDialog(),
    );
  } finally {
    _showing = false;
  }
}

class _TermsDialog extends StatefulWidget {
  const _TermsDialog();

  @override
  State<_TermsDialog> createState() => _TermsDialogState();
}

class _TermsDialogState extends State<_TermsDialog> {
  bool _busy = false;

  Future<void> _open(String? url) async {
    final uri = Uri.tryParse(url ?? '');
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (mounted) {
      showToast(context, context.l10n.couldNotOpenTermsOfUse,
          style: ToastStyle.error);
    }
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.acceptPendingTerms();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      showToast(
          context,
          auth.errorMessage ??
              context.l10n.unableToCompleteThisRequestPleaseTryAgain,
          style: ToastStyle.error);
    }
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().logout();
    navigator.pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final terms = context.watch<AuthProvider>().pendingTerms;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('termsPrompt'),
        title: Text(context.l10n.updatedTermsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.updatedTermsBody),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _open(terms?.url),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(context.l10n.readTermsOfUse),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _logout,
            child: Text(context.l10n.logout),
          ),
          FilledButton(
            key: const Key('acceptTerms'),
            onPressed: _busy ? null : _accept,
            child: Text(context.l10n.accept),
          ),
        ],
      ),
    );
  }
}
