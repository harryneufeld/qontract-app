import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/app_notification.dart';
import '../../services/api_service.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_toast.dart';
import 'notification_text.dart';

/// Defaults of the backend rule engine; used when a workspace sets nothing.
const _defaultLeadDays = <String, List<int>>{
  NotificationKind.noticeDeadline: [30, 14, 3],
  NotificationKind.endDate: [30, 7],
  NotificationKind.minimumTerm: [30],
};
const _defaultEnabled = <String, bool>{NotificationKind.missingData: false};

/// Which checks run for a workspace (administrators only). Stored as the
/// `notifications` object inside the tenant settings JSON.
class WorkspaceNotificationSettingsScreen extends StatefulWidget {
  const WorkspaceNotificationSettingsScreen(
      {super.key, required this.tenantId, this.api});

  final int tenantId;
  final ApiService? api;

  @override
  State<WorkspaceNotificationSettingsScreen> createState() =>
      _WorkspaceNotificationSettingsScreenState();
}

class _WorkspaceNotificationSettingsScreenState
    extends State<WorkspaceNotificationSettingsScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  Map<String, dynamic> _tenantSettings = {};
  final _timeZone = TextEditingController(text: 'Europe/Berlin');
  final _leadDays = <String, TextEditingController>{};
  final _minPercent = TextEditingController(text: '5');
  final _afterMonths = TextEditingController(text: '12');
  final _enabled = <String, bool>{};
  bool _unassignedToAdmins = true;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final kind in NotificationKind.values) {
      _enabled[kind] = _defaultEnabled[kind] ?? true;
    }
    for (final entry in _defaultLeadDays.entries) {
      _leadDays[entry.key] =
          TextEditingController(text: entry.value.join(', '));
    }
    _load();
  }

  @override
  void dispose() {
    _timeZone.dispose();
    _minPercent.dispose();
    _afterMonths.dispose();
    for (final c in _leadDays.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final details = await _api.getTenantDetails(widget.tenantId);
      final raw = details['settings'] as String?;
      final settings = raw == null || raw.trim().isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final node = settings['notifications'];
      if (node is Map) _apply(Map<String, dynamic>.from(node));
      if (mounted) {
        setState(() {
          _tenantSettings = settings;
          _loaded = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _apply(Map<String, dynamic> node) {
    if (node['timeZone'] is String) _timeZone.text = node['timeZone'] as String;
    _unassignedToAdmins = node['unassignedGoTo'] != 'nobody';
    final rules = node['rules'];
    if (rules is! Map) return;
    for (final kind in NotificationKind.values) {
      final rule = rules[kind];
      if (rule is! Map) continue;
      if (rule['enabled'] is bool) _enabled[kind] = rule['enabled'] as bool;
      if (rule['leadDays'] is List && _leadDays.containsKey(kind)) {
        _leadDays[kind]!.text = (rule['leadDays'] as List).join(', ');
      }
      if (kind == NotificationKind.priceIncrease &&
          rule['minPercent'] != null) {
        _minPercent.text = '${rule['minPercent']}';
      }
      if (kind == NotificationKind.insuranceReview &&
          rule['afterMonths'] != null) {
        _afterMonths.text = '${rule['afterMonths']}';
      }
    }
  }

  List<int>? _parseLeadDays(String text) {
    final days = text
        .split(RegExp(r'[,\s]+'))
        .where((s) => s.isNotEmpty)
        .map(int.tryParse)
        .toList();
    if (days.isEmpty ||
        days.length > 6 ||
        days.any((d) => d == null || d < 1 || d > 365)) {
      return null;
    }
    return days.cast<int>();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final rules = <String, dynamic>{};
    for (final kind in NotificationKind.values) {
      final rule = <String, dynamic>{'enabled': _enabled[kind]};
      if (_leadDays.containsKey(kind)) {
        final days = _parseLeadDays(_leadDays[kind]!.text);
        if (days == null) {
          showToast(context,
              l.ntfWsLeadDaysInvalid(notificationKindLabel(kind, l10n: l)),
              style: ToastStyle.error);
          return;
        }
        rule['leadDays'] = days;
      }
      if (kind == NotificationKind.priceIncrease) {
        final percent =
            num.tryParse(_minPercent.text.trim().replaceAll(',', '.'));
        if (percent == null || percent < 0 || percent > 1000) {
          showToast(context, l.ntfWsPercentInvalid, style: ToastStyle.error);
          return;
        }
        rule['minPercent'] = percent;
      }
      if (kind == NotificationKind.insuranceReview) {
        final months = int.tryParse(_afterMonths.text.trim());
        if (months == null || months < 1 || months > 120) {
          showToast(context, l.ntfWsMonthsInvalid, style: ToastStyle.error);
          return;
        }
        rule['afterMonths'] = months;
      }
      rules[kind] = rule;
    }
    setState(() => _saving = true);
    try {
      await _api.updateTenantSettings(
          widget.tenantId,
          jsonEncode({
            ..._tenantSettings,
            'notifications': {
              'timeZone': _timeZone.text.trim(),
              'unassignedGoTo': _unassignedToAdmins ? 'admins' : 'nobody',
              'rules': rules,
            },
          }));
      if (!mounted) return;
      showToast(context, l.ntfSaved);
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, style: ToastStyle.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.ntfWsTitle)),
      body: !_loaded
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!))
          : AppPageListView(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  key: const Key('notificationTimeZone'),
                  controller: _timeZone,
                  decoration: InputDecoration(
                      labelText: l.ntfWsTimeZone,
                      helperText: 'Europe/Berlin',
                      border: const OutlineInputBorder()),
                ),
              ),
              SwitchListTile(
                key: const Key('unassignedToAdmins'),
                title: Text(l.ntfWsUnassigned),
                value: _unassignedToAdmins,
                onChanged: (v) => setState(() => _unassignedToAdmins = v),
              ),
              const Divider(),
              for (final kind in NotificationKind.values) ...[
                SwitchListTile(
                  key: Key('rule_$kind'),
                  title: Text(notificationKindLabel(kind, l10n: l)),
                  value: _enabled[kind] ?? true,
                  onChanged: (v) => setState(() => _enabled[kind] = v),
                ),
                if (_leadDays.containsKey(kind) && (_enabled[kind] ?? true))
                  _field('leadDays_$kind', _leadDays[kind]!, l.ntfWsLeadDays),
                if (kind == NotificationKind.priceIncrease &&
                    (_enabled[kind] ?? true))
                  _field('minPercent', _minPercent, l.ntfWsMinPercent),
                if (kind == NotificationKind.insuranceReview &&
                    (_enabled[kind] ?? true))
                  _field('afterMonths', _afterMonths, l.ntfWsAfterMonths),
              ],
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                    key: const Key('saveNotificationSettings'),
                    onPressed: _saving ? null : _save,
                    child: Text(l.save)),
              ),
            ]),
    );
  }

  Widget _field(String key, TextEditingController controller, String label) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
        child: TextField(
          key: Key(key),
          controller: controller,
          decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true),
        ),
      );
}
