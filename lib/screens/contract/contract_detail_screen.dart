import '../../widgets/contact_action.dart';
import '../../utils/amount_format.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_routes.dart';
import '../../models/contract.dart';
import '../../models/contractor.dart';
import '../../providers/contract_provider.dart';
import '../../providers/contractor_provider.dart';
import '../../providers/document_provider.dart';
import '../../screens/document/documents_section.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_bottom_actions.dart';
import '../../widgets/contract_list_item.dart';
import '../invoice/invoices_screen.dart';

class ContractDetailScreen extends StatefulWidget {
  final Contract contract;
  const ContractDetailScreen({super.key, required this.contract});
  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  bool _busy = false;
  Contract get contract =>
      context.read<ContractProvider>().currentContract(widget.contract);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contracts = context.read<ContractProvider>();
      contracts.setSelectedContract(contracts.currentContract(widget.contract));
      final contractors = context.read<ContractorProvider>();
      if (contract.contractorId != null && contractors.contractors.isEmpty) {
        contractors.fetchContractors();
      }
    });
  }

  Future<void> _refresh() async {
    final contracts = context.read<ContractProvider>();
    final documents = context.read<DocumentProvider>();
    final ok = await contracts.refreshContract(widget.contract.id);
    if (!mounted) return;
    if (!ok) {
      showToast(context, contracts.errorMessage ?? 'Refresh failed.',
          style: ToastStyle.error);
    }
    await documents.loadFor(widget.contract.id, force: true);
  }

  Widget _section(String title, List<Widget> children) =>
      AppDetailSection(title: title, children: children);
  Widget _text(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
      ]));
  Widget _facts(List<(String, String)> facts) =>
      LayoutBuilder(builder: (context, size) {
        final columns = size.maxWidth >= 600 &&
                MediaQuery.textScalerOf(context).scale(14) <= 19
            ? 2
            : 1;
        return Wrap(spacing: 24, runSpacing: 8, children: [
          for (final fact in facts)
            SizedBox(
                width: (size.maxWidth - (columns - 1) * 24) / columns,
                child: _text(fact.$1, fact.$2)),
        ]);
      });
  String _date(DateTime value) => value.toLocal().toString().split(' ').first;
  @override
  Widget build(BuildContext context) {
    context.watch<ContractProvider>();
    final allContractors = context.watch<ContractorProvider>().contractors;
    Contractor? contractor;
    for (final candidate in allContractors) {
      if (candidate.id == contract.contractorId) contractor = candidate;
    }
    final linkedContractor = contractor;
    final theme = Theme.of(context);
    final identity =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('CONTRACT',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.primary, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      Text(contract.title, style: theme.textTheme.headlineMedium),
      const SizedBox(height: 16),
      Text('Contract number', style: theme.textTheme.labelLarge),
      SelectableText(
          (contract.contractNumber ?? '').trim().isEmpty
              ? 'Not recorded'
              : contract.contractNumber!,
          style: theme.textTheme.titleLarge),
      const SizedBox(height: 16),
      Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ContractStatusBadge(
                status: contract.isActive ? contract.status : 'Inactive'),
            Text(contractTypes[contract.type] ??
                contract.type ??
                'Unclassified'),
          ]),
    ]);
    final billing = Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Billed amount',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
          const SizedBox(height: 8),
          SelectableText(contract.formattedValue,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
          const SizedBox(height: 8),
          Text(
              'Billing period: ${billingPeriods[contract.billingPeriod] ?? 'Unknown — review this amount'}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
          if (contract.currency == null || contract.currency!.isEmpty)
            Text('Currency not recorded',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
        ]));
    final main = AppFormColumn(children: [
      _section('Contract information', [
        if ((contract.iban ?? '').isNotEmpty) _text('IBAN', contract.iban!),
        if ((contract.iban ?? '').isEmpty &&
            (contract.description ?? '').isEmpty &&
            (contract.notes ?? '').isEmpty)
          const Text('No additional details recorded.'),
        if ((contract.description ?? '').isNotEmpty)
          _text('Description', contract.description!),
        if ((contract.notes ?? '').isNotEmpty)
          _text('Contract notes', contract.notes!),
      ]),
      if (contract.priceHistory.isNotEmpty)
        _section('Price history', [
          for (final price in contract.priceHistory.reversed)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 12, runSpacing: 4, children: [
                        Text(formatAmount(price.value, price.currency),
                            style: theme.textTheme.titleMedium),
                        Text(billingPeriods[price.billingPeriod] ??
                            'Unknown period'),
                      ]),
                      const SizedBox(height: 6),
                      Text(price.intervalLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      if ((price.notes ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SelectableText(price.notes!)
                      ],
                    ])),
        ]),
      Padding(
          padding: const EdgeInsets.only(top: AppSpace.group),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DocumentsSection(contract: contract),
            if (!contract.isPersonal)
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  InvoicesScreen(contractId: contract.id))),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Invoices for this contract'))),
          ])),
    ]);
    final aside = AppFormColumn(children: [
      _section('Important dates', [
        _facts([
          ('Start date', contract.startDate ?? 'Not recorded'),
          ('End date', contract.endDate ?? 'Not recorded'),
          (
            'Minimum contract date',
            contract.minimumContractDate ?? 'Not recorded'
          ),
          ('Responsible member', contract.responsibleUserName ?? 'Unassigned')
        ]),
      ]),
      _section('Contractor', [
        if (contract.contractorId == null)
          const Text('No contractor linked')
        else if (linkedContractor == null)
          Text('#${contract.contractorId}')
        else ...[
          Text(linkedContractor.name, style: theme.textTheme.titleMedium),
          if ((linkedContractor.email ?? '').trim().isNotEmpty)
            ContactAction(
                value: linkedContractor.email!,
                email: true,
                subject: contract.contractNumber),
          if ((linkedContractor.phone ?? '').trim().isNotEmpty)
            ContactAction(value: linkedContractor.phone!, email: false),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                  context, AppRoutes.contractorDetail,
                  arguments: linkedContractor),
              icon: const Icon(Icons.arrow_outward),
              label: const Text('View contractor')),
        ],
      ]),
      _section('Activity', [
        _facts([
          ('Created', _date(contract.createdAt)),
          ('Last updated', _date(contract.modifiedAt)),
          if ((contract.createdBy ?? '').isNotEmpty)
            ('Created by', contract.createdBy!),
          if ((contract.modifiedBy ?? '').isNotEmpty)
            ('Updated by', contract.modifiedBy!)
        ]),
      ]),
    ]);
    return Scaffold(
        appBar: AppBar(title: const Text('Contract details')),
        floatingActionButton: AppBottomActions(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: _busy
                ? null
                : () => Navigator.pushNamed(context, '/contract/edit',
                    arguments: contract),
            secondary: [
              AppBottomAction(
                  tooltip: 'Delete',
                  onPressed: _busy ? null : _confirmDelete,
                  destructive: true,
                  icon: Icons.delete_outline)
            ]),
        body: RefreshIndicator(
            onRefresh: _refresh,
            child: AppPage(
                maxWidth: AppSpace.maxWidth,
                child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 112),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpace.control),
                              child: LayoutBuilder(
                                  builder: (context, size) => size.maxWidth >=
                                              760 &&
                                          MediaQuery.textScalerOf(context)
                                                  .scale(14) <=
                                              19
                                      ? Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                              Expanded(
                                                  flex: 3, child: identity),
                                              const SizedBox(width: 24),
                                              Expanded(flex: 2, child: billing)
                                            ])
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                              identity,
                                              const SizedBox(height: 24),
                                              billing
                                            ]))),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                              builder: (context, size) =>
                                  size.maxWidth >= 900 &&
                                          MediaQuery.textScalerOf(context)
                                                  .scale(14) <=
                                              19
                                      ? Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                              Expanded(flex: 3, child: main),
                                              const SizedBox(width: 24),
                                              Expanded(flex: 2, child: aside)
                                            ])
                                      : AppFormColumn(children: [
                                          main.children.first,
                                          aside.children.first,
                                          ...main.children.skip(1),
                                          ...aside.children.skip(1),
                                        ])),
                        ])))));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Contract'),
        content: Text(
          'Are you sure you want to delete "${contract.title}"? '
          'You can restore it during the retention period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final provider = context.read<ContractProvider>();
    final ok = await provider.deleteContract(contract.id);
    if (!mounted) return;
    setState(() => _busy = false);

    showToast(
      context,
      ok ? 'Contract deleted.' : (provider.errorMessage ?? 'Delete failed.'),
      style: ok ? ToastStyle.success : ToastStyle.error,
    );
    if (ok) {
      Navigator.of(context).pop(); // back to dashboard
    }
  }
}
