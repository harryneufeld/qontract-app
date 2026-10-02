import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';

class TenantsScreen extends StatefulWidget {
  final ApiService? api;
  const TenantsScreen({super.key, this.api});
  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invitations = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _code = TextEditingController();
  int get _tenantId => context.read<AuthProvider>().user!.tenantId;
  bool get _admin {
    final current =
        _tenants.where((t) => t['tenantId'] == _tenantId).firstOrNull;
    return (current?['role'] ?? context.read<AuthProvider>().user?.role) ==
        'TenantAdmin';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final tenantId = _tenantId;
    try {
      final tenants = await _api.getMemberships();
      final admin = tenants
              .where((t) => t['tenantId'] == tenantId)
              .firstOrNull?['role'] ==
          'TenantAdmin';
      final members = admin
          ? await _api.getTenantMembers(tenantId)
          : <Map<String, dynamic>>[];
      final invitations = admin
          ? await _api.getTenantInvitations(tenantId)
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _tenants = tenants;
          _members = members;
          _invitations = invitations;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, style: ToastStyle.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _session(Future<bool> Function(AuthProvider) action) async {
    if (_busy) return;
    final auth = context.read<AuthProvider>();
    setState(() => _busy = true);
    final ok = await action(auth);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
    } else {
      showToast(context, auth.errorMessage ?? 'Could not change tenant.',
          style: ToastStyle.error);
    }
  }

  Future<String?> _textDialog(String title, String label,
      {String initial = '', bool optional = false}) async {
    return showDialog<String>(
        context: context,
        builder: (_) => _TenantTextDialog(
            title: title, label: label, initial: initial, optional: optional));
  }

  Future<void> _invite() async {
    final email =
        await _textDialog('Invite member', 'Email (optional)', optional: true);
    if (email == null || !mounted) return;
    await _perform(() async {
      final invitation = await _api.inviteMember(_tenantId, email: email);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
                title: const Text('Invitation created'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Share this code with the invited person. It is valid for 7 days and can be used once. Copy it now; it will not be shown again.'),
                      const SizedBox(height: 16),
                      SelectableText(invitation['code'] as String),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: invitation['code'] as String));
                        if (dialog.mounted) Navigator.pop(dialog);
                      },
                      child: const Text('Copy code')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Done'))
                ],
              ));
    });
  }

  Future<void> _remove(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: const Text('Remove member'),
              content: Text(
                  'Remove ${member['name']} from this tenant? Their account and other memberships will remain.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Remove'))
              ],
            ));
    if (confirmed == true && mounted) {
      await _perform(
          () => _api.removeMember(_tenantId, (member['id'] as num).toInt()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }
    final current =
        _tenants.where((t) => t['tenantId'] == user.tenantId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Tenants')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) ...[
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      TextButton(onPressed: _load, child: const Text('Retry'))
                    ],
                    Text('Your tenants',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (_tenants.isNotEmpty)
                      DropdownButtonFormField<int>(
                          key: const Key('tenantSwitcher'),
                          initialValue: user.tenantId,
                          decoration: const InputDecoration(
                              labelText: 'Current tenant'),
                          items: _tenants
                              .map((t) => DropdownMenuItem(
                                  value: (t['tenantId'] as num).toInt(),
                                  child: Text(t['name'] as String)))
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (id) {
                                  if (id != null && id != user.tenantId) {
                                    _session((auth) => auth.switchTenant(id));
                                  }
                                }),
                    const SizedBox(height: 20),
                    Text('Join another tenant',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextField(
                        key: const Key('joinCode'),
                        controller: _code,
                        decoration: const InputDecoration(
                            labelText: 'Invitation code')),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    if (_code.text.trim().length != 64) {
                                      showToast(context,
                                          'Paste the complete invitation code.',
                                          style: ToastStyle.error);
                                      return;
                                    }
                                    _session((auth) =>
                                        auth.redeemInvitation(_code.text));
                                  },
                            child: const Text('Accept invitation'))),
                    if (_admin) ...[
                      const Divider(height: 36),
                      Text('Tenant settings',
                          style: Theme.of(context).textTheme.titleLarge),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              current?['name'] as String? ?? 'Current tenant'),
                          trailing: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final name = await _textDialog(
                                          'Rename tenant', 'Name',
                                          initial:
                                              current?['name'] as String? ??
                                                  '');
                                      if (name != null && mounted) {
                                        _perform(() =>
                                            _api.renameTenant(_tenantId, name));
                                      }
                                    },
                              child: const Text('Rename'))),
                      TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final name = await _textDialog(
                                      'Create another tenant', 'Tenant name');
                                  if (name == null || !context.mounted) return;
                                  final auth = context.read<AuthProvider>();
                                  await _perform(() async {
                                    final tenant =
                                        await _api.createTenant(name, 'Family');
                                    final ok = await auth.switchTenant(
                                        (tenant['id'] as num).toInt());
                                    if (!ok && context.mounted) {
                                      showToast(
                                          context,
                                          auth.errorMessage ??
                                              'Could not switch tenant.',
                                          style: ToastStyle.error);
                                    }
                                  });
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('Create another tenant')),
                      const Divider(height: 32),
                      Row(children: [
                        Expanded(
                            child: Text('Members',
                                style: Theme.of(context).textTheme.titleLarge)),
                        FilledButton.icon(
                            onPressed: _busy ? null : _invite,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Invite'))
                      ]),
                      for (final member in _members)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(member['name'] as String),
                            subtitle: Text(
                                '${member['email']} · ${member['role']}${member['isActive'] == true ? '' : ' · Inactive'}'),
                            trailing: PopupMenuButton<String>(
                                enabled: !_busy,
                                onSelected: (value) {
                                  if (value == 'remove') {
                                    _remove(member);
                                  } else {
                                    _perform(() => _api.updateMember(_tenantId,
                                        (member['id'] as num).toInt(),
                                        role:
                                            value == 'activate' ? null : value,
                                        isActive:
                                            value == 'activate' ? true : null));
                                  }
                                },
                                itemBuilder: (_) => [
                                      if (member['isActive'] != true)
                                        const PopupMenuItem(
                                            value: 'activate',
                                            child:
                                                Text('Reactivate membership')),
                                      const PopupMenuItem(
                                          value: 'TenantAdmin',
                                          child: Text('Make administrator')),
                                      const PopupMenuItem(
                                          value: 'User',
                                          child: Text('Make member')),
                                      const PopupMenuItem(
                                          value: 'Contractor',
                                          child: Text('Make contractor')),
                                      if (member['isActive'] == true)
                                        const PopupMenuItem(
                                            value: 'remove',
                                            child: Text('Remove membership')),
                                    ])),
                      const Divider(height: 32),
                      Text('Invitations',
                          style: Theme.of(context).textTheme.titleLarge),
                      if (_invitations.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('No invitations yet.')),
                      for (final invitation in _invitations)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(invitation['email'] as String? ??
                                'Invitation code'),
                            subtitle: Text(invitation['redeemedAt'] != null
                                ? 'Accepted'
                                : invitation['revokedAt'] != null
                                    ? 'Revoked'
                                    : DateTime.parse(invitation['expiresAt']
                                                as String)
                                            .isBefore(DateTime.now())
                                        ? 'Expired'
                                        : 'Pending'),
                            trailing: invitation['redeemedAt'] == null &&
                                    invitation['revokedAt'] == null
                                ? TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _perform(() =>
                                            _api.revokeInvitation(_tenantId,
                                                invitation['id'] as String)),
                                    child: const Text('Revoke'))
                                : null),
                    ],
                    if (_busy) const LinearProgressIndicator(),
                  ])),
    );
  }
}

class _TenantTextDialog extends StatefulWidget {
  final String title, label, initial;
  final bool optional;
  const _TenantTextDialog(
      {required this.title,
      required this.label,
      required this.initial,
      required this.optional});
  @override
  State<_TenantTextDialog> createState() => _TenantTextDialogState();
}

class _TenantTextDialogState extends State<_TenantTextDialog> {
  late final _input = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Form(
            key: _form,
            child: TextFormField(
                controller: _input,
                autofocus: true,
                decoration: InputDecoration(labelText: widget.label),
                maxLength: 100,
                validator: (value) =>
                    !widget.optional && (value?.trim().isEmpty ?? true)
                        ? 'Enter a value.'
                        : null)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _input.text.trim());
                }
              },
              child: const Text('Continue'))
        ],
      );
}
