import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contract.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contract_provider.dart';
import '../../widgets/contract_list_item.dart';
import '../../app_routes.dart';
import '../../widgets/stats_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum _ContractFilter { none, active, expiring }

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  _ContractFilter _filter = _ContractFilter.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContractProvider>().fetchContracts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showError(String? message) async {
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, child) => IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                await auth.logout();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Consumer2<AuthProvider, ContractProvider>(
        builder: (context, auth, contracts, child) {
          // Surface a stale session (expired token) as a snackbar and
          // bounce back to the login screen.
          if (!auth.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _showError(auth.errorMessage ??
                  'Your session expired. Please login again.');
              if (mounted && !auth.isAuthenticated) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            });
          }

          if (contracts.isLoading && contracts.contracts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (contracts.errorMessage != null &&
              contracts.contracts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      contracts.errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => contracts.fetchContracts(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final visible = _searching
              ? contracts.searchContracts(_searchController.text)
              : _filter == _ContractFilter.active
                  ? contracts.contracts.where((c) => c.status == ContractStatus.active).toList()
                  : _filter == _ContractFilter.expiring
                      ? contracts.getExpiringContracts()
                      : contracts.contracts;

          return Column(
            children: [
              _buildStatsSection(context, contracts),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search contracts...',
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
                    ? _buildEmptyState(context, contracts)
                    : RefreshIndicator(
                        onRefresh: () => contracts.refreshContracts(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            return ContractListItem(
                              contract: visible[index],
                              onTap: () {
                                contracts.setSelectedContract(visible[index]);
                                Navigator.of(context)
                                    .pushNamed('/contract/detail',
                                        arguments: visible[index]);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/contract/create');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Contract'),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Qontract',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  auth.user?.email ?? 'Signed in',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: true,
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Contractors'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(AppRoutes.contractorList);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.of(context).pop();
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
      BuildContext context, ContractProvider provider) {
    final total = provider.contracts.length;
    final active = provider.activeCount;
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
                onTap: _filter != _ContractFilter.none || _searching
                    ? () => setState(() {
                          _filter = _ContractFilter.none;
                          _searchController.clear();
                          _searching = false;
                        })
                    : null,
              ),
              const SizedBox(width: 16),
              StatsCard(
                title: 'Active',
                value: active.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
                onTap: active > 0
                    ? () => setState(() => _filter = _ContractFilter.active)
                    : null,
              ),
              const SizedBox(width: 16),
              StatsCard(
                title: 'Expiring',
                value: expiring.toString(),
                icon: Icons.warning,
                color: Colors.orange,
                onTap: expiring > 0
                    ? () => setState(() => _filter = _ContractFilter.expiring)
                    : null,
              ),
            ],
          ),
          if (_filter != _ContractFilter.none) ...[
            const SizedBox(height: 12),
            _buildFilterChip(context),
          ]
          else if (expiring > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
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

  Widget _buildFilterChip(BuildContext context) {
    final label = _filter == _ContractFilter.active
        ? 'Active contracts'
        : 'Expiring within 30 days';
    final color = _filter == _ContractFilter.active ? Colors.green : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Chip(
        avatar: Icon(
          _filter == _ContractFilter.active ? Icons.check_circle : Icons.warning,
          color: color,
          size: 18,
        ),
        label: Text(label),
        backgroundColor: color.withValues(alpha: 0.1),
        side: BorderSide(color: color),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => setState(() {
          _filter = _ContractFilter.none;
          _searchController.clear();
          _searching = false;
        }),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ContractProvider provider) {
    final hasAny = provider.contracts.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasAny ? Icons.search_off : Icons.description_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasAny ? 'No matches' : 'No contracts yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            hasAny
                ? 'Try a different search term'
                : 'Create your first contract',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}
