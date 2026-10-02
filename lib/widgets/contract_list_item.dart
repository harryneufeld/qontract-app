import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/contract.dart';

class ContractListItem extends StatelessWidget {
  final Contract contract;
  final VoidCallback? onTap;

  /// Name of the linked contractor (resolved by the caller via
  /// [ContractorProvider]); shown as subtitle when the contract has no
  /// description.
  final String? contractorName;

  const ContractListItem({
    super.key,
    required this.contract,
    this.onTap,
    this.contractorName,
  });

  @override
  Widget build(BuildContext context) {
    final color = ContractStatusStyle.color(context, contract.status);
    final label = ContractStatusStyle.label(contract.status);
    final end = _parseEnd(contract.endDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            Icons.description,
            color: color,
          ),
        ),
        title: Text(
          contract.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((contract.contractNumber ?? '').isNotEmpty)
              Text(
                contract.contractNumber!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            Text(
              contract.subtitle ?? contractorName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (end != null)
              Text(
                '${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')}.${end.year}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  static DateTime? _parseEnd(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } on FormatException {
      return null;
    }
  }
}
