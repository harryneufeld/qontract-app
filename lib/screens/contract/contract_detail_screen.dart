import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contract_provider.dart';
import '../../models/contract.dart';
import '../../models/document.dart';

class ContractDetailScreen extends StatefulWidget {
  final Contract contract;

  const ContractDetailScreen({super.key, required this.contract});

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contract.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).pushNamed('/contract/edit', arguments: widget.contract);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Consumer<ContractProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBadge(),
                const SizedBox(height: 16),
                _buildSection('Description', widget.contract.description),
                const SizedBox(height: 16),
                _buildSection('Value', '${widget.contract.currency} ${widget.contract.value.toStringAsFixed(2)}'),
                const SizedBox(height: 16),
                _buildSection('Expiry Date', widget.contract.expiryDate.toString().split(' ')[0]),
                const SizedBox(height: 16),
                _buildSection('Documents', widget.contract.documents),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color statusColor;
    String statusText;

    switch (widget.contract.status) {
      case 'active':
        statusColor = Colors.green;
        statusText = 'Active';
        break;
      case 'draft':
        statusColor = Colors.blue;
        statusText = 'Draft';
        break;
      case 'expired':
        statusColor = Colors.grey;
        statusText = 'Expired';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusText = widget.contract.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info, size: 20),
          const SizedBox(width: 8),
          Text(
            statusText.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, dynamic content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content is List ? '${content.length} document(s)' : content.toString(),
          ),
        ),
      ],
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contract'),
        content: const Text('Are you sure you want to delete this contract? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<ContractProvider>().deleteContract(widget.contract.id);
              if (mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}