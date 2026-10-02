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
import '../../widgets/app_toast.dart';
import '../../widgets/stat_chip.dart';
import '../../services/cost_summary.dart';
import '../../widgets/wordmark.dart';

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

  final _searchController = TextEditingController();
  bool _searching = false;
  String _statusFilter = _StatusFilter.all;
  int? _contractorFilter;
  int? _endingFilter; // days: contracts ending within this many days
  bool _statsExpanded = true;

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
    });
  }

  Future<void> _loadExpandedState() async {
    final tenantId = context.read<AuthProvider>().user?.tenantId;
    if (tenantId == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() =>
        _statsExpanded = prefs.getBool('$_expandedKeyPrefix$tenantId') ?? true);
  }

  void _setStatsExpanded(bool expanded) {
    setState(() => _statsExpanded = expanded);
    final tenantId = context.read<AuthProvider>().user?.tenantId;
    if (tenantId == null) return;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('$_expandedKeyPrefix$tenantId', expanded);
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
    final next = _statusFilter == filter ? _StatusFilter.all : filter;
    setState(() => _statusFilter = next);
    // Server-side refetch (app#36): the filtered view must cover ALL of
    // the tenant's contracts in that bucket, not only the loaded slice.
    context.read<ContractProvider>().applyStatusFilter(next);
  }

  void _clearAllFilters() {
    setState(() {
      _statusFilter = _StatusFilter.all;
      _contractorFilter = null;
      _endingFilter = null;
      _searchController.clear();
      _searching = false;
    });
    // Drop the server-side status filter again, if one is active (app#36);
    // a no-op when the list is already unfiltered.
    context.read<ContractProvider>().applyStatusFilter(_StatusFilter.all);
  }

  Future<void> _showError(String? message) async {
    if (message != null) {
      showToast(
        context,
        message,
        style: ToastStyle.error,
        duration: const Duration(seconds: 5),
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
              icon: const Icon(Icons.groups_outlined),
              tooltip: 'Tenants',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.tenants)),
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
                final navigator = Navigator.of(context);
                await auth.logout();
                if (mounted) {
                  navigator.pushReplacementNamed('/login');
                }
              },
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Consumer3<AuthProvider, ContractProvider, ContractorProvider>(
        builder: (context, auth, contracts, contractors, child) {
          // Surface a stale session (expired token): bounce to login and
          // toast after navigation so the message stays visible (app#28).
          if (!auth.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final navigator = Navigator.of(context);
              if (!mounted || auth.isAuthenticated) return;
              final message = auth.errorMessage ??
                  'Your session expired. Please login again.';
              await _showError(message);
              if (mounted) {
                navigator.pushReplacementNamed('/login');
              }
            });
          }

          if (contracts.isLoading && contracts.contracts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (contracts.errorMessage != null && contracts.contracts.isEmpty) {
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

          return RefreshIndicator(
            onRefresh: contracts.refreshContracts,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                    child: _buildStatsSection(context, contracts, contractors)),
                SliverToBoxAdapter(
                    child: _buildCostSection(context, contracts)),
                SliverToBoxAdapter(
                    child: Padding(
                  padding: const EdgeInsets.all(16),
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
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) =>
                        setState(() => _searching = value.isNotEmpty),
                  ),
                )),
                if (visible.isEmpty)
                  SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _buildEmptyState(context, contracts)))
                else ...[
                  SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) => ContractListItem(
                          contract: visible[index],
                          contractorName:
                              contractorNames[visible[index].contractorId],
                          onTap: () {
                            contracts.setSelectedContract(visible[index]);
                            Navigator.of(context).pushNamed('/contract/detail',
                                arguments: visible[index]);
                          },
                        ),
                      )),
                  if (contracts.hasMore &&
                      !(_searching && contracts.hasFullList))
                    SliverToBoxAdapter(child: _buildLoadMore(contracts)),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ),
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
                // Brand wordmark (app#23); variant follows the theme.
                const QontractWordmark(size: 24),
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
            leading: const Icon(Icons.person_outline),
            title: const Text('Account'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(AppRoutes.account);
            },
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
            leading: const Icon(Icons.receipt_long),
            title: const Text('Invoices'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(AppRoutes.invoices);
            },
          ),
          ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Files'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(AppRoutes.documentList);
              }),
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
    // Tenant-wide counters from the server (app#33): the list is paginated,
    // so the chips must not count only the loaded slice. Falls back to the
    // slice-based counts when the backend predates the stats endpoint.
    final s = provider.stats;
    final total = s?.total ?? provider.contracts.length;
    final active = s?.active ?? provider.activeCount;
    final expiring = s?.expiring ?? provider.getExpiringContracts().length;
    final expired = s?.expired ?? provider.expiredCount;
    final minDateApproaching = s?.minDateApproaching ??
        provider.getMinDateApproachingContracts().length;

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
            onChanged: (value) => setState(() => _contractorFilter = value),
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
              DropdownMenuItem<int?>(value: null, child: Text('Any end date')),
              DropdownMenuItem<int?>(value: 30, child: Text('Next 30 days')),
              DropdownMenuItem<int?>(value: 90, child: Text('Next 90 days')),
              DropdownMenuItem<int?>(value: 365, child: Text('Next 12 months')),
            ],
            onChanged: (value) => setState(() => _endingFilter = value),
          ),
        ),
      ],
    );
  }

  /// Complete tenant costs, independent of every contract-list filter.
  Widget _buildCostSection(BuildContext context, ContractProvider provider) {
    final theme = Theme.of(context);
    final format = NumberFormat('#,##0.00', 'en');
    final now = DateTime.now();
    const periods = {
      CostPeriod.month: 'This month',
      CostPeriod.quarter: 'This quarter',
      CostPeriod.year: 'This year',
    };
    final ready = provider.hasFullList &&
        !provider.isLoadingFullList &&
        provider.fullListError == null;
    final activeCount = provider.costContracts
        .where((c) => c.status == ContractStatus.active)
        .length;
    return Container(
      key: const Key('costSection'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Estimated costs (active)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (provider.fullListError != null) ...[
          const Text(
              'Cost overview unavailable. The complete tenant list could not be loaded.'),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('retryCostOverview'),
            onPressed: provider.fetchAllContracts,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry cost overview'),
          ),
        ] else if (!ready) ...[
          const Text('Loading all active contract costs…'),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ] else ...[
          Text('$activeCount active contracts · entire tenant',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          for (final entry in periods.entries)
            _costOverviewRow(
                entry.key,
                entry.value,
                computeCostSum(
                    contracts: provider.costContracts,
                    period: entry.key,
                    now: now),
                format),
          const SizedBox(height: 8),
          Text(
              'Calendar estimates from dated prices; currencies stay separate.',
              style: theme.textTheme.bodySmall),
        ],
      ]),
    );
  }

  Widget _costOverviewRow(CostPeriod period, String label, CostSummary summary,
      NumberFormat format) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 88, child: Text(label)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (summary.isEmpty)
            const Text('No estimated costs')
          else
            for (final entry in summary.byCurrency.entries)
              Text(
                  '${entry.key.isEmpty ? 'Unknown currency' : entry.key} ${format.format(entry.value)}',
                  key: ValueKey('cost.${period.name}.${entry.key}'),
                  style: Theme.of(context).textTheme.titleSmall),
          if (summary.excludedCount > 0)
            Text(
                '${summary.excludedCount} to review: missing or invalid billing data',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall),
        ])),
      ]),
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
