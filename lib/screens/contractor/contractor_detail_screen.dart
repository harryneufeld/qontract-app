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
        appBar: AppBar(title: const Text('Contractor')),
        body: const Center(child: Text('No contractor selected')),
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
    showToast(context, 'Could not open website.', style: ToastStyle.error);
  }

  Widget _metadataSection(String title, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(value),
        ]),
      );

  Future<void> _activate() async {
    final provider = context.read<ContractorProvider>();
    final ok = await provider.activateContractor(widget.contractor);
    if (!mounted) return;
    showToast(
        context,
        ok
            ? 'Contractor reactivated.'
            : (provider.errorMessage ?? 'Reactivate failed.'),
        style: ok ? ToastStyle.success : ToastStyle.error);
  }

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate Contractor'),
        content: Text(
          'Deactivate "${widget.contractor.name}"?\n\n'
          'It will no longer be selectable on new contracts, but existing '
          'contracts that reference it stay intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Deactivate'),
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
          ? 'Deactivated "${widget.contractor.name}".'
          : (provider.errorMessage ?? 'Deactivate failed.'),
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
            ? 'Address added.'
            : (provider.errorMessage ?? 'Add address failed.'),
        style: created != null ? ToastStyle.success : ToastStyle.error,
      );
    } else {
      final ok = await provider.updateAddress(result);
      if (!mounted) return;
      showToast(
        context,
        ok
            ? 'Address updated.'
            : (provider.errorMessage ?? 'Update address failed.'),
        style: ok ? ToastStyle.success : ToastStyle.error,
      );
    }
  }

  Future<void> _confirmRemoveAddress(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Address'),
        content:
            Text('Remove "${address.display}" from ${widget.contractor.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
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
          ? 'Address removed.'
          : (provider.errorMessage ?? 'Remove address failed.'),
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

    final chipColor = fresh.type == ContractorType.company
        ? Theme.of(context).colorScheme.primary
        : Colors.green;

    final email = fresh.email;
    final phone = fresh.phone;

    return Scaffold(
      appBar: AppBar(
        title: Text(fresh.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      floatingActionButton: AppBottomActions(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          onPressed: _openEdit,
          secondary: [
            AppBottomAction(
                tooltip: active ? 'Deactivate' : 'Reactivate',
                onPressed: active ? _confirmDeactivate : _activate,
                destructive: active,
                icon: active ? Icons.block : Icons.check_circle_outline)
          ]),
      body: AppPageListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          Row(
            children: [
              Icon(
                fresh.type == ContractorType.company
                    ? Icons.business
                    : Icons.person,
                color: active ? chipColor : Colors.grey[500],
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(fresh.typeLabel),
                backgroundColor:
                    chipColor.withValues(alpha: active ? 0.1 : 0.05),
                side: BorderSide(color: active ? chipColor : Colors.grey[400]!),
              ),
              if (!active) ...[
                const SizedBox(width: 8),
                Chip(
                  label: const Text('Inactive'),
                  backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  side: const BorderSide(color: Colors.grey),
                  avatar: const Icon(Icons.block, color: Colors.grey, size: 16),
                  padding: EdgeInsets.zero,
                  labelStyle: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // ------------------------------------------------------ contact
          _sectionHeader(context, Icons.contact_page, 'Contact'),
          AppCollectionRow(
            child: Column(
              children: [
                if (email != null && email.isNotEmpty)
                  ContactAction(value: email, email: true)
                else
                  _noContactRow(context, Icons.email_outlined, 'Email'),
                const Divider(height: 1),
                if (phone != null && phone.isNotEmpty)
                  ContactAction(value: phone, email: false)
                else
                  _noContactRow(context, Icons.phone_outlined, 'Phone'),
              ],
            ),
          ),

          if ((fresh.website ?? '').isNotEmpty) ...[
            _sectionHeader(context, Icons.language, 'Website'),
            AppCollectionRow(
                child: ListTile(
              title: SelectableText(fresh.website!),
              trailing: fresh.websiteUri == null
                  ? null
                  : IconButton(
                      tooltip: 'Open website',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openWebsite(fresh.websiteUri!),
                    ),
            )),
            const SizedBox(height: 16),
          ],
          if ((fresh.description ?? '').isNotEmpty)
            _metadataSection('Description', fresh.description!),
          if ((fresh.notes ?? '').isNotEmpty)
            _metadataSection('Notes', fresh.notes!),

          // ------------------------------------------------------ address
          _sectionHeader(context, Icons.location_on_outlined, 'Address',
              trailing: TextButton.icon(
                onPressed: () => _openAddressEditor(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              )),
          if (addresses.isEmpty)
            AppCollectionRow(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.location_off_outlined, color: Colors.grey[400]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        addressProvider.errorMessage != null &&
                                !addressProvider.isLoading
                            ? 'Could not load addresses: ${addressProvider.errorMessage}'
                            : 'No address on file.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final a in addresses)
              AppCollectionRow(
                child: ListTile(
                  leading:
                      const Icon(Icons.home_outlined, color: Color(0xFF1976D2)),
                  title: Text(a.display.isEmpty ? '—' : a.display,
                      style: Theme.of(context).textTheme.bodyMedium),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _openAddressEditor(a),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: Colors.red),
                        onPressed: () => _confirmRemoveAddress(a),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 8),

          // ------------------------------------------------------ contracts
          _sectionHeader(context, Icons.description_outlined, 'Contracts'),
          if (contracts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No contracts for this contractor',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            )
          else
            ...contracts.map(
              (contract) => ContractListItem(
                contract: contract,
                onTap: () {
                  Navigator.of(context).pushNamed(
                    '/contract/detail',
                    arguments: contract,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _noContactRow(BuildContext context, IconData icon, String label) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: Colors.grey[400]),
      title: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[500], fontStyle: FontStyle.italic)),
    );
  }
}
