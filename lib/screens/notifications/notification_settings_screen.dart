import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/app_notification.dart';
import '../../services/api_service.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_toast.dart';
import 'notification_text.dart';

/// Personal notification preferences: which kinds to see and the digest mail.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key, this.api});

  final ApiService? api;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  NotificationPreferences? _prefs;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await _api.getNotificationPreferences();
      if (mounted) setState(() => _prefs = prefs);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save(NotificationPreferences next) async {
    final previous = _prefs;
    setState(() {
      _prefs = next;
      _saving = true;
    });
    try {
      final saved = await _api.saveNotificationPreferences(next);
      if (mounted) setState(() => _prefs = saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      showToast(context, e.message, style: ToastStyle.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final prefs = _prefs;
    return Scaffold(
      appBar: AppBar(title: Text(l.ntfPrefsTitle)),
      body: prefs == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!))
          : AppPageListView(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(l.ntfPrefsIntro,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              for (final kind in NotificationKind.values)
                SwitchListTile(
                  key: Key('kind_$kind'),
                  title: Text(notificationKindLabel(kind, l10n: l)),
                  value: !prefs.mutedKinds.contains(kind),
                  onChanged: _saving
                      ? null
                      : (on) => _save(NotificationPreferences(
                              digest: prefs.digest,
                              mutedKinds: {
                                ...prefs.mutedKinds.where((k) => k != kind),
                                if (!on) kind,
                              })),
                ),
              const Divider(),
              ListTile(
                title: Text(l.ntfDigestTitle),
                subtitle: Text(l.ntfDigestSubtitle),
                trailing: DropdownButton<String>(
                  key: const Key('digestSelector'),
                  value: prefs.digest,
                  onChanged: _saving
                      ? null
                      : (value) => _save(NotificationPreferences(
                          digest: value ?? 'Off',
                          mutedKinds: prefs.mutedKinds)),
                  items: [
                    DropdownMenuItem(value: 'Off', child: Text(l.ntfDigestOff)),
                    DropdownMenuItem(value: 'Daily', child: Text(l.daily)),
                    DropdownMenuItem(value: 'Weekly', child: Text(l.weekly)),
                  ],
                ),
              ),
            ]),
    );
  }
}
