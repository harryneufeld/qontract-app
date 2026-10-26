import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/session_info.dart';
import '../../services/api_service.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_toast.dart';

/// Devices signed in to this account, with the option to sign them out.
class SessionsScreen extends StatefulWidget {
  final ApiService? api;
  const SessionsScreen({super.key, this.api});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late final _api = widget.api ?? ApiService();
  List<SessionInfo>? _sessions;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final sessions = await _api.listSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.devicesSignOut)),
          ],
        ),
      ) ??
      false;

  Future<void> _run(Future<void> Function() action, String done) async {
    final failed = context.l10n.devicesActionFailed;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showToast(context, done, style: ToastStyle.success);
    } catch (_) {
      if (!mounted) return;
      showToast(context, failed, style: ToastStyle.error);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _revoke(SessionInfo session) async {
    final l10n = context.l10n;
    if (!await _confirm(l10n.devicesSignOutConfirmTitle,
        l10n.devicesSignOutConfirmBody(_name(session)))) {
      return;
    }
    await _run(() => _api.revokeSession(session.id), l10n.devicesSignedOut);
  }

  Future<void> _revokeOthers() async {
    final l10n = context.l10n;
    if (!await _confirm(
        l10n.devicesSignOutOthers, l10n.devicesSignOutOthersConfirmBody)) {
      return;
    }
    await _run(_api.revokeOtherSessions, l10n.devicesOthersSignedOut);
  }

  String _name(SessionInfo session) =>
      (session.deviceName?.isNotEmpty ?? false)
          ? session.deviceName!
          : context.l10n.devicesUnknownName;

  String _when(DateTime value) {
    final local = value.toLocal();
    final time = TimeOfDay.fromDateTime(local).format(context);
    return '${S.date(local)} $time';
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions ?? const <SessionInfo>[];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.devicesTitle)),
      body: AppPageListView(
        padding: const EdgeInsets.all(AppSpace.group),
        children: [
          Text(context.l10n.devicesDescription,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpace.group),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_failed)
            AppPanel(
                child: Column(children: [
              Text(context.l10n.devicesLoadFailed),
              const SizedBox(height: AppSpace.control),
              OutlinedButton(
                  onPressed: _load, child: Text(context.l10n.retry)),
            ]))
          else ...[
            AppCollection(compact: true, children: [
              for (final session in sessions)
                ListTile(
                  key: Key('session-${session.id}'),
                  leading: Icon(session.clientType == 'web'
                      ? Icons.language
                      : Icons.smartphone_outlined),
                  title: Text(session.current
                      ? '${_name(session)} · ${context.l10n.devicesThisDevice}'
                      : _name(session)),
                  subtitle: Text(
                      '${session.clientType == 'web' ? context.l10n.devicesKindWeb : context.l10n.devicesKindMobile}'
                      ' · ${context.l10n.devicesLastActive(_when(session.lastUsedAt))}'),
                  trailing: session.current
                      ? null
                      : IconButton(
                          tooltip: context.l10n.devicesSignOut,
                          icon: const Icon(Icons.logout),
                          onPressed: _busy ? null : () => _revoke(session),
                        ),
                ),
            ]),
            if (sessions.any((s) => !s.current)) ...[
              const SizedBox(height: AppSpace.section),
              OutlinedButton.icon(
                key: const Key('signOutOthersButton'),
                onPressed: _busy ? null : _revokeOthers,
                icon: const Icon(Icons.devices_other_outlined),
                label: Text(context.l10n.devicesSignOutOthers),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
