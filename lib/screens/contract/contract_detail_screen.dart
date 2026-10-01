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

  @override
  Widget build(BuildContext context) {
    context.watch<ContractProvider>();
    final contractors = context.watch<ContractorProvider>().contractors;
    final contractor = _findContractor(contractors, contract.contractorId);
    return Scaffold(
      appBar: AppBar(
        title:
            Text(contract.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () {
              Navigator.of(context)
                  .pushNamed('/contract/edit', arguments: contract);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _busy ? null : _confirmDelete,
          ),
        ],
      ),
      body: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBadge(context),
                const SizedBox(height: 16),
                if ((contract.contractNumber ?? '').isNotEmpty) ...[
                  _buildSection(
                      context, 'Contract Number', contract.contractNumber!),
                  const SizedBox(height: 16),
                ],
                if ((contract.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSection(context, 'Description', contract.description!),
                ],
                const SizedBox(height: 16),
                _buildSection(context, 'Value', contract.formattedValue),
                const SizedBox(height: 16),
                _buildDateSection(context),
                const SizedBox(height: 16),
                _buildSection(
                    context,
                    'Created',
                    '${contract.createdAt.toLocal().toString().split(' ').first} '
                        '${contract.createdBy ?? ''}'),
                if (contract.contractorId != null) ...[
                  const SizedBox(height: 16),
                  _buildSection(context, 'Contractor',
                      contractor?.name ?? '#${contract.contractorId}'),
                ],
                const SizedBox(height: 16),
                const Divider(height: 24),
                DocumentsSection(contract: contract),
              ],
            ),
          )),
    );
  }

  Contractor? _findContractor(List<Contractor> contractors, int? id) {
    if (id == null) return null;
    for (final c in contractors) {
      if (c.id == id) return c;
    }
    return null;
  }

  Widget _buildDateSection(BuildContext context) {
    final start = contract.startDate;
    final end = contract.endDate;
    final min = contract.minimumContractDate;
    if ((start == null || start.isEmpty) &&
        (end == null || end.isEmpty) &&
        (min == null || min.isEmpty)) {
      return _buildSection(context, 'Dates', '—');
    }
    final lines = <String>[
      '${start ?? '…'}  →  ${end ?? '…'}',
    ];
    if (min != null && min.isNotEmpty) {
      lines.add('Min. contract date  $min');
    }
    return _buildSection(context, 'Dates', lines.join('\n'));
  }

  Widget _buildStatusBadge(BuildContext context) {
    final color = ContractStatusStyle.color(context, contract.status);
    final label = ContractStatusStyle.label(contract.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
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
            // Theme-aware so the field values stay dark in dark mode
            // (app#33); the old hard-coded Colors.grey[100] was a light
            // background in both modes.
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(content),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Contract'),
        content: Text(
          'Are you sure you want to delete "${contract.title}"? '
          'This action cannot be undone.',
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
