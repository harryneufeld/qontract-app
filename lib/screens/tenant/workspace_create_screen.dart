import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/currency.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/currency_field.dart';

/// Creates a workspace for the signed-in user, who becomes its administrator,
/// and switches into it.
class WorkspaceCreateScreen extends StatefulWidget {
  final ApiService? api;
  const WorkspaceCreateScreen({super.key, this.api});

  @override
  State<WorkspaceCreateScreen> createState() => _WorkspaceCreateScreenState();
}

class _WorkspaceCreateScreenState extends State<WorkspaceCreateScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _type = 'Family';
  late String _currency;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currency = context.read<AuthProvider>().user?.defaultCurrency ??
        defaultCurrencyForCountry(
            WidgetsBinding.instance.platformDispatcher.locale.countryCode);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy || !_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() => _busy = true);
    try {
      final tenant = await _api.createTenant(_name.text.trim(), _type,
          settings: jsonEncode({'defaultCurrency': _currency}));
      final ok = await auth.switchTenant((tenant['id'] as num).toInt());
      if (!mounted) return;
      if (ok) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.dashboard, (_) => false);
        return;
      }
      showToast(context, auth.errorMessage ?? context.l10n.couldNotSwitchTenant,
          style: ToastStyle.error);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, style: ToastStyle.error);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.newWorkspace)),
        body: AppPageListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppPageHeading(
              eyebrow: context.l10n.contractWorkspaces,
              title: context.l10n.createWorkspaceTitle,
              description: context.l10n.createWorkspaceIntro,
            ),
            const SizedBox(height: AppSpace.section),
            Form(
              key: _form,
              child: AppFormColumn(children: [
                TextFormField(
                  key: const Key('createTenantName'),
                  controller: _name,
                  autofocus: true,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      InputDecoration(labelText: context.l10n.tenantName),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? context.l10n.enterATenantName
                      : null,
                ),
                AppDropdown<String>(
                  key: const Key('createTenantType'),
                  initialValue: _type,
                  decoration:
                      InputDecoration(labelText: context.l10n.tenantType),
                  items: [
                    DropdownMenuItem(
                        value: 'Family', child: Text(context.l10n.standard)),
                    DropdownMenuItem(
                        value: 'Company', child: Text(context.l10n.company)),
                  ],
                  onChanged:
                      _busy ? null : (value) => setState(() => _type = value!),
                ),
                CurrencyField(
                  key: const Key('createTenantCurrency'),
                  label: context.l10n.defaultCurrency,
                  value: _currency,
                  enabled: !_busy,
                  onChanged: (value) => setState(() => _currency = value),
                ),
                FilledButton(
                  key: const Key('createTenantSubmit'),
                  onPressed: _busy ? null : _create,
                  child: Text(context.l10n.createWorkspace),
                ),
                if (_busy) const LinearProgressIndicator(),
              ]),
            ),
          ],
        ),
      );
}
