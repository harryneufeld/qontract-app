import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import '../../models/contract.dart';
import '../../models/contractor.dart';
import '../../widgets/app_design.dart';

Map<String, String> get contractFilterStatuses => <String, String>{
      'all': S.current.all,
      'active': S.current.active,
      'inactive': S.current.inactive,
      'expired': S.current.expired,
      'terminated': S.current.terminated,
      'expiring': S.current.endingSoon,
      'minDate': S.current.minimumTerm,
      'priceChanges': S.current.priceChanges,
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
  late String status = contractFilterStatuses.containsKey(widget.initial.status)
      ? widget.initial.status
      : 'all';
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
                      child: Text(context.l10n.filterContracts,
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: context.l10n.closeFilters,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ])),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                        key: ValueKey(resetVersion),
                        child: AppFormColumn(children: [
                          AppDropdown<String>(
                              key: const Key('statusFilter'),
                              initialValue: status,
                              decoration: InputDecoration(
                                  labelText: context.l10n.statusOrAttention),
                              items: [
                                for (final e in contractFilterStatuses.entries)
                                  DropdownMenuItem(
                                      value: e.key, child: Text(e.value))
                              ],
                              onChanged: (value) =>
                                  setState(() => status = value ?? 'all')),
                          AppDropdown<int>(
                              key: const Key('contractorFilter'),
                              initialValue: contractor ?? -1,
                              decoration: InputDecoration(
                                  labelText: context.l10n.contractor),
                              items: [
                                DropdownMenuItem(
                                    value: -1,
                                    child: Text(context.l10n.allContractors)),
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
                          AppDropdown<int>(
                              key: const Key('endingFilter'),
                              initialValue: ending ?? 0,
                              decoration: InputDecoration(
                                  labelText: context.l10n.endDate),
                              items: [
                                DropdownMenuItem(
                                    value: 0,
                                    child: Text(context.l10n.anyEndDate)),
                                DropdownMenuItem(
                                    value: 30,
                                    child: Text(context.l10n.next30Days)),
                                DropdownMenuItem(
                                    value: 90,
                                    child: Text(context.l10n.next90Days)),
                                DropdownMenuItem(
                                    value: 365,
                                    child: Text(context.l10n.next12Months)),
                              ],
                              onChanged: (value) => setState(
                                  () => ending = value == 0 ? null : value)),
                          AppDropdown<String>(
                              key: const Key('typeFilter'),
                              initialValue: type ?? '',
                              decoration: InputDecoration(
                                  labelText: context.l10n.contractType),
                              items: [
                                DropdownMenuItem(
                                    value: '',
                                    child: Text(context.l10n.allTypes)),
                                for (final t in widget.types)
                                  DropdownMenuItem(
                                      value: t,
                                      child: Text(contractTypes[t] ?? t)),
                              ],
                              onChanged: (value) => setState(
                                  () => type = value == '' ? null : value)),
                          AppDropdown<String>(
                              key: const Key('periodFilter'),
                              initialValue: period ?? '',
                              decoration: InputDecoration(
                                  labelText: context.l10n.billingPeriod292),
                              items: [
                                DropdownMenuItem(
                                    value: '',
                                    child: Text(context.l10n.allPeriods)),
                                for (final e in billingPeriods.entries)
                                  DropdownMenuItem(
                                      value: e.key, child: Text(e.value)),
                                DropdownMenuItem(
                                    value: '__unknown__',
                                    child: Text(context.l10n.unknownPeriod)),
                              ],
                              onChanged: (value) => setState(
                                  () => period = value == '' ? null : value)),
                          SwitchListTile.adaptive(
                              key: const Key('reviewBillingFilter'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(context.l10n.billingDetailsToReview),
                              subtitle: Text(context.l10n
                                  .missingAmountsUnknownPeriodsOrInvalidPriceDates),
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
                            tooltip: context.l10n.resetFilters,
                            onPressed: reset,
                            icon: const Icon(Icons.restart_alt)),
                        IconButton(
                            tooltip: context.l10n.cancelFilters,
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close)),
                      ] else ...[
                        TextButton(
                            onPressed: reset, child: Text(context.l10n.reset)),
                        OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(context.l10n.cancel)),
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
                          child: Text(context.l10n.applyFilters)),
                    ])),
          ]));
}
