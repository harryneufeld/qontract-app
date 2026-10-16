import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_routes.dart';
import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_design.dart';

class TwoFactorScreen extends StatefulWidget {
  final ApiService? api;
  const TwoFactorScreen({super.key, this.api});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  late final _api = widget.api ?? ApiService();
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _code = TextEditingController();
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _setup;
  List<String>? _recoveryCodes;
  bool _busy = false;
  bool _recovery = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await _api.twoFactorStatus();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.twoFactorError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final action = _status?['enabled'] == true
        ? 'disable'
        : _setup == null
            ? 'setup'
            : 'enable';
    try {
      final result = await _api.manageTwoFactor(action, _password.text,
          code: _code.text, recovery: _recovery);
      if (!mounted) return;
      if (action == 'setup') {
        setState(() => _setup = result);
      } else {
        _password.clear();
        _code.clear();
        if (action == 'enable') {
          // Keep the codes visible until acknowledged. No more API requests use
          // the revoked session; the session gate is cleared on acknowledgement.
          setState(() {
            _setup = null;
            _recoveryCodes = List<String>.from(result['recoveryCodes'] as List);
          });
          await _api.clearToken();
        } else {
          await auth.clearRevokedSession();
          if (mounted) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.twoFactorActionError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<AuthProvider>().clearRevokedSession();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _status?['enabled'] == true;
    final codes = _recoveryCodes;
    return PopScope(
      canPop: !_busy && codes == null,
      child: Scaffold(
        appBar: AppBar(
            title: Text(context.l10n.twoFactorTitle),
            automaticallyImplyLeading: codes == null),
        body: AppPageListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Semantics(
                    liveRegion: true,
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              ),
            if (codes != null) ...[
              Text(context.l10n.twoFactorRecoveryTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(context.l10n.twoFactorRecoveryHelp),
              const SizedBox(height: 16),
              SelectableText(codes.join('\n'),
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 16, height: 1.8)),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _busy ? null : _finish,
                  child: Text(context.l10n.twoFactorSaved)),
            ] else if (_status == null && !_busy) ...[
              FilledButton(onPressed: _load, child: Text(context.l10n.retry)),
            ] else if (_status != null) ...[
              Text(
                  enabled
                      ? context.l10n.twoFactorEnabled
                      : context.l10n.twoFactorDisabled,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(enabled
                  ? context.l10n.twoFactorDisableHelp
                  : context.l10n.twoFactorDescription),
              if (enabled)
                Text(context.l10n.twoFactorRemaining(
                    _status!['recoveryCodesRemaining'] as int)),
              const SizedBox(height: 24),
              Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _password,
                          enabled: !_busy,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                              labelText: context.l10n.currentPassword),
                          validator: (v) => v == null || v.isEmpty
                              ? context.l10n.pleaseEnterYourPassword
                              : null,
                        ),
                        if (_setup != null) ...[
                          const SizedBox(height: 24),
                          Text(context.l10n.twoFactorSetupHelp),
                          const SizedBox(height: 16),
                          Text(context.l10n.twoFactorKey,
                              style: Theme.of(context).textTheme.titleSmall),
                          SelectableText(_setup!['secret'] as String,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 18)),
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    await Clipboard.setData(ClipboardData(
                                        text: _setup!['secret'] as String));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(context
                                                  .l10n.twoFactorKeyCopied)));
                                    }
                                  },
                            icon: const Icon(Icons.copy_outlined),
                            label: Text(context.l10n.twoFactorCopyKey),
                          ),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      try {
                                        if (!await launchUrl(Uri.parse(
                                                _setup!['authenticatorUri']
                                                    as String)) &&
                                            mounted) {
                                          setState(() => _error =
                                              context.l10n.twoFactorManualKey);
                                        }
                                      } catch (_) {
                                        if (mounted) {
                                          setState(() => _error =
                                              context.l10n.twoFactorManualKey);
                                        }
                                      }
                                    },
                              child: Text(context.l10n.twoFactorOpenApp)),
                        ],
                        if (enabled || _setup != null) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _code,
                            enabled: !_busy,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            keyboardType: _recovery
                                ? TextInputType.text
                                : TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                                labelText: _recovery
                                    ? context.l10n.twoFactorRecoveryCode
                                    : context.l10n.twoFactorCode),
                            validator: (v) => v == null ||
                                    (_recovery
                                        ? v.trim().isEmpty
                                        : !RegExp(r'^\d{6}$')
                                            .hasMatch(v.trim()))
                                ? context.l10n.twoFactorInvalidCode
                                : null,
                          ),
                          if (enabled)
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                          _recovery = !_recovery;
                                          _code.clear();
                                        }),
                                child: Text(_recovery
                                    ? context.l10n.twoFactorUseAuthenticator
                                    : context.l10n.twoFactorUseRecovery)),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: Text(enabled
                                ? context.l10n.twoFactorDeactivate
                                : _setup == null
                                    ? context.l10n.twoFactorSetup
                                    : context.l10n.twoFactorActivate)),
                      ])),
            ],
          ],
        ),
      ),
    );
  }
}
