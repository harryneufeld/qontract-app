import 'package:flutter/material.dart';
import '../../models/contract.dart';
import '../../models/contractor.dart';
import '../../widgets/app_design.dart';

const contractFilterStatuses = <String, String>{
  'all': 'All',
  'active': 'Active',
  'draft': 'Draft',
  'expired': 'Expired',
  'terminated': 'Terminated',
  'expiring': 'Ending soon',
  'minDate': 'Minimum term',
  'priceChanges': 'Price changes',
};

class ContractFilters {
  final String status;
  final int? contractorId;
  final int? endingDays;
  final String? type;
  final String? period;
  final bool reviewBilling;
  const ContractFilters(
      {this.status = 'all',
      this.contractorId,
      this.endingDays,
      this.type,
      this.period,
      this.reviewBilling = false});
  int get additionalCount =>
      (contractorId == null ? 0 : 1) +
      (endingDays == null ? 0 : 1) +
      (type == null ? 0 : 1) +
      (period == null ? 0 : 1) +
      (reviewBilling ? 1 : 0);
}

/// A draft selection: dismissing the sheet leaves the current view untouched.
class ContractFilterSheet extends StatefulWidget {
  final ContractFilters initial;
  final List<Contractor> contractors;
  final List<String> types;
  const ContractFilterSheet(
      {super.key,
      required this.initial,
      required this.contractors,
      required this.types});
  @override
  State<ContractFilterSheet> createState() => _ContractFilterSheetState();
}

class _ContractFilterSheetState extends State<ContractFilterSheet> {
  late String status = widget.initial.status;
  late int? contractor = widget.initial.contractorId;
  late int? ending = widget.initial.endingDays;
  late String? type = widget.initial.type;
  late String? period = widget.initial.period;
  late bool review = widget.initial.reviewBilling;
  int resetVersion = 0;
  void reset() => setState(() {
        resetVersion++;
        status = 'all';
        contractor = null;
        ending = null;
        type = null;
        period = null;
        review = false;
      });
  @override
  Widget build(BuildContext context) => SafeArea(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                child: Row(children: [
                  Expanded(
                      child: Text('Filter contracts',
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: 'Close filters',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ])),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                        key: ValueKey(resetVersion),
                        child: AppFormColumn(children: [
                          DropdownButtonFormField<String>(
                              key: const Key('statusFilter'),
                              isExpanded: true,
                              initialValue: status,
                              decoration: const InputDecoration(
                                  labelText: 'Status or attention'),
                              items: [
                                for (final e in contractFilterStatuses.entries)
                                  DropdownMenuItem(
                                      value: e.key, child: Text(e.value))
                              ],
                              onChanged: (value) =>
                                  setState(() => status = value ?? 'all')),
                          DropdownButtonFormField<int>(
                              key: const Key('contractorFilter'),
                              isExpanded: true,
                              initialValue: contractor ?? -1,
                              decoration: const InputDecoration(
                                  labelText: 'Contractor'),
                              items: [
                                const DropdownMenuItem(
                                    value: -1, child: Text('All contractors')),
                                if (contractor != null &&
                                    !widget.contractors
                                        .any((c) => c.id == contractor))
                                  DropdownMenuItem(
                                      value: contractor,
                                      child: Text('#$contractor')),
                                for (final c in widget.contractors)
                                  DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name,
                                          overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (value) => setState(() =>
                                  contractor = value == -1 ? null : value)),
                          DropdownButtonFormField<int>(
                              key: const Key('endingFilter'),
                              isExpanded: true,
                              initialValue: ending ?? 0,
                              decoration:
                                  const InputDecoration(labelText: 'End date'),
                              items: const [
                                DropdownMenuItem(
                                    value: 0, child: Text('Any end date')),
                                DropdownMenuItem(
                                    value: 30, child: Text('Next 30 days')),
                                DropdownMenuItem(
                                    value: 90, child: Text('Next 90 days')),
                                DropdownMenuItem(
                                    value: 365, child: Text('Next 12 months')),
                              ],
                              onChanged: (value) => setState(
                                  () => ending = value == 0 ? null : value)),
                          DropdownButtonFormField<String>(
                              key: const Key('typeFilter'),
                              isExpanded: true,
                              initialValue: type ?? '',
                              decoration: const InputDecoration(
                                  labelText: 'Contract type'),
                              items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('All types')),
                                for (final t in widget.types)
                                  DropdownMenuItem(
                                      value: t,
                                      child: Text(contractTypes[t] ?? t)),
                              ],
                              onChanged: (value) => setState(
                                  () => type = value == '' ? null : value)),
                          DropdownButtonFormField<String>(
                              key: const Key('periodFilter'),
                              isExpanded: true,
                              initialValue: period ?? '',
                              decoration: const InputDecoration(
                                  labelText: 'Billing period'),
                              items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('All periods')),
                                for (final e in billingPeriods.entries)
                                  DropdownMenuItem(
                                      value: e.key, child: Text(e.value)),
                                const DropdownMenuItem(
                                    value: '__unknown__',
                                    child: Text('Unknown period')),
                              ],
                              onChanged: (value) => setState(
                                  () => period = value == '' ? null : value)),
                          SwitchListTile.adaptive(
                              key: const Key('reviewBillingFilter'),
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Billing details to review'),
                              subtitle: const Text(
                                  'Missing amounts, unknown periods or invalid price dates'),
                              value: review,
                              onChanged: (value) =>
                                  setState(() => review = value)),
                        ])))),
            Padding(
                padding: const EdgeInsets.all(24),
                child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (MediaQuery.textScalerOf(context).scale(14) > 19) ...[
                        IconButton(
                            tooltip: 'Reset filters',
                            onPressed: reset,
                            icon: const Icon(Icons.restart_alt)),
                        IconButton(
                            tooltip: 'Cancel filters',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close)),
                      ] else ...[
                        TextButton(
                            onPressed: reset, child: const Text('Reset')),
                        OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel')),
                      ],
                      FilledButton(
                          key: const Key('applyFilters'),
                          onPressed: () => Navigator.pop(
                              context,
                              ContractFilters(
                                  status: status,
                                  contractorId: contractor,
                                  endingDays: ending,
                                  type: type,
                                  period: period,
                                  reviewBilling: review)),
                          child: const Text('Apply filters')),
                    ])),
          ]));
}
