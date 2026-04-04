import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contract_provider.dart';
import '../../widgets/contract_list_item.dart';
import '../../widgets/stats_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final success = await context.read<AuthProvider>().logout();
              if (mounted && success) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer<ContractProvider>(
            builder: (context, contractProvider, child) {
              if (contractProvider.isLoading && contractProvider.contracts.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildStatsSection(context, contractProvider);
            },
          ),
          Expanded(
            child: Consumer<ContractProvider>(
              builder: (context, contractProvider, child) {
                if (contractProvider.contracts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No contracts yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first contract',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _buildContractList(context, contractProvider);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/contract/create');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Contract'),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, ContractProvider provider) {
    final total = provider.contracts.length;
    final active = provider.contracts.where((c) => c.status == 'active').length;
    final expiring = provider.getExpiringContracts().length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              StatsCard(
                title: 'Total',
                value: total.toString(),
                icon: Icons.description,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              StatsCard(
                title: 'Active',
                value: active.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              const SizedBox(width: 16),
              StatsCard(
                title: 'Expiring',
                value: expiring.toString(),
                icon: Icons.warning,
                color: Colors.orange,
              ),
            ],
          ),
          if (expiring > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$expiring contract(s) expiring within 30 days',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContractList(BuildContext context, ContractProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contracts...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _searchController.clear(),
              ),
            ),
            onChanged: (_) => provider.searchContracts(_searchController.text),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: provider.contracts.length,
            itemBuilder: (context, index) {
              return ContractListItem(contract: provider.contracts[index]);
            },
          ),
        ),
      ],
    );
  }
}