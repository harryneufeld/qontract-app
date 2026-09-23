import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contractor.dart';
import '../../providers/contract_provider.dart';
import '../../providers/contractor_provider.dart';
import '../../app_routes.dart';
import '../../widgets/contract_list_item.dart';

class ContractorDetailScreen extends StatelessWidget {
  const ContractorDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contractor = ModalRoute.of(context)?.settings.arguments as Contractor?;
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
  Future<void> _openEdit() async {
    await Navigator.of(context).pushNamed(
      AppRoutes.contractorForm,
      arguments: widget.contractor,
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Deactivated "${widget.contractor.name}".'
            : (provider.errorMessage ?? 'Deactivate failed.')),
      ),
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

    final contracts = context.watch<ContractProvider>().contracts
        .where((c) => c.contractorId == fresh.id)
        .toList();

    final chipColor = fresh.type == ContractorType.company
        ? Theme.of(context).colorScheme.primary
        : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: Text(fresh.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit),
            onPressed: _openEdit,
          ),
          if (active)
            IconButton(
              tooltip: 'Deactivate',
              icon: const Icon(Icons.block, color: Colors.red),
              onPressed: _confirmDeactivate,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      side: BorderSide(
                          color: active ? chipColor : Colors.grey[400]!),
                    ),
                    if (!active) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text('Inactive'),
                        backgroundColor: Colors.grey.withValues(alpha: 0.1),
                        side: const BorderSide(color: Colors.grey),
                        avatar: const Icon(Icons.block,
                            color: Colors.grey, size: 16),
                        padding: EdgeInsets.zero,
                        labelStyle: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                if (fresh.contactInfo != null &&
                    fresh.contactInfo!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    fresh.contactInfo!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Contracts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: contracts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
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
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: contracts.length,
                    itemBuilder: (context, index) {
                      return ContractListItem(
                        contract: contracts[index],
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/contract/detail',
                            arguments: contracts[index],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
