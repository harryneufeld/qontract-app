import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../models/contract.dart';

class ContractStatusBadge extends StatelessWidget {
  final String status;
  const ContractStatusBadge({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final color = ContractStatusStyle.color(context, status);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8)),
        child: Text(ContractStatusStyle.label(status),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color)));
  }
}

class ContractListItem extends StatelessWidget {
  final Contract contract;
  final VoidCallback? onTap;
  final String? contractorName;
  const ContractListItem(
      {super.key, required this.contract, this.onTap, this.contractorName});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = DateTime.tryParse(contract.endDate ?? '');
    final documentLabel = contract.documentCount == null
        ? 'Document count unavailable'
        : '${contract.documentCount} ${contract.documentCount == 1 ? 'document' : 'documents'}';
    return Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(contract.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium),
                                  if (contractorName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(contractorName!,
                                        style: theme.textTheme.bodyMedium),
                                  ],
                                ])),
                            const SizedBox(width: 12),
                            Tooltip(
                                message: documentLabel,
                                excludeFromSemantics: true,
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.attach_file, size: 16),
                                      const SizedBox(width: 4),
                                      Text('${contract.documentCount ?? '—'}',
                                          semanticsLabel: documentLabel,
                                          style: theme.textTheme.bodySmall),
                                    ])),
                          ]),
                      if ((contract.contractNumber ?? '').isNotEmpty ||
                          end != null) ...[
                        const SizedBox(height: 4),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text(contract.contractNumber ?? '',
                                      style: theme.textTheme.bodySmall)),
                              const SizedBox(width: 12),
                              if (end != null)
                                Expanded(
                                    child: Text(
                                        '${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')}.${end.year}',
                                        textAlign: TextAlign.right,
                                        style: theme.textTheme.bodySmall)),
                            ]),
                      ],
                      const SizedBox(height: 8),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: ContractStatusBadge(
                                        status: contract.isActive
                                            ? contract.status
                                            : 'Inactive'))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(contract.formattedValue,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    billingPeriods[contract.billingPeriod] ??
                                        'Unknown period',
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.bodySmall)),
                          ]),
                    ]))));
  }
}
