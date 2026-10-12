import '../../l10n/strings.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_bottom_actions.dart';
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
      if (!mounted) return;
      context.read<ContractorProvider>().fetchContractors();
    });
  }

  Future<void> _activate(Contractor contractor) async {
    final provider = context.read<ContractorProvider>();
    final ok = await provider.activateContractor(contractor);
    if (!mounted) return;
    showToast(
        context,
        ok
            ? context.l10n.reactivated((contractor.name))
            : (provider.errorMessage ?? context.l10n.reactivateFailed),
        style: ok ? ToastStyle.success : ToastStyle.error);
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
        title: Text(context.l10n.deactivateContractor),
        content: Text(
          context.l10n.deactivate445((contractor.name)) +
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
    final ok = await provider.deactivateContractor(contractor);
    if (!mounted) return;
    showToast(
      context,
      ok
          ? context.l10n.deactivated446((contractor.name))
          : (provider.errorMessage ?? context.l10n.deactivateFailed),
      style: ok ? ToastStyle.success : ToastStyle.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.contractors),
      ),
      floatingActionButton: AppBottomActions(
          onPressed: () => _openForm(),
          icon: Icons.add,
          tooltip: context.l10n.addContractor),
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
              ? _searchContractors(
                  contractorProv.contractors, _searchController.text)
              : contractorProv.contractors;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.l10n.searchContractors,
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
                  onChanged: (value) =>
                      setState(() => _searching = value.isNotEmpty),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => RefreshIndicator(
                            onRefresh: contractorProv.refreshContractors,
                            child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                      height: constraints.maxHeight,
                                      child: _buildEmptyState(
                                          context, contractorProv)),
                                ])))
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
                            // just the loaded contracts page, including zero.
                            final contractCount = contractor.contractCount;
                            return _ContractorListTile(
                              contractor: contractor,
                              contractCount: contractCount,
                              onOpen: () {
                                contractorProv
                                    .setSelectedContractor(contractor);
                                Navigator.of(context).pushNamed(
                                  AppRoutes.contractorDetail,
                                  arguments: contractor,
                                );
                              },
                              onEdit: () => _openForm(contractor: contractor),
                              onDeactivate: () =>
                                  _confirmDeactivate(contractor),
                              onActivate: () => _activate(contractor),
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
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ContractorProvider provider) {
    final hasAny = provider.contractors.isNotEmpty;
    return Center(
      child: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasAny ? Icons.search_off : Icons.person_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasAny
                        ? context.l10n.noMatches
                        : context.l10n.noContractorsYet,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (!hasAny) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.useTheAddButtonToCreateYourFirst,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ))),
    );
  }

  List<Contractor> _searchContractors(List<Contractor> list, String query) {
    final q = query.toLowerCase();
    return list
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            (c.email ?? '').toLowerCase().contains(q) ||
            (c.phone ?? '').toLowerCase().contains(q))
        .toList();
  }
}

class _ContractorListTile extends StatelessWidget {
  final Contractor contractor;
  final int contractCount;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onActivate;

  const _ContractorListTile({
    required this.contractor,
    required this.contractCount,
    required this.onOpen,
    required this.onEdit,
    required this.onDeactivate,
    required this.onActivate,
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

    return AppCollectionRow(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (contractor.contactLine.isNotEmpty)
            Text(contractor.contactLine,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(contractor.typeLabel, style: TextStyle(color: chipColor)),
                Text(context.l10n.contractCountLabel(contractCount)),
                if (!active) Text(context.l10n.inactive),
              ]),
        ]),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              tooltip: context.l10n.more,
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'deactivate') {
                  onDeactivate();
                } else if (value == 'activate') {
                  onActivate();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: const Icon(Icons.edit),
                    title: Text(context.l10n.edit),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (active)
                  PopupMenuItem(
                    value: 'deactivate',
                    child: ListTile(
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: Text(context.l10n.deactivate401,
                          style: const TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                else
                  PopupMenuItem(
                    value: 'activate',
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(context.l10n.reactivate),
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
