import '../../l10n/strings.dart';
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
        context.l10n.defaultCurrency, context.l10n.threeLetterCurrencyCode,
        initial: '${_settings['defaultCurrency'] ?? 'EUR'}');
    if (entered == null || !mounted) return;
    final currency = entered.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      showToast(context, context.l10n.enterAThreeLetterCurrencyCode,
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
                    title: Text(context.l10n.applyToContracts((currency))),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(context.l10n
                          .updatesCurrenciesOnExistingContractsAndTheirPrice),
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title:
                              Text(context.l10n.replaceExistingCurrenciesToo),
                          value: replaceExisting,
                          onChanged: (value) =>
                              update(() => replaceExisting = value ?? false)),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(context.l10n.cancel)),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(replaceExisting
                              ? context.l10n.applyToAll
                              : context.l10n.fillMissingCurrencies)),
                    ])));
    if (confirmed != true || !mounted) return;
    await _perform(() async {
      final changed = await _api.applyTenantCurrency(_tenantId,
          replaceExisting: replaceExisting);
      if (!mounted) return;
      await context.read<ContractProvider>().refreshContracts();
      if (mounted) {
        showToast(context, context.l10n.updatedContracts((changed)),
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
      showToast(
          context, auth.errorMessage ?? context.l10n.couldNotChangeWorkspace,
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
    final email = await _textDialog(
        context.l10n.inviteMember, context.l10n.emailOptional,
        optional: true);
    if (email == null || !mounted) return;
    await _perform(() async {
      final invitation = await _api.inviteMember(_tenantId, email: email);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
                title: Text(context.l10n.invitationCreated),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.shareThisCodeWithTheInvitedPersonIt),
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
                      child: Text(context.l10n.copyCode)),
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: Text(context.l10n.done))
                ],
              ));
    });
  }

  Future<void> _remove(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: Text(context.l10n.removeMember),
              content: Text(context.l10n
                  .removeFromThisTenantTheirAccountAndOther((member['name']))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(context.l10n.cancel)),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(context.l10n.remove))
              ],
            ));
    if (confirmed == true && mounted) {
      await _perform(
          () => _api.removeMember(_tenantId, (member['id'] as num).toInt()));
    }
  }

  Widget _action(Widget child) => LayoutBuilder(
      builder: (context, constraints) => Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
              width: constraints.maxWidth < 600 ? double.infinity : null,
              child: child)));

  Widget _membersHeading() => LayoutBuilder(builder: (context, constraints) {
        final title = Text(context.l10n.members,
            style: Theme.of(context).textTheme.titleLarge);
        final invite = FilledButton.icon(
            onPressed: _busy ? null : _invite,
            icon: const Icon(Icons.person_add),
            label: Text(context.l10n.invite));
        if (constraints.maxWidth < 600) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: AppSpace.group),
                invite
              ]);
        }
        return Row(children: [Expanded(child: title), invite]);
      });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return Scaffold(
          body: Center(child: Text(context.l10n.pleaseSignInAgain)));
    }
    final current =
        _tenants.where((t) => t['tenantId'] == user.tenantId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.workspaces)),
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
                      TextButton(
                          onPressed: _load, child: Text(context.l10n.retry))
                    ],
                    AppPageHeading(
                        eyebrow: context.l10n.contractWorkspaces,
                        title: context.l10n.yourWorkspaces,
                        description: context
                            .l10n.keepContractsPrivateInPersonalOrShareThem),
                    const SizedBox(height: AppSpace.section),
                    DropdownButtonFormField<int>(
                        isExpanded: true,
                        key: const Key('tenantSwitcher'),
                        initialValue: user.tenantId,
                        decoration: InputDecoration(
                            labelText: context.l10n.currentWorkspace),
                        items: [
                          DropdownMenuItem<int>(
                              value: 0, child: Text(context.l10n.personal)),
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
                        ? context.l10n
                            .onlyYouCanAccessContractsContractorsAndDocuments
                        : context.l10n
                            .contractsContractorsAndContractDocumentsCreatedHereAre),
                    const SizedBox(height: AppSpace.group),
                    if (!user.isPersonal) ...[
                      _action(OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => AddressBookScreen(
                                          entityType: 'Tenant',
                                          canEdit: _admin,
                                          api: _api))),
                          icon: const Icon(Icons.location_on_outlined),
                          label: Text(context.l10n.tenantAddresses))),
                      const SizedBox(height: AppSpace.section),
                    ],
                    Text(context.l10n.joinAnotherTenant,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpace.group),
                    TextField(
                        key: const Key('joinCode'),
                        controller: _code,
                        decoration: InputDecoration(
                            labelText: context.l10n.invitationCode)),
                    const SizedBox(height: AppSpace.group),
                    _action(FilledButton(
                        onPressed: _busy
                            ? null
                            : () {
                                if (_code.text.trim().length != 64) {
                                  showToast(
                                      context,
                                      context
                                          .l10n.pasteTheCompleteInvitationCode,
                                      style: ToastStyle.error);
                                  return;
                                }
                                _session((auth) =>
                                    auth.redeemInvitation(_code.text));
                              },
                        child: Text(context.l10n.acceptInvitation))),
                    if (_admin) ...[
                      const Divider(height: 36),
                      Text(context.l10n.tenantSettings,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppSpace.group),
                      AppCollection(children: [
                        ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.group),
                            title: Text(current?['name'] as String? ??
                                context.l10n.currentTenant),
                            trailing: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        final name = await _textDialog(
                                            context.l10n.renameTenant,
                                            context.l10n.name,
                                            initial:
                                                current?['name'] as String? ??
                                                    '');
                                        if (name != null && mounted) {
                                          _perform(() => _api.renameTenant(
                                              _tenantId, name));
                                        }
                                      },
                                child: Text(context.l10n.rename))),
                        ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.group),
                            title: Text(context.l10n.contractDeletionRetention),
                            subtitle: Text(context.l10n
                                .daysChangesApplyToFutureDeletions(
                                    (_settings['contractRetentionDays'] ??
                                        90))),
                            trailing: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        final entered = await _textDialog(
                                            context
                                                .l10n.contractDeletionRetention,
                                            context.l10n.days13650,
                                            initial:
                                                '${_settings['contractRetentionDays'] ?? 90}');
                                        if (entered == null ||
                                            !context.mounted) {
                                          return;
                                        }
                                        final days =
                                            int.tryParse(entered.trim());
                                        if (days == null ||
                                            days < 1 ||
                                            days > 3650) {
                                          showToast(
                                              context,
                                              context.l10n
                                                  .enterBetween1And3650Days,
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
                                child: Text(context.l10n.change))),
                        ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.group),
                            title: Text(context.l10n.defaultCurrency),
                            subtitle: Text(context.l10n
                                .usedForNewTenantContracts(
                                    (_settings['defaultCurrency'] ?? 'EUR'))),
                            trailing: TextButton(
                                onPressed: _busy ? null : _changeCurrency,
                                child: Text(context.l10n.change))),
                      ]),
                      const SizedBox(height: AppSpace.group),
                      _action(OutlinedButton.icon(
                          onPressed: _busy ? null : _applyCurrency,
                          icon: const Icon(Icons.currency_exchange),
                          label: Text(context.l10n.applyCurrencyToContracts))),
                      const SizedBox(height: AppSpace.control),
                      _action(TextButton.icon(
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
                                              context.l10n.couldNotSwitchTenant,
                                          style: ToastStyle.error);
                                    }
                                  });
                                },
                          icon: const Icon(Icons.add),
                          label: Text(context.l10n.createAnotherTenant))),
                      const Divider(height: 32),
                      _membersHeading(),
                      const SizedBox(height: AppSpace.group),
                      AppCollection(children: [
                        for (final member in _members)
                          ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.group),
                              title: Text(member['name'] as String),
                              subtitle: Text(
                                  '${member['email']} · ${S.role(member['role'] as String?)}${member['isActive'] == true ? '' : ' · ${context.l10n.inactive}'}'),
                              trailing: PopupMenuButton<String>(
                                  enabled: !_busy,
                                  onSelected: (value) {
                                    if (value == 'remove') {
                                      _remove(member);
                                    } else {
                                      _perform(() => _api.updateMember(
                                          _tenantId,
                                          (member['id'] as num).toInt(),
                                          role: value == 'activate'
                                              ? null
                                              : value,
                                          isActive: value == 'activate'
                                              ? true
                                              : null));
                                    }
                                  },
                                  itemBuilder: (_) => [
                                        if (member['isActive'] != true)
                                          PopupMenuItem(
                                              value: 'activate',
                                              child: Text(context
                                                  .l10n.reactivateMembership)),
                                        PopupMenuItem(
                                            value: 'TenantAdmin',
                                            child: Text(context
                                                .l10n.makeAdministrator)),
                                        PopupMenuItem(
                                            value: 'User',
                                            child:
                                                Text(context.l10n.makeMember)),
                                        PopupMenuItem(
                                            value: 'Contractor',
                                            child: Text(
                                                context.l10n.makeContractor)),
                                        if (member['isActive'] == true)
                                          PopupMenuItem(
                                              value: 'remove',
                                              child: Text(context
                                                  .l10n.removeMembership)),
                                      ]))
                      ]),
                      const Divider(height: 32),
                      Text(context.l10n.invitations,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppSpace.group),
                      if (_invitations.isEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(context.l10n.noInvitationsYet)),
                      AppCollection(children: [
                        for (final invitation in _invitations)
                          ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.group),
                              title: Text(invitation['email'] as String? ??
                                  context.l10n.invitationCode),
                              subtitle: Text(invitation['redeemedAt'] != null
                                  ? context.l10n.accepted
                                  : invitation['revokedAt'] != null
                                      ? context.l10n.revoked
                                      : DateTime.parse(invitation['expiresAt']
                                                  as String)
                                              .isBefore(DateTime.now())
                                          ? context.l10n.expired
                                          : context.l10n.pending),
                              trailing: invitation['redeemedAt'] == null &&
                                      invitation['revokedAt'] == null
                                  ? TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _perform(() =>
                                              _api.revokeInvitation(_tenantId,
                                                  invitation['id'] as String)),
                                      child: Text(context.l10n.revoke))
                                  : null)
                      ]),
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
        title: Text(context.l10n.createAnotherTenant),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: AppFormColumn(children: [
              TextFormField(
                key: const Key('createTenantName'),
                controller: _name,
                autofocus: true,
                maxLength: 100,
                decoration: InputDecoration(labelText: context.l10n.tenantName),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? context.l10n.enterATenantName
                    : null,
              ),
              DropdownButtonFormField<String>(
                key: const Key('createTenantType'),
                initialValue: _type,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.l10n.tenantType),
                items: [
                  DropdownMenuItem(
                      value: 'Family', child: Text(context.l10n.standard)),
                  DropdownMenuItem(
                      value: 'Company', child: Text(context.l10n.company)),
                ],
                onChanged: (value) => setState(() => _type = value!),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel)),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(
                      context, (name: _name.text.trim(), type: _type));
                }
              },
              child: Text(context.l10n.createTenant)),
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
                        ? context.l10n.enterAValue
                        : null)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel)),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _input.text.trim());
                }
              },
              child: Text(context.l10n.continueAction))
        ],
      );
}
