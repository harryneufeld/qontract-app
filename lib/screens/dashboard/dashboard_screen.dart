import '../../l10n/strings.dart';
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
        showToast(
            context,
            auth.errorMessage ??
                context.l10n.yourSessionExpiredPleaseLoginAgain,
            style: ToastStyle.error,
            duration: const Duration(seconds: 5));
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
      appBar: AppBar(title: Text(context.l10n.dashboard), actions: [
        IconButton(
            tooltip: context.l10n.workspaces,
            icon: const Icon(Icons.groups_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.tenants)),
        const SizedBox(width: AppSpace.control),
        IconButton(
            tooltip: context.l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings)),
        const SizedBox(width: AppSpace.control),
      ]),
      floatingActionButton: AppBottomActions(
          icon: Icons.add,
          tooltip: context.l10n.newContract,
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
                          ? context.l10n.personalContractOverview
                          : _scope == 'mine'
                              ? context.l10n.myContractOverview
                              : context.l10n.tenantContractOverview,
                      title: context.l10n.yourContractsInFocus,
                      description: context.l10n
                          .understandYourCommitmentsCostsAndWhatNeedsAttention,
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
                                  Text(context.l10n
                                      .costOverviewUnavailableTheCompleteWorkspaceListCould),
                                  const SizedBox(height: AppSpace.group),
                                  TextButton.icon(
                                      key: const Key('retryCostOverview'),
                                      onPressed: _refresh,
                                      icon: const Icon(Icons.refresh),
                                      label:
                                          Text(context.l10n.retryCostOverview)),
                                ] else ...[
                                  Text(context
                                      .l10n.loadingAllActiveContractCosts),
                                  const SizedBox(height: AppSpace.group),
                                  const LinearProgressIndicator(),
                                ],
                              ])),
                    if (ready) ...[
                      _tiles([
                        _metric('statTotal', context.l10n.total, all.length,
                            Icons.description_outlined, () => _open()),
                        _metric(
                            'statActive',
                            context.l10n.active,
                            active,
                            Icons.check_circle_outline,
                            () => _open(status: 'active')),
                        _queueCard(),
                        _metric(
                            'statExpired',
                            context.l10n.expired,
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
                      Text(context.l10n.needsAttention,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppSpace.group),
                      _attention(
                          'statExpiring',
                          context.l10n.endingInTheNext30Days,
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
                          context.l10n.minimumTermReachedOrWithin90Days,
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
                          context.l10n.billingDetailsToReview,
                          all.where(needsBillingReview).length,
                          Icons.fact_check_outlined,
                          () => _open(reviewBilling: true)),
                      const SizedBox(height: AppSpace.group),
                      _attention(
                          'priceChanges',
                          context.l10n.priceChangesInTheNext30Days,
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
            ? context.l10n.trashCountUnavailablePullToRefreshToRetry
            : context.l10n.contractsQueuedForDeletion,
        child: _metric('deletionQueue', context.l10n.trash, count,
            Icons.restore_page_outlined, () async {
          await Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => ContractTrashScreen(
                      api: widget.api, initialScope: _scope)));
          if (mounted) await _refresh();
        }));
  }

  Widget _contractActions(AuthProvider auth, ContractProvider provider) =>
      auth.user!.isPersonal
          ? const SizedBox.shrink()
          : ContractUserFilter(
              contracts: provider.costContracts,
              currentUserId: auth.user!.id,
              scope: _scope,
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
              subtitle: Text(context.l10n.attentionContractCount((count))),
              trailing: const Icon(Icons.arrow_forward)));

  Widget _costs(List<Contract> contracts, int active) {
    final summaries = computeBillingSums(contracts: contracts);
    return Column(
        key: const Key('costSection'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.costsByBillingFrequencyActive,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.control),
          Text(
              context.l10n.activeContracts(
                  (active),
                  (context.read<AuthProvider>().user?.isPersonal == true
                      ? context.l10n.personal
                      : (_scope == 'tenant'
                          ? context.l10n.entireTenant
                          : context.l10n.filteredByResponsibleUser))),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpace.group),
          LayoutBuilder(builder: (context, constraints) {
            final cards = [
              for (final entry in billingPeriods.entries)
                if (summaries[entry.key]!.contractCount > 0 ||
                    ['Monthly', 'Quarterly', 'Yearly'].contains(entry.key))
                  _costCard(entry.key, entry.value, summaries[entry.key]!)
            ];
            return constraints.maxWidth < 540
                ? AppCollection(children: cards)
                : _tiles(
                    cards
                        .map((card) =>
                            AppPanel(padding: EdgeInsets.zero, child: card))
                        .toList(),
                    columns: 3);
          }),
        ]);
  }

  Widget _costCard(String period, String label, CostSummary summary) {
    final format = NumberFormat('#,##0.00', S.languageCode);
    final amounts =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (summary.isEmpty) Text(context.l10n.noCurrentCosts),
      for (final entry in summary.byCurrency.entries)
        Text('${entry.key} ${format.format(entry.value)}',
            key: ValueKey('cost.$period.${entry.key}'),
            style: Theme.of(context).textTheme.titleLarge),
    ]);
    return Padding(
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
