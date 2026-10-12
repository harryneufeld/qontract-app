import '../../services/api_service.dart';
import '../contract/contract_trash_screen.dart';
import '../../widgets/contract_user_filter.dart';
import '../../widgets/app_bottom_actions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../models/contract.dart';
import '../../models/contract_list_query.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contract_provider.dart';
import '../../services/cost_summary.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/app_toast.dart';

/// Tenant-wide overview. Searching and individual rows live on Contracts.
class DashboardScreen extends StatefulWidget {
  final ApiService? api;
  const DashboardScreen({super.key, this.api});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _scope = 'tenant';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    final provider = context.read<ContractProvider>();
    await Future.wait([
      provider.fetchAllContracts(),
      provider.fetchContractTrash(),
    ]);
  }

  void _open({String status = 'all', bool reviewBilling = false}) =>
      Navigator.of(context).pushNamed(AppRoutes.contractList,
          arguments: ContractListQuery(
              status: status, reviewBilling: reviewBilling, scope: _scope));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || auth.isAuthenticated) return;
        showToast(context,
            auth.errorMessage ?? 'Your session expired. Please login again.',
            style: ToastStyle.error, duration: const Duration(seconds: 5));
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
    }
    final provider = context.watch<ContractProvider>();
    final ready = provider.hasFullList &&
        !provider.isLoadingFullList &&
        provider.fullListError == null;
    final all = provider.costContracts
        .where((c) =>
            c.deletedAt == null &&
            matchesContractUser(c, _scope, auth.user?.id))
        .toList();
    final active = all
        .where((c) => c.isActive && c.status == ContractStatus.active)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), actions: [
        IconButton(
            tooltip: 'Workspaces',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.tenants)),
        const SizedBox(width: AppSpace.control),
        IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings)),
        const SizedBox(width: AppSpace.control),
      ]),
      floatingActionButton: AppBottomActions(
          icon: Icons.add,
          tooltip: 'New Contract',
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.contractCreate)),
      drawer: const AppNavigation(selectedRoute: AppRoutes.dashboard),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpace.maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                  16,
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                  112),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPageHeading(
                      eyebrow: auth.user!.isPersonal
                          ? 'Personal contract overview'
                          : _scope == 'mine'
                              ? 'My contract overview'
                              : 'Tenant contract overview',
                      title: 'Your contracts, in focus.',
                      description:
                          'Understand your commitments, costs and what needs attention.',
                    ),
                    const SizedBox(height: AppSpace.section),
                    _contractActions(auth, provider),
                    const SizedBox(height: AppSpace.section),
                    if (!ready)
                      AppPanel(
                          key: const Key('costSection'),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (provider.fullListError != null) ...[
                                  const Text(
                                      'Cost overview unavailable. The complete workspace list could not be loaded.'),
                                  const SizedBox(height: AppSpace.group),
                                  TextButton.icon(
                                      key: const Key('retryCostOverview'),
                                      onPressed: _refresh,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry cost overview')),
                                ] else ...[
                                  const Text(
                                      'Loading all active contract costs…'),
                                  const SizedBox(height: AppSpace.group),
                                  const LinearProgressIndicator(),
                                ],
                              ])),
                    if (ready) ...[
                      _tiles([
                        _metric('statTotal', 'Total', all.length,
                            Icons.description_outlined, () => _open()),
                        _metric(
                            'statActive',
                            'Active',
                            active,
                            Icons.check_circle_outline,
                            () => _open(status: 'active')),
                        _queueCard(),
                        _metric(
                            'statExpired',
                            'Expired',
                            all
                                .where((c) =>
                                    c.isExpired ||
                                    c.status == ContractStatus.expired)
                                .length,
                            Icons.history,
                            () => _open(status: 'expired')),
                      ], columns: 4),
                      const SizedBox(height: AppSpace.page),
                      _costs(all, active),
                      const SizedBox(height: AppSpace.page),
                      Text('Needs attention',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppSpace.group),
                      _attention(
                          'statExpiring',
                          'Ending in the next 30 days',
                          all
                              .where((c) =>
                                  c.isActive &&
                                  c.isExpiringSoon &&
                                  !c.isExpired)
                              .length,
                          Icons.event_outlined,
                          () => _open(status: 'expiring')),
                      const SizedBox(height: AppSpace.group),
                      _attention(
                          'statMinDate',
                          'Minimum term reached or within 90 days',
                          all
                              .where((c) =>
                                  c.isActive &&
                                  c.status == ContractStatus.active &&
                                  c.reachesMinimumContractDateIn())
                              .length,
                          Icons.event_available_outlined,
                          () => _open(status: 'minDate')),
                      const SizedBox(height: AppSpace.group),
                      _attention(
                          'billingReview',
                          'Billing details to review',
                          all.where(needsBillingReview).length,
                          Icons.fact_check_outlined,
                          () => _open(reviewBilling: true)),
                      const SizedBox(height: AppSpace.group),
                      _attention(
                          'priceChanges',
                          'Price changes in the next 30 days',
                          all.where((c) => hasUpcomingPriceChange(c)).length,
                          Icons.trending_up,
                          () => _open(status: 'priceChanges')),
                    ],
                    const SizedBox(height: AppSpace.section),
                  ]),
            ),
          )),
        ),
      ),
    );
  }

  Widget _queueCard() {
    final provider = context.watch<ContractProvider>();
    final count = provider.trashContracts
        ?.where((c) => matchesContractUser(
            c, _scope, context.read<AuthProvider>().user?.id))
        .length;
    return Tooltip(
        message: provider.trashError != null
            ? 'Trash count unavailable. Pull to refresh to retry.'
            : 'Contracts queued for deletion',
        child: _metric(
            'deletionQueue', 'Trash', count, Icons.restore_page_outlined,
            () async {
          await Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => ContractTrashScreen(
                      api: widget.api, initialScope: _scope)));
          if (mounted) await _refresh();
        }));
  }

  Widget _contractActions(AuthProvider auth, ContractProvider provider) => auth
          .user!.isPersonal
      ? const SizedBox.shrink()
      : ContractUserFilter(
          contracts: provider.costContracts,
          currentUserId: auth.user!.id,
          scope: _scope,
          height: 48.0 *
              (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0),
          onChanged: (value) => setState(() => _scope = value));
  Widget _tiles(List<Widget> children, {required int columns}) =>
      LayoutBuilder(builder: (context, constraints) {
        final count = constraints.maxWidth >= 900
            ? columns
            : constraints.maxWidth >= 540 ||
                    (columns == 4 &&
                        constraints.maxWidth >= 280 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 19)
                ? 2
                : 1;
        final width =
            (constraints.maxWidth - AppSpace.group * (count - 1)) / count;
        return Wrap(
            spacing: AppSpace.group,
            runSpacing: AppSpace.group,
            children: children
                .map((child) => SizedBox(width: width, child: child))
                .toList());
      });

  Widget _metric(String key, String label, int? count, IconData icon,
          VoidCallback onTap) =>
      AppPanel(
          padding: EdgeInsets.zero,
          child: InkWell(
            key: Key(key),
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpace.radius),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(count?.toString() ?? '—',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium)),
                        Icon(icon,
                            color: Theme.of(context).colorScheme.primary),
                      ]),
                      const SizedBox(height: AppSpace.control),
                      Text(label,
                          style: Theme.of(context).textTheme.titleMedium),
                    ])),
          ));

  Widget _attention(String key, String title, int count, IconData icon,
          VoidCallback onTap) =>
      AppPanel(
          padding: EdgeInsets.zero,
          child: ListTile(
              key: Key(key),
              onTap: onTap,
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text('$count contracts'),
              trailing: const Icon(Icons.arrow_forward)));

  Widget _costs(List<Contract> contracts, int active) {
    final summaries = computeBillingSums(contracts: contracts);
    return Column(
        key: const Key('costSection'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Costs by billing frequency (active)',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.control),
          Text(
              '$active active contracts · ${context.read<AuthProvider>().user?.isPersonal == true ? 'Personal' : (_scope == 'tenant' ? 'entire tenant' : 'filtered by responsible user')}',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpace.group),
          _tiles([
            for (final entry in billingPeriods.entries)
              if (summaries[entry.key]!.contractCount > 0 ||
                  ['Monthly', 'Quarterly', 'Yearly'].contains(entry.key))
                _costCard(entry.key, entry.value, summaries[entry.key]!)
          ], columns: 3),
        ]);
  }

  Widget _costCard(String period, String label, CostSummary summary) {
    final format = NumberFormat('#,##0.00', 'en');
    final amounts =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (summary.isEmpty) const Text('No current costs'),
      for (final entry in summary.byCurrency.entries)
        Text('${entry.key} ${format.format(entry.value)}',
            key: ValueKey('cost.$period.${entry.key}'),
            style: Theme.of(context).textTheme.titleLarge),
    ]);
    return AppPanel(
        padding: const EdgeInsets.all(16),
        child: MediaQuery.sizeOf(context).width < 600 &&
                MediaQuery.textScalerOf(context).scale(14) <= 19
            ? Row(children: [
                Expanded(
                    child: Text(label,
                        style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(width: 16),
                Expanded(child: amounts),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpace.group),
                amounts,
              ]));
  }
}
