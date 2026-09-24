import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/contract.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/contractor_provider.dart';
import '../../widgets/contract_list_item.dart';
import '../../app_routes.dart';
import '../../widgets/stat_chip.dart';
import '../../services/cost_summary.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

/// Status quick-filters (issue #20). Values other than [all] map to
/// [ContractProvider.filterByStatus]. `minDate` reuses the "minimum
/// contract date within 90 days" list of the former large stat cards.
class _StatusFilter {
  static const String all = 'all';
  static const String active = 'active';
  static const String expiring = 'expiring';
  static const String expired = 'expired';
  static const String minDate = 'minDate';
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Pref key prefix for the collapsed/expanded state of the stats area
  /// (issue #20), scoped per tenant.
  static const String _expandedKeyPrefix = 'dashboard.statsExpanded.';

  /// Pref key prefix for the selected cost-summary period (issue #13),
  /// scoped per tenant.
  static const String _costPeriodKeyPrefix = 'dashboard.costPeriod.';

  final _searchController = TextEditingController();
  bool _searching = false;
  String _statusFilter = _StatusFilter.all;
  int? _contractorFilter;
  int? _endingFilter; // days: contracts ending within this many days
  bool _statsExpanded = true;
  CostPeriod _costPeriod = CostPeriod.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ContractProvider>().fetchContracts();
      // Contractor names are needed for the list subtitles, the search
      // field (counterparty lookup) and the contractor quick filter.
      final contractors = context.read<ContractorProvider>();
      if (contractors.contractors.isEmpty) {
        contractors.fetchContractors();
      }
      _loadExpandedState();
      _loadCostPeriod();
    });
  }

  Future<void> _loadExpandedState() async {
    final tenantId = context.read<AuthProvider>().user?.tenantId;
    if (tenantId == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _statsExpanded = prefs.getBool('$_expandedKeyPrefix$tenantId') ?? true);
  }

  void _setStatsExpanded(bool expanded) {
    setState(() => _statsExpanded = expanded);
    final tenantId = context.read<AuthProvider>().user?.tenantId;
    if (tenantId == null) return;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('$_expandedKeyPrefix$tenantId', expanded);
    });
  }

  Future<void> _loadCostPeriod() async {
    final tenantId = context.read<AuthProvider>().user?.tenantId;
    if (tenantId == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = prefs.getString('$_costPeriodKeyPrefix$tenantId');
    setState(() => _costPeriod = CostPeriod.values.firstWhere(
          (p) => p.name == raw,
          orElse: () => CostPeriod.month,
        ));
  }

  void _setCostPeriod(CostPeriod period) {
    setState(() => _costPeriod = period);
    final tenantId = context.read<AuthProvider>().user?.tenantId;
    if (tenantId == null) return;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('$_costPeriodKeyPrefix$tenantId', period.name);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasStatusFilter => _statusFilter != _StatusFilter.all;
  bool get _hasFilters =>
      _hasStatusFilter || _contractorFilter != null || _endingFilter != null;

  void _toggleStatusFilter(String filter) {
    setState(() => _statusFilter = _statusFilter == filter
        ? _StatusFilter.all
        : filter);
  }

  void _clearAllFilters() {
    setState(() {
      _statusFilter = _StatusFilter.all;
      _contractorFilter = null;
      _endingFilter = null;
      _searchController.clear();
      _searching = false;
    });
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
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
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
      body: Consumer3<AuthProvider, ContractProvider, ContractorProvider>(
        builder: (context, auth, contracts, contractors, child) {
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

          final contractorNames = {
            for (final k in contractors.contractors) k.id: k.name,
          };

          // Search takes precedence over the quick filters (existing
          // behaviour); otherwise the three filter dimensions compose.
          List<Contract> visible;
          if (_searching) {
            visible = contracts.searchContracts(_searchController.text,
                contractorNames: contractorNames);
          } else {
            visible = contracts.filterByStatus(_statusFilter);
            if (_contractorFilter != null) {
              final id = _contractorFilter!;
              visible = visible.where((c) => c.contractorId == id).toList();
            }
            if (_endingFilter != null) {
              visible = contracts
                  .filterByEndingWithinDays(_endingFilter!)
                  .where((c) => visible.contains(c))
                  .toList();
            }
          }

          return Column(
            children: [
              _buildStatsSection(context, contracts, contractors),
              _buildCostSection(context, contracts),
              Padding(
                // Top gap keeps the search bar from touching the costs
                // container (app#32).
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  return ContractListItem(
                                    contract: visible[index],
                                    contractorName:
                                        contractorNames[visible[index].contractorId],
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
                            if (contracts.hasMore)
                              _buildLoadMore(contracts),
                          ],
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
            // No custom background: the header matches the drawer body in
            // both light and dark themes (app#32).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Qontract',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  auth.user?.email ?? 'Signed in',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(AppRoutes.settings);
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

  // ------------------------------------------------------- compact stats

  /// Compact overview (issue #20): a header row plus a horizontally
  /// scrolling row of tappable stat chips (quick filters), and — when
  /// expanded — a secondary row with contractor + end-date-range filters.
  /// Collapsed height is well below 25% of a regular phone's screen.
  Widget _buildStatsSection(
    BuildContext context,
    ContractProvider provider,
    ContractorProvider contractors,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = provider.contracts.length;
    final active = provider.activeCount;
    final expiring = provider.getExpiringContracts().length;
    final expired = provider.expiredCount;
    final minDateApproaching = provider.getMinDateApproachingContracts().length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Overview',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_hasFilters)
                IconButton(
                  key: const Key('clearFilters'),
                  tooltip: 'Clear filters',
                  icon: const Icon(Icons.filter_alt_off),
                  onPressed: _clearAllFilters,
                ),
              IconButton(
                key: const Key('statsExpand'),
                tooltip: _statsExpanded ? 'Hide filters' : 'Show filters',
                icon: Icon(_statsExpanded ? Icons.expand_less : Icons.tune),
                onPressed: () => _setStatsExpanded(!_statsExpanded),
              ),
            ],
          ),
          SizedBox(
            height: 60,
            child: ListView(
              key: const Key('statChips'),
              scrollDirection: Axis.horizontal,
              children: [
                StatChip(
                  key: const Key('statTotal'),
                  title: 'Total',
                  value: '$total',
                  icon: Icons.description,
                  color: scheme.primary,
                  active: _hasFilters,
                  onTap: _hasFilters ? _clearAllFilters : null,
                ),
                const SizedBox(width: 8),
                StatChip(
                  key: const Key('statActive'),
                  title: 'Active',
                  value: '$active',
                  icon: Icons.check_circle,
                  color: Colors.green,
                  active: _statusFilter == _StatusFilter.active,
                  onTap: () => _toggleStatusFilter(_StatusFilter.active),
                ),
                const SizedBox(width: 8),
                StatChip(
                  key: const Key('statExpiring'),
                  title: 'Expiring',
                  value: '$expiring',
                  icon: Icons.warning,
                  color: Colors.orange,
                  active: _statusFilter == _StatusFilter.expiring,
                  onTap: () => _toggleStatusFilter(_StatusFilter.expiring),
                ),
                const SizedBox(width: 8),
                StatChip(
                  key: const Key('statExpired'),
                  title: 'Expired',
                  value: '$expired',
                  icon: Icons.hourglass_bottom,
                  color: Colors.red,
                  active: _statusFilter == _StatusFilter.expired,
                  onTap: () => _toggleStatusFilter(_StatusFilter.expired),
                ),
                const SizedBox(width: 8),
                StatChip(
                  key: const Key('statMinDate'),
                  title: 'Min. date 90d',
                  value: '$minDateApproaching',
                  icon: Icons.event_busy,
                  color: Colors.deepPurple,
                  active: _statusFilter == _StatusFilter.minDate,
                  onTap: () => _toggleStatusFilter(_StatusFilter.minDate),
                ),
              ],
            ),
          ),
          if (_statsExpanded) ...[
            const SizedBox(height: 8),
            _buildSecondaryFilters(contractors),
          ],
        ],
      ),
    );
  }

  Widget _buildSecondaryFilters(ContractorProvider contractors) {
    final activeContractor = _contractorFilter;
    final activeEnding = _endingFilter;
    return Row(
      children: [
        Expanded(
          child: _CompactDropdown<int?>(
            key: const Key('contractorFilter'),
            icon: Icons.business,
            hint: 'All contractors',
            value: activeContractor,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All contractors',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              ...contractors.contractors.map(
                (c) => DropdownMenuItem<int?>(
                  value: c.id,
                  child: Text(c.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) =>
                setState(() => _contractorFilter = value),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactDropdown<int?>(
            key: const Key('endingFilter'),
            icon: Icons.calendar_month,
            hint: 'Any end date',
            value: activeEnding,
            items: const [
              DropdownMenuItem<int?>(
                  value: null, child: Text('Any end date')),
              DropdownMenuItem<int?>(value: 30, child: Text('Next 30 days')),
              DropdownMenuItem<int?>(value: 90, child: Text('Next 90 days')),
              DropdownMenuItem<int?>(
                  value: 365, child: Text('Next 12 months')),
            ],
            onChanged: (value) => setState(() => _endingFilter = value),
          ),
        ),
      ],
    );
  }

  /// Compact cost summary for active contracts (issue #13): a card with
  /// a period switcher (month / half year / year / all active) and the
  /// per-currency sum of contract values for the selected period.
  Widget _buildCostSection(BuildContext context, ContractProvider provider) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = computeCostSum(
      contracts: provider.contracts,
      period: _costPeriod,
    );
    final fmt = NumberFormat('#,##0.00', 'en');

    return Container(
      key: const Key('costSection'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Costs (active)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (summary.isEmpty)
                Text(
                  'No active contract costs in this period',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                Text(
                  '${summary.contractCount} '
                  '${summary.contractCount == 1 ? 'contract' : 'contracts'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...CostPeriod.values.expand((p) => [
                _CostPeriodPill(
                  period: p,
                  active: p == _costPeriod,
                  onTap: () => _setCostPeriod(p),
                ),
                if (p != CostPeriod.values.last) const SizedBox(width: 4),
              ]),
            ],
          ),
          if (!summary.isEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 2,
              children: [
                ...summary.byCurrency.entries.map(
                  (e) => Text(
                    '${e.key.isEmpty ? '' : '${e.key} '}'
                    '${fmt.format(e.value)}',
                    key: ValueKey('cost.${e.key}'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Footer shown while [ContractProvider.hasMore] is true (issue #21): a
  /// "Load more" affordance with an inline spinner while the next page is
  /// in flight. Tapping loads and appends the next page.
  Widget _buildLoadMore(ContractProvider provider) {
    final loading = provider.isLoadingMore;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: SizedBox(
          height: 32,
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : OutlinedButton.icon(
                  key: const Key('loadMore'),
                  onPressed: () => provider.loadMore(),
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: const Text('Load more'),
                ),
        ),
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
                ? 'Try a different search term or clear the filters'
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

/// Small labelled dropdown for the secondary quick-filter row (issue
/// #20). Shows its hint (e.g. "All contractors") while unselected and
/// highlights when a filter is applied.
class _CompactDropdown<T> extends StatelessWidget {
  final IconData icon;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T?>> items;
  final ValueChanged<T?> onChanged;

  const _CompactDropdown({
    super.key,
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlighted = value != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? theme.colorScheme.primary : theme.dividerColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: highlighted
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T?>(
                isExpanded: true,
                value: value,
                hint: Text(
                  hint,
                  style: theme.textTheme.bodySmall,
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill toggle for the cost-summary period switcher (issue #13).
class _CostPeriodPill extends StatelessWidget {
  final CostPeriod period;
  final bool active;
  final VoidCallback onTap;

  const _CostPeriodPill({
    required this.period,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = switch (period) {
      CostPeriod.month => 'Month',
      CostPeriod.halfYear => 'Half year',
      CostPeriod.year => 'Year',
      CostPeriod.allActive => 'All active',
    };
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('costPeriod.${period.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? scheme.primary : scheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? scheme.primary : theme.dividerColor,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
