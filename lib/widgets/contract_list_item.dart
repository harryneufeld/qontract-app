import 'package:flutter/material.dart';
import '../../models/contract.dart';

class ContractListItem extends StatelessWidget {
  final Contract contract;

  const ContractListItem({super.key, required this.contract});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'draft':
        return Colors.blue;
      case 'expired':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(contract.status).withOpacity(0.2),
          child: Icon(
            Icons.description,
            color: _getStatusColor(contract.status),
          ),
        ),
        title: Text(
          contract.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          contract.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(contract.status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                contract.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(contract.status),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              contract.expiryDate.day.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            Text(
              '${contract.expiryDate.month}/${contract.expiryDate.year}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).pushNamed('/contract/detail', arguments: contract);
        },
      ),
    );
  }
}