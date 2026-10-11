import '../../widgets/contract_user_filter.dart';
import 'contract_trash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/contractor_provider.dart';
import '../../widgets/contract_list_item.dart';
import '../../widgets/app_bottom_actions.dart';
import '../../app_routes.dart';
import '../../widgets/app_toast.dart';
import '../../services/cost_summary.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/app_design.dart';
import 'contract_filter_sheet.dart';

class ContractListScreen extends StatefulWidget {
  final String initialFilter;
  final bool reviewBilling;
  final String initialScope;
  const ContractListScreen(
      {super.key,
      this.initialFilter = 'all',
      this.initialScope = 'tenant',
      this.reviewBilling = false});
  @override
  State<ContractListScreen> createState() => _ContractListScreenState();
}

class _ContractListScreenState extends State<ContractListScreen> {
  final _searchController = TextEditingController();
  late ContractFilters _filters = ContractFilters(
      status: widget.initialFilter, reviewBilling: widget.reviewBilling);
  String _sort = 'title';
  late String _scope = widget.initialScope;
  String _apiFilter(String status) => [
        'all',
        'active',
        'inactive',
        'expired',
        'expiring',
        'minDate'
      ].contains(status)
          ? status
          : 'all';
  bool get _searching => _searchController.text.trim().isNotEmpty;
  bool get _needsCompleteList =>
      _scope != 'tenant' ||
      _searching ||
      _filters.additionalCount > 0 ||
      _sort != 'title' ||
      ['draft', 'terminated', 'priceChanges', 'minDate']
          .contains(_filters.status);
  bool get _hasFilters =>
      _scope != 'tenant' ||
      _searching ||
      _filters.status != 'all' ||
      _filters.additionalCount > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ContractProvider>();
      if (provider.statusFilter == _apiFilter(_filters.status)) {
        provider.fetchContracts();
      } else {
        provider.applyStatusFilter(_apiFilter(_filters.status));
      }
      provider.fetchAllContracts();
      final contractors = context.read<ContractorProvider>();
      if (contractors.contractors.isEmpty) contractors.fetchContractors();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _apply(ContractFilters filters) {
    setState(() => _filters = filters);
    context
        .read<ContractProvider>()
        .applyStatusFilter(_apiFilter(filters.status));
  }

  void _clear() {
    _searchController.clear();
    setState(() {
      _sort = 'title';
      _scope = 'tenant';
    });
    _apply(const ContractFilters());
  }

  ContractFilters _copy(
          {String? status,
          bool clearContractor = false,
          bool clearEnding = false,
          bool clearType = false,
          bool clearPeriod = false,
          bool clearReview = false}) =>
      ContractFilters(
          status: status ?? _filters.status,
          contractorId: clearContractor ? null : _filters.contractorId,
          endingDays: clearEnding ? null : _filters.endingDays,
          type: clearType ? null : _filters.type,
          period: clearPeriod ? null : _filters.period,
          reviewBilling: clearReview ? false : _filters.reviewBilling);

  Future<void> _openFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final provider = context.read<ContractProvider>();
    final types = <String>{
      ...contractTypes.keys,
      for (final c in provider.costContracts)
        if (c.type != null && c.type!.isNotEmpty) c.type!,
      if (_filters.type != null) _filters.type!
    }.toList()
      ..sort();
    final sheet = ContractFilterSheet(
        initial: _filters,
        contractors: context.read<ContractorProvider>().contractors,
        types: types);
    final height = MediaQuery.sizeOf(context).height * .9;
    final ContractFilters? result;
    if (MediaQuery.sizeOf(context).width >= 700) {
      result = await showDialog<ContractFilters>(
          context: context,
          builder: (_) => Dialog(
              child: SizedBox(
                  width: 560, height: height.clamp(0, 760), child: sheet)));
    } else {
      result = await showModalBottomSheet<ContractFilters>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => SizedBox(height: height, child: sheet));
    }
    if (result != null && mounted) _apply(result);
  }

  bool _matches(Contract c) {
    final user = context.read<AuthProvider>().user;
    if (!matchesContractUser(c, _scope, user?.id)) return false;
    final statusMatches = switch (_filters.status) {
      'active' => c.isActive && c.status == ContractStatus.active,
      'inactive' => !c.isActive,
      'draft' => c.status == ContractStatus.draft,
      'terminated' => c.status == ContractStatus.terminated,
      'expired' => c.isExpired || c.status == ContractStatus.expired,
      'expiring' => c.isActive && c.isExpiringSoon && !c.isExpired,
      'minDate' => c.isActive &&
          c.status == ContractStatus.active &&
          c.reachesMinimumContractDateIn(),
      'priceChanges' => hasUpcomingPriceChange(c),
      _ => true,
    };
    if (!statusMatches || (_filters.reviewBilling && !needsBillingReview(c))) {
      return false;
    }
    if (_filters.contractorId != null &&
        c.contractorId != _filters.contractorId) {
      return false;
    }
    if (_filters.type != null && c.type != _filters.type) return false;
    if (_filters.period == '__unknown__') {
      if (billingPeriods.containsKey(c.billingPeriod)) return false;
    } else if (_filters.period != null && c.billingPeriod != _filters.period) {
      return false;
    }
    if (_filters.endingDays != null) {
      final date = DateTime.tryParse(c.endDate ?? '');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (c.status != ContractStatus.active ||
          date == null ||
          date.isBefore(today) ||
          date.isAfter(today.add(Duration(days: _filters.endingDays!)))) {
        return false;
      }
    }
    return true;
  }

  Color _filterColor(String status) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (status) {
      'active' => dark ? Colors.green.shade300 : Colors.green.shade800,
      'draft' => dark ? Colors.blue.shade300 : Colors.blue.shade800,
      'expired' => dark ? Colors.grey.shade400 : Colors.grey.shade700,
      'terminated' => dark ? Colors.red.shade300 : Colors.red.shade800,
      'expiring' => dark ? Colors.amber.shade300 : Colors.amber.shade900,
      _ => Theme.of(context).colorScheme.primary,
    };
  }

  Widget _controls(Map<int, String> names) {
    final search = TextField(
        key: const Key('contractSearch'),
        controller: _searchController,
        decoration: InputDecoration(
            hintText: 'Search contracts...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _searchController.clear()))
                : null),
        onChanged: (_) => setState(() {}));
    final actions = Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
              key: const Key('openFilters'),
              onPressed: _openFilters,
              icon: const Icon(Icons.tune),
              label: Text(_filters.additionalCount == 0
                  ? 'Filters'
                  : 'Filters (${_filters.additionalCount})')),
          PopupMenuButton<String>(
              tooltip: 'Sort contracts',
              initialValue: _sort,
              onSelected: (value) => setState(() => _sort = value),
              itemBuilder: (_) => const [
                    PopupMenuItem(value: 'title', child: Text('Name A–Z')),
                    PopupMenuItem(value: 'end', child: Text('Ending soon')),
                    PopupMenuItem(
                        value: 'updated', child: Text('Recently updated')),
                  ],
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.sort),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(switch (_sort) {
                      'title' => 'Name A–Z',
                      'end' => 'Ending soon',
                      'updated' => 'Recently updated',
                      _ => 'Sort',
                    }))
                  ]))),
        ]);
    final statuses = <String, String>{
      'all': 'statTotal',
      'active': 'statActive',
      'draft': 'statDraft',
      'expired': 'statExpired',
      'terminated': 'statTerminated',
      if (['expiring', 'minDate', 'priceChanges'].contains(_filters.status))
        _filters.status: _filters.status == 'expiring'
            ? 'statExpiring'
            : _filters.status == 'minDate'
                ? 'statMinDate'
                : 'statPriceChanges'
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(
          builder: (context, size) => size.maxWidth >= 650 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 19
              ? Row(children: [
                  Expanded(child: search),
                  const SizedBox(width: 16),
                  actions
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [search, const SizedBox(height: 12), actions])),
      const SizedBox(height: 16),
      if (context.read<AuthProvider>().user?.isPersonal == false) ...[
        ContractUserFilter(
            contracts: context.watch<ContractProvider>().costContracts,
            scope: _scope,
            onChanged: (value) => setState(() => _scope = value)),
        const SizedBox(height: 8),
      ],
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final entry in statuses.entries)
          FilterChip(
              key: Key(entry.value),
              label: Text(contractFilterStatuses[entry.key]!),
              labelStyle: TextStyle(color: _filterColor(entry.key)),
              checkmarkColor: _filterColor(entry.key),
              selectedColor: _filterColor(entry.key).withValues(alpha: .14),
              side: BorderSide(
                  color: _filterColor(entry.key).withValues(alpha: .45)),
              selected: _filters.status == entry.key,
              onSelected: (_) => _apply(_copy(
                  status: _filters.status == entry.key ? 'all' : entry.key))),
      ]),
      if (_hasFilters) ...[
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_filters.contractorId != null)
                InputChip(
                    label: Text(names[_filters.contractorId] ??
                        '#${_filters.contractorId}'),
                    onDeleted: () => _apply(_copy(clearContractor: true))),
              if (_filters.endingDays != null)
                InputChip(
                    label: Text('Ends within ${_filters.endingDays} days'),
                    onDeleted: () => _apply(_copy(clearEnding: true))),
              if (_filters.type != null)
                InputChip(
                    label: Text(contractTypes[_filters.type] ?? _filters.type!),
                    onDeleted: () => _apply(_copy(clearType: true))),
              if (_filters.period != null)
                InputChip(
                    label: Text(
                        billingPeriods[_filters.period] ?? 'Unknown period'),
                    onDeleted: () => _apply(_copy(clearPeriod: true))),
              if (_filters.reviewBilling)
                InputChip(
                    label: const Text('Billing details to review'),
                    onDeleted: () => _apply(_copy(clearReview: true))),
              TextButton(
                  key: const Key('clearFilters'),
                  onPressed: _clear,
                  child: const Text('Clear all')),
            ]),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Contracts'), actions: [
        IconButton(
            tooltip: 'Contract trash',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const ContractTrashScreen()))),
      ]),
      drawer: Navigator.of(context).canPop()
          ? null
          : const AppNavigation(selectedRoute: AppRoutes.contractList),
      floatingActionButton: AppBottomActions(
          icon: Icons.add,
          tooltip: 'New Contract',
          onPressed: () => Navigator.pushNamed(context, '/contract/create')),
      body: Consumer3<AuthProvider, ContractProvider, ContractorProvider>(
          builder: (context, auth, provider, contractors, _) {
        if (!auth.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || auth.isAuthenticated) return;
            showToast(
                context,
                auth.errorMessage ??
                    'Your session expired. Please login again.',
                style: ToastStyle.error);
            Navigator.pushReplacementNamed(context, '/login');
          });
        }
        final names = {for (final c in contractors.contractors) c.id: c.name};
        final completePending = _needsCompleteList &&
            (!provider.hasFullList ||
                provider.isLoadingFullList ||
                provider.fullListError != null);
        final source = _searching
            ? provider.searchContracts(_searchController.text,
                contractorNames: names)
            : _needsCompleteList
                ? provider.costContracts
                : provider.contracts;
        final visible = source.where(_matches).toList();
        if (_sort == 'title') {
          visible.sort((a, b) {
            final title =
                a.title.toLowerCase().compareTo(b.title.toLowerCase());
            return title == 0 ? a.id.compareTo(b.id) : title;
          });
        }
        if (_sort == 'end') {
          visible.sort((a, b) => (DateTime.tryParse(a.endDate ?? '') ??
                  DateTime(9999))
              .compareTo(DateTime.tryParse(b.endDate ?? '') ?? DateTime(9999)));
        }
        if (_sort == 'updated') {
          visible.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        }
        final total = switch (_filters.status) {
          'all' => provider.stats?.total,
          'active' => provider.stats?.active,
          'expired' => provider.stats?.expired,
          'expiring' => provider.stats?.expiring,
          'minDate' => provider.stats?.minDateApproaching,
          _ => null,
        };
        final loading = completePending || provider.isLoading;
        final error =
            completePending ? provider.fullListError : provider.errorMessage;
        return AppPage(
            maxWidth: AppSpace.maxWidth,
            child: RefreshIndicator(
                onRefresh: provider.refreshContracts,
                child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const AppPageHeading(
                                        eyebrow: 'Contract library',
                                        title: 'Your commitments, in focus.',
                                        description:
                                            'Find the right contract. Keep every detail within reach.'),
                                    const SizedBox(height: 24),
                                    _controls(names),
                                    const SizedBox(height: 24),
                                    Text(
                                        loading
                                            ? 'Preparing results…'
                                            : _needsCompleteList
                                                ? '${visible.length} ${visible.length == 1 ? 'result' : 'results'}'
                                                : total == null
                                                    ? '${visible.length} contracts loaded'
                                                    : '${visible.length} of $total contracts',
                                        key: const Key('resultCount'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge),
                                  ]))),
                      if (loading || error != null)
                        SliverToBoxAdapter(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppPanel(
                                    child: Column(children: [
                                  Text((error != null && _needsCompleteList
                                          ? 'Complete results unavailable. Please retry.'
                                          : error) ??
                                      (_needsCompleteList
                                          ? 'Loading all contracts…'
                                          : 'Loading contracts…')),
                                  const SizedBox(height: 16),
                                  if (error == null)
                                    const CircularProgressIndicator()
                                  else
                                    TextButton(
                                        onPressed: _needsCompleteList
                                            ? provider.fetchAllContracts
                                            : provider.fetchContracts,
                                        child: const Text('Retry')),
                                ]))))
                      else if (visible.isEmpty)
                        SliverToBoxAdapter(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppPanel(
                                    child: Column(children: [
                                  Icon(
                                      _hasFilters
                                          ? Icons.search_off
                                          : Icons.description_outlined,
                                      size: 40,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(height: 16),
                                  Text(
                                      _hasFilters
                                          ? 'No matches'
                                          : 'No contracts yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 8),
                                  Text(_hasFilters
                                      ? 'Try a different search term or clear the filters'
                                      : 'Create your first contract'),
                                ]))))
                      else ...[
                        SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverList.builder(
                                itemCount: visible.length,
                                itemBuilder: (context, index) =>
                                    ContractListItem(
                                        contract: visible[index],
                                        contractorName:
                                            names[visible[index].contractorId],
                                        onTap: () {
                                          provider.setSelectedContract(
                                              visible[index]);
                                          Navigator.pushNamed(
                                              context, '/contract/detail',
                                              arguments: visible[index]);
                                        }))),
                        if (provider.hasMore && !_needsCompleteList)
                          SliverToBoxAdapter(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                      child: provider.isLoadingMore
                                          ? const CircularProgressIndicator()
                                          : OutlinedButton.icon(
                                              key: const Key('loadMore'),
                                              onPressed: provider.loadMore,
                                              icon:
                                                  const Icon(Icons.expand_more),
                                              label:
                                                  const Text('Load more'))))),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 112)),
                    ])));
      }));
}
