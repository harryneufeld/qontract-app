import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contractor.dart';
import '../../providers/contract_provider.dart';
import '../../providers/contractor_provider.dart';
import '../../app_routes.dart';

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
      body: Consumer2<ContractProvider, ContractorProvider>(
        builder: (context, contractProv, contractorProv, child) {
          if (contractorProv.isLoading && contractorProv.contractors.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (contractorProv.errorMessage != null && contractorProv.contractors.isEmpty) {
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
                            final contractCount = contractProv.contracts
                                .where((c) => c.contractorId == contractor.id)
                                .length;
                            return _ContractorListTile(
                              contractor: contractor,
                              contractCount: contractCount,
                              onTap: () {
                                contractorProv.setSelectedContractor(contractor);
                                Navigator.of(context).pushNamed(
                                  AppRoutes.contractorDetail,
                                  arguments: contractor,
                                );
                              },
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
            hasAny ? Icons.search_off : Icons.business_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasAny ? 'No matches' : 'No contractors yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  List<Contractor> _searchContractors(List<Contractor> list, String query) {
    final q = query.toLowerCase();
    return list.where((c) => c.name.toLowerCase().contains(q)).toList();
  }
}

class _ContractorListTile extends StatelessWidget {
  final Contractor contractor;
  final int contractCount;
  final VoidCallback onTap;

  const _ContractorListTile({
    required this.contractor,
    required this.contractCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = contractor.type == ContractorType.company
        ? Theme.of(context).colorScheme.primary
        : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: chipColor.withValues(alpha: 0.15),
          child: Icon(
            contractor.type == ContractorType.company
                ? Icons.business
                : Icons.person,
            color: chipColor,
          ),
        ),
        title: Text(contractor.name),
        subtitle: contractor.contactInfo != null && contractor.contactInfo!.isNotEmpty
            ? Text(contractor.contactInfo!)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(contractor.typeLabel),
              backgroundColor: chipColor.withValues(alpha: 0.1),
              side: BorderSide(color: chipColor),
              padding: EdgeInsets.zero,
              labelStyle: const TextStyle(fontSize: 12),
            ),
            if (contractCount > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$contractCount',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
