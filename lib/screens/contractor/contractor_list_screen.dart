import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contractor.dart';
import '../../providers/contract_provider.dart';
import '../../providers/contractor_provider.dart';
import '../../app_routes.dart';
import '../../widgets/app_toast.dart';

/// Full contractor management view: searchable list, add, edit, deactivate.
///
/// Deactivated contractors stay visible (dimmed, flagged) so existing
/// contracts that reference them remain resolvable.
class ContractorListScreen extends StatefulWidget {
  const ContractorListScreen({super.key});

  @override
  State<ContractorListScreen> createState() => _ContractorListScreenState();
}

class _ContractorListScreenState extends State<ContractorListScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContractorProvider>().fetchContractors();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm({Contractor? contractor}) async {
    final provider = context.read<ContractorProvider>();
    // Make sure the list is populated so the dropdowns and counts stay in
    // sync after a create.
    if (provider.contractors.isEmpty && !provider.isLoading) {
      provider.fetchContractors();
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.contractorForm,
      arguments: contractor,
    );
  }

  Future<void> _confirmDeactivate(Contractor contractor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate Contractor'),
        content: Text(
          'Deactivate "${contractor.name}"?\n\n'
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
    final ok = await provider.deactivateContractor(contractor);
    if (!mounted) return;
    showToast(
      context,
      ok
          ? 'Deactivated "${contractor.name}".'
          : (provider.errorMessage ?? 'Deactivate failed.'),
      style: ok ? ToastStyle.success : ToastStyle.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contractors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<ContractorProvider>().refreshContractors(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add'),
      ),
      body: Consumer2<ContractProvider, ContractorProvider>(
        builder: (context, contractProv, contractorProv, child) {
          if (contractorProv.isLoading && contractorProv.contractors.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (contractorProv.errorMessage != null &&
              contractorProv.contractors.isEmpty) {
            return _buildErrorState(context, contractorProv);
          }

          final visible = _searching
              ? _searchContractors(contractorProv.contractors, _searchController.text)
              : contractorProv.contractors;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search contractors...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searching
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searching = false);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searching = value.isNotEmpty),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? _buildEmptyState(context, contractorProv)
                    : RefreshIndicator(
                        onRefresh: () => contractorProv.refreshContractors(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final contractor = visible[index];
                            // Server-side total (app#33): the count must
                            // cover ALL of the contractor's contracts, not
                            // just the loaded dashboard page. Falls back to
                            // counting the loaded slice only when the
                            // backend predates the field and the full list
                            // is loaded anyway.
                            final contractCount =
                                contractor.contractCount > 0
                                    ? contractor.contractCount
                                    : contractProv.hasMore
                                        ? 0
                                        : contractProv.contracts
                                            .where((c) => c.contractorId == contractor.id)
                                            .length;
                            return _ContractorListTile(
                              contractor: contractor,
                              contractCount: contractCount,
                              onOpen: () {
                                contractorProv.setSelectedContractor(contractor);
                                Navigator.of(context).pushNamed(
                                  AppRoutes.contractorDetail,
                                  arguments: contractor,
                                );
                              },
                              onEdit: () => _openForm(contractor: contractor),
                              onDeactivate: () => _confirmDeactivate(contractor),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ContractorProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => provider.fetchContractors(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ContractorProvider provider) {
    final hasAny = provider.contractors.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasAny ? Icons.search_off : Icons.person_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasAny ? 'No matches' : 'No contractors yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!hasAny) ...[
            const SizedBox(height: 8),
            Text(
              'Use the Add button to create your first contractor.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  List<Contractor> _searchContractors(List<Contractor> list, String query) {
    final q = query.toLowerCase();
    return list.where((c) =>
        c.name.toLowerCase().contains(q) ||
        (c.email ?? '').toLowerCase().contains(q) ||
        (c.phone ?? '').toLowerCase().contains(q)).toList();
  }
}

class _ContractorListTile extends StatelessWidget {
  final Contractor contractor;
  final int contractCount;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  const _ContractorListTile({
    required this.contractor,
    required this.contractCount,
    required this.onOpen,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = contractor.isActive;
    final chipColor = contractor.type == ContractorType.company
        ? scheme.primary
        : Colors.green;
    // Theme-aware so names stay readable on dark cards (app#32).
    final nameColor = active ? scheme.onSurface : scheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: chipColor.withValues(alpha: active ? 0.15 : 0.08),
          child: Icon(
            contractor.type == ContractorType.company
                ? Icons.business
                : Icons.person,
            color: active ? chipColor : Colors.grey[500],
          ),
        ),
        title: Text(
          contractor.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: nameColor),
        ),
        subtitle: Text(
          [
            if (!active) 'Inactive',
            if (contractor.contactLine.isNotEmpty) contractor.contactLine,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? null : Colors.grey[500],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(contractor.typeLabel),
              backgroundColor: chipColor.withValues(alpha: active ? 0.1 : 0.05),
              side: BorderSide(color: active ? chipColor : Colors.grey[400]!),
              padding: EdgeInsets.zero,
              labelStyle: const TextStyle(fontSize: 12),
            ),
            if (contractCount > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$contractCount',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: chipColor,
                    ),
              ),
            ],
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'deactivate') {
                  onDeactivate();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (active)
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: ListTile(
                      leading: Icon(Icons.block, color: Colors.red),
                      title: Text('Deactivate', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}
