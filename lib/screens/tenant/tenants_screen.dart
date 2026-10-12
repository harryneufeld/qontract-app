import '../../providers/contract_provider.dart';
import 'dart:convert';
import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../address/address_book_screen.dart';

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
  Map<String, dynamic> _settings = {};
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
      final details = admin ? await _api.getTenantDetails(tenantId) : null;
      final rawSettings = details?['settings'] as String?;
      final settings = rawSettings == null || rawSettings.trim().isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(rawSettings) as Map);
      final members = admin
          ? await _api.getTenantMembers(tenantId)
          : <Map<String, dynamic>>[];
      final invitations = admin
          ? await _api.getTenantInvitations(tenantId)
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _tenants = tenants;
          _settings = settings;
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

  Future<void> _changeCurrency() async {
    final entered = await _textDialog(
        'Default currency', 'Three-letter currency code',
        initial: '${_settings['defaultCurrency'] ?? 'EUR'}');
    if (entered == null || !mounted) return;
    final currency = entered.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      showToast(context, 'Enter a three-letter currency code.',
          style: ToastStyle.error);
      return;
    }
    await _perform(() => _api.updateTenantSettings(
        _tenantId, jsonEncode({..._settings, 'defaultCurrency': currency})));
  }

  Future<void> _applyCurrency() async {
    var replaceExisting = false;
    final currency = '${_settings['defaultCurrency'] ?? 'EUR'}';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    title: Text('Apply $currency to contracts'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Updates currencies on existing contracts and their price history. Amounts stay unchanged; no currency conversion is performed. Contracts queued for deletion are excluded.'),
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Replace existing currencies too'),
                          value: replaceExisting,
                          onChanged: (value) =>
                              update(() => replaceExisting = value ?? false)),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(replaceExisting
                              ? 'Apply to all'
                              : 'Fill missing currencies')),
                    ])));
    if (confirmed != true || !mounted) return;
    await _perform(() async {
      final changed = await _api.applyTenantCurrency(_tenantId,
          replaceExisting: replaceExisting);
      if (!mounted) return;
      await context.read<ContractProvider>().refreshContracts();
      if (mounted) {
        showToast(context, 'Updated $changed contracts.',
            style: ToastStyle.success);
      }
    });
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
      showToast(context, auth.errorMessage ?? 'Could not change workspace.',
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
      appBar: AppBar(title: const Text('Workspaces')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: AppPageListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) ...[
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      TextButton(onPressed: _load, child: const Text('Retry'))
                    ],
                    const AppPageHeading(
                        eyebrow: 'Contract workspaces',
                        title: 'Your workspaces',
                        description:
                            'Keep contracts private in Personal, or share them with a tenant.'),
                    const SizedBox(height: AppSpace.section),
                    DropdownButtonFormField<int>(
                        isExpanded: true,
                        key: const Key('tenantSwitcher'),
                        initialValue: user.tenantId,
                        decoration: const InputDecoration(
                            labelText: 'Current workspace'),
                        items: [
                          const DropdownMenuItem<int>(
                              value: 0, child: Text('Personal')),
                          ..._tenants.map((t) => DropdownMenuItem(
                              value: (t['tenantId'] as num).toInt(),
                              child: Text(t['name'] as String))),
                        ],
                        onChanged: _busy
                            ? null
                            : (id) {
                                if (id != null && id != user.tenantId) {
                                  _session((auth) => auth.switchTenant(id));
                                }
                              }),
                    const SizedBox(height: AppSpace.group),
                    Text(user.isPersonal
                        ? 'Only you can access contracts, contractors and documents created here.'
                        : 'Contracts, contractors and contract documents created here are shared with tenant members.'),
                    const SizedBox(height: 20),
                    if (!user.isPersonal) ...[
                      Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                          builder: (_) => AddressBookScreen(
                                              entityType: 'Tenant',
                                              canEdit: _admin,
                                              api: _api))),
                              icon: const Icon(Icons.location_on_outlined),
                              label: const Text('Tenant addresses'))),
                      const SizedBox(height: AppSpace.section),
                    ],
                    Text('Join another tenant',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpace.group),
                    TextField(
                        key: const Key('joinCode'),
                        controller: _code,
                        decoration: const InputDecoration(
                            labelText: 'Invitation code')),
                    const SizedBox(height: AppSpace.group),
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
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Contract deletion retention'),
                          subtitle: Text(
                              '${_settings['contractRetentionDays'] ?? 90} days · changes apply to future deletions'),
                          trailing: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final entered = await _textDialog(
                                          'Contract deletion retention',
                                          'Days (1–3650)',
                                          initial:
                                              '${_settings['contractRetentionDays'] ?? 90}');
                                      if (entered == null || !context.mounted) {
                                        return;
                                      }
                                      final days = int.tryParse(entered.trim());
                                      if (days == null ||
                                          days < 1 ||
                                          days > 3650) {
                                        showToast(context,
                                            'Enter between 1 and 3650 days.',
                                            style: ToastStyle.error);
                                        return;
                                      }
                                      await _perform(() =>
                                          _api.updateTenantSettings(
                                              _tenantId,
                                              jsonEncode({
                                                ..._settings,
                                                'contractRetentionDays': days
                                              })));
                                    },
                              child: const Text('Change'))),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Default currency'),
                          subtitle: Text(
                              '${_settings['defaultCurrency'] ?? 'EUR'} · used for new tenant contracts'),
                          trailing: TextButton(
                              onPressed: _busy ? null : _changeCurrency,
                              child: const Text('Change'))),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                              onPressed: _busy ? null : _applyCurrency,
                              icon: const Icon(Icons.currency_exchange),
                              label:
                                  const Text('Apply currency to contracts'))),
                      TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final draft = await showDialog<
                                          ({String name, String type})>(
                                      context: context,
                                      builder: (_) =>
                                          const _CreateTenantDialog());
                                  if (draft == null || !context.mounted) return;
                                  final auth = context.read<AuthProvider>();
                                  await _perform(() async {
                                    final tenant = await _api.createTenant(
                                        draft.name, draft.type);
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
                      Wrap(
                          spacing: AppSpace.control,
                          runSpacing: AppSpace.control,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Members',
                                style: Theme.of(context).textTheme.titleLarge),
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

class _CreateTenantDialog extends StatefulWidget {
  const _CreateTenantDialog();

  @override
  State<_CreateTenantDialog> createState() => _CreateTenantDialogState();
}

class _CreateTenantDialogState extends State<_CreateTenantDialog> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _type = 'Family';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create another tenant'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: AppFormColumn(children: [
              TextFormField(
                key: const Key('createTenantName'),
                controller: _name,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Tenant name'),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Enter a tenant name.'
                    : null,
              ),
              DropdownButtonFormField<String>(
                key: const Key('createTenantType'),
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tenant type'),
                items: const [
                  DropdownMenuItem(value: 'Family', child: Text('Standard')),
                  DropdownMenuItem(value: 'Company', child: Text('Company')),
                ],
                onChanged: (value) => setState(() => _type = value!),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(
                      context, (name: _name.text.trim(), type: _type));
                }
              },
              child: const Text('Create tenant')),
        ],
      );
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
