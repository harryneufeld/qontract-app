import '../../l10n/strings.dart';
import '../../widgets/contact_action.dart';
import '../../widgets/app_bottom_actions.dart';
import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/address.dart';
import '../../models/contractor.dart';
import '../../providers/contract_provider.dart';
import '../../providers/contractor_address_provider.dart';
import '../../providers/contractor_provider.dart';
import '../../app_routes.dart';
import '../../widgets/contract_list_item.dart';
import '../../widgets/app_toast.dart';
import 'address_editor_dialog.dart';

class ContractorDetailScreen extends StatelessWidget {
  const ContractorDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contractor =
        ModalRoute.of(context)?.settings.arguments as Contractor?;
    if (contractor == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.contractor)),
        body: Center(child: Text(context.l10n.noContractorSelected)),
      );
    }

    return _ContractorDetailView(contractor: contractor);
  }
}

class _ContractorDetailView extends StatefulWidget {
  final Contractor contractor;

  const _ContractorDetailView({required this.contractor});

  @override
  State<_ContractorDetailView> createState() => _ContractorDetailViewState();
}

class _ContractorDetailViewState extends State<_ContractorDetailView> {
  @override
  void initState() {
    super.initState();
    // Load this contractor's postal addresses (no-op if already loaded).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<ContractorAddressProvider>()
          .loadAddresses(widget.contractor.id);
    });
  }

  Future<void> _openEdit() async {
    final provider = context.read<ContractorProvider>();
    final fresh = provider.contractors
            .where((c) => c.id == widget.contractor.id)
            .firstOrNull ??
        widget.contractor;
    await Navigator.of(context).pushNamed(
      AppRoutes.contractorForm,
      arguments: fresh,
    );
  }

  Future<void> _openWebsite(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Report a failed platform launch while keeping the stored text visible.
    }
    if (!mounted) return;
    showToast(context, context.l10n.couldNotOpenWebsite,
        style: ToastStyle.error);
  }

  Widget _metadataSection(String title, String value) =>
      AppDetailSection(title: title, children: [SelectableText(value)]);

  Widget _group(String title, Widget child, {Widget? action}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Divider(height: 1),
        const SizedBox(height: AppSpace.section),
        Row(children: [
          Expanded(
              child: Semantics(
                  header: true,
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge))),
          if (action != null) action
        ]),
        const SizedBox(height: AppSpace.group),
        child,
      ]);

  Future<void> _activate() async {
    final provider = context.read<ContractorProvider>();
    final ok = await provider.activateContractor(widget.contractor);
    if (!mounted) return;
    showToast(
        context,
        ok
            ? context.l10n.contractorReactivated
            : (provider.errorMessage ?? context.l10n.reactivateFailed),
        style: ok ? ToastStyle.success : ToastStyle.error);
  }

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deactivateContractor),
        content: Text(
          context.l10n.deactivate((widget.contractor.name)) +
              context.l10n.itWillNoLongerBeSelectableOnNew +
              context.l10n.contractsThatReferenceItStayIntact,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.deactivate401),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<ContractorProvider>();
    final ok = await provider.deactivateContractor(widget.contractor);
    if (!mounted) return;
    showToast(
      context,
      ok
          ? context.l10n.deactivated((widget.contractor.name))
          : (provider.errorMessage ?? context.l10n.deactivateFailed),
      style: ok ? ToastStyle.success : ToastStyle.error,
    );
  }

  Future<void> _openAddressEditor(Address? address) async {
    final provider = context.read<ContractorAddressProvider>();
    final result = await showAddressEditorDialog(
      context,
      contractorId: widget.contractor.id,
      address: address,
    );
    if (result == null || !mounted) return; // cancelled

    if (address == null) {
      final created = await provider.createAddress(result);
      if (!mounted) return;
      showToast(
        context,
        created != null
            ? context.l10n.addressAdded
            : (provider.errorMessage ?? context.l10n.addAddressFailed),
        style: created != null ? ToastStyle.success : ToastStyle.error,
      );
    } else {
      final ok = await provider.updateAddress(result);
      if (!mounted) return;
      showToast(
        context,
        ok
            ? context.l10n.addressUpdated
            : (provider.errorMessage ?? context.l10n.updateAddressFailed),
        style: ok ? ToastStyle.success : ToastStyle.error,
      );
    }
  }

  Future<void> _confirmRemoveAddress(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.removeAddress408),
        content: Text(context.l10n
            .removeFrom((address.display), (widget.contractor.name))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<ContractorAddressProvider>();
    final ok = await provider.removeAddress(address);
    if (!mounted) return;
    showToast(
      context,
      ok
          ? context.l10n.addressRemoved
          : (provider.errorMessage ?? context.l10n.removeAddressFailed),
      style: ok ? ToastStyle.success : ToastStyle.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the freshest copy from the provider (after edit/deactivate),
    // falling back to the argument before the list is loaded.
    final allContractors = context.watch<ContractorProvider>().contractors;
    final idx = allContractors.indexWhere((c) => c.id == widget.contractor.id);
    final fresh = idx != -1 ? allContractors[idx] : widget.contractor;
    final active = fresh.isActive;

    final addressProvider = context.watch<ContractorAddressProvider>();
    final addresses = addressProvider.contractorId == fresh.id
        ? addressProvider.addresses
        : const <Address>[];

    final contracts = context
        .watch<ContractProvider>()
        .contracts
        .where((c) => c.contractorId == fresh.id)
        .toList();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final email = fresh.email;
    final phone = fresh.phone;
    final contact = _group(
        context.l10n.contact,
        AppCollection(children: [
          if (email != null && email.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.group),
                child: ContactAction(value: email, email: true))
          else
            _noContactRow(context, Icons.email_outlined, context.l10n.email),
          if (phone != null && phone.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.group),
                child: ContactAction(value: phone, email: false))
          else
            _noContactRow(context, Icons.phone_outlined, context.l10n.phone),
          if ((fresh.website ?? '').isNotEmpty)
            ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.l10n.website,
                    style: theme.textTheme.labelLarge),
                subtitle: SelectableText(fresh.website!),
                trailing: fresh.websiteUri == null
                    ? null
                    : IconButton(
                        tooltip: context.l10n.openWebsite,
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _openWebsite(fresh.websiteUri!))),
        ]));
    final addressGroup = _group(
        context.l10n.address,
        AppCollection(children: [
          if (addresses.isEmpty)
            ListTile(
                leading: Icon(Icons.location_off_outlined,
                    color: scheme.onSurfaceVariant),
                title: Text(
                    addressProvider.isLoading
                        ? context.l10n.loadingAddresses
                        : addressProvider.errorMessage != null
                            ? context.l10n.couldNotLoadAddresses
                            : context.l10n.noAddressOnFile,
                    style: TextStyle(color: scheme.onSurfaceVariant)))
          else
            for (final address in addresses)
              ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: Text(address.display.isEmpty ? '—' : address.display),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: context.l10n.edit,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openAddressEditor(address)),
                    IconButton(
                        tooltip: context.l10n.remove,
                        icon: Icon(Icons.delete_outline, color: scheme.error),
                        onPressed: () => _confirmRemoveAddress(address)),
                  ])),
        ]),
        action: TextButton.icon(
            onPressed: () => _openAddressEditor(null),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.add)));
    final linkedContracts = _group(
        context.l10n.contracts,
        AppCollection(children: [
          if (contracts.isEmpty)
            ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(context.l10n.noContractsForThisContractor))
          else
            for (final contract in contracts)
              ContractListItem(
                  contract: contract,
                  onTap: () => Navigator.of(context)
                      .pushNamed('/contract/detail', arguments: contract)),
        ]));
    final information = <Widget>[
      if ((fresh.description ?? '').isNotEmpty)
        _metadataSection(context.l10n.description, fresh.description!),
      if ((fresh.notes ?? '').isNotEmpty)
        _metadataSection(context.l10n.notes, fresh.notes!),
      linkedContracts,
    ];
    final contacts = <Widget>[contact, addressGroup];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.contractor),
      ),
      floatingActionButton: AppBottomActions(
          icon: Icons.edit_outlined,
          tooltip: context.l10n.edit,
          onPressed: _openEdit,
          secondary: [
            AppBottomAction(
                tooltip: active
                    ? context.l10n.deactivate401
                    : context.l10n.reactivate,
                onPressed: active ? _confirmDeactivate : _activate,
                destructive: active,
                icon: active ? Icons.block : Icons.check_circle_outline)
          ]),
      body: AppPageListView(
        maxWidth: AppSpace.maxWidth,
        padding: AppSpace.pageInsets(context, bottom: 112),
        children: [
          Text(context.l10n.contractor.toUpperCase(),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: scheme.primary, letterSpacing: 1.2)),
          const SizedBox(height: AppSpace.control),
          Text(fresh.name, style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpace.group),
          Wrap(
              spacing: AppSpace.control,
              runSpacing: AppSpace.control,
              children: [
                Chip(
                    avatar: Icon(
                        fresh.type == ContractorType.company
                            ? Icons.business
                            : Icons.person_outline,
                        size: 18,
                        color: scheme.primary),
                    label: Text(fresh.typeLabel)),
                if (!active)
                  Chip(
                      avatar: Icon(Icons.block,
                          size: 18, color: scheme.onSurfaceVariant),
                      label: Text(context.l10n.inactive)),
              ]),
          const SizedBox(height: AppSpace.section),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth >= 900 &&
                MediaQuery.textScalerOf(context).scale(14) <= 19) {
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        flex: 3, child: AppFormColumn(children: information)),
                    const SizedBox(width: AppSpace.section),
                    Expanded(flex: 2, child: AppFormColumn(children: contacts)),
                  ]);
            }
            return AppFormColumn(children: [...contacts, ...information]);
          }),
        ],
      ),
    );
  }

  Widget _noContactRow(BuildContext context, IconData icon, String label) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading:
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic)),
    );
  }
}
