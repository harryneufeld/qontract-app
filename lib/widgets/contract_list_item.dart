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
    final identity =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(contract.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium),
      if (contractorName != null) ...[
        const SizedBox(height: 4),
        Text(contractorName!, style: theme.textTheme.bodyMedium)
      ],
      if ((contract.contractNumber ?? '').isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(contract.contractNumber!, style: theme.textTheme.bodySmall)
      ],
      if (contract.subtitle != null) ...[
        const SizedBox(height: 4),
        Text(contract.subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
      ],
      if (end != null) ...[
        const SizedBox(height: 8),
        Text(
            '${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')}.${end.year}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
      ],
    ]);
    final billing =
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      ContractStatusBadge(status: contract.status),
      const SizedBox(height: 12),
      Text(contract.formattedValue, style: theme.textTheme.titleMedium),
      Text(billingPeriods[contract.billingPeriod] ?? 'Unknown period',
          style: theme.textTheme.bodySmall),
    ]);
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(builder: (context, size) {
                  if (size.maxWidth >= 600 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 19) {
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.description_outlined,
                                  color: theme.colorScheme.onPrimaryContainer)),
                          const SizedBox(width: 16),
                          Expanded(child: identity),
                          const SizedBox(width: 24),
                          ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: billing),
                          const SizedBox(width: 16),
                          const Icon(Icons.chevron_right),
                        ]);
                  }
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        identity,
                        const SizedBox(height: 16),
                        Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ContractStatusBadge(status: contract.status),
                              Text(contract.formattedValue,
                                  style: theme.textTheme.titleMedium),
                              Text(
                                  billingPeriods[contract.billingPeriod] ??
                                      'Unknown period',
                                  style: theme.textTheme.bodySmall),
                            ]),
                      ]);
                }))));
  }
}
