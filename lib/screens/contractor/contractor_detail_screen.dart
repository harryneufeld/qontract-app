import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contractor.dart';
import '../../providers/contract_provider.dart';
import '../../widgets/contract_list_item.dart';

class ContractorDetailScreen extends StatelessWidget {
  const ContractorDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contractor = ModalRoute.of(context)?.settings.arguments as Contractor?;
    if (contractor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contractor')),
        body: const Center(child: Text('No contractor selected')),
      );
    }

    return _ContractorDetailView(contractor: contractor);
  }
}

class _ContractorDetailView extends StatefulWidget {
  final Contractor contractor;

  const _ContractorDetailView({required this.contractor});

  @override
  State<_ContractorDetailView> createState() => _ContractorDetailViewState();
}

class _ContractorDetailViewState extends State<_ContractorDetailView> {
  @override
  Widget build(BuildContext context) {
    final contracts = context.watch<ContractProvider>().contracts
        .where((c) => c.contractorId == widget.contractor.id)
        .toList();

    final chipColor = widget.contractor.type == ContractorType.company
        ? Theme.of(context).colorScheme.primary
        : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contractor.name),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.contractor.type == ContractorType.company
                          ? Icons.business
                          : Icons.person,
                      color: chipColor,
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(widget.contractor.typeLabel),
                      backgroundColor: chipColor.withValues(alpha: 0.1),
                      side: BorderSide(color: chipColor),
                    ),
                  ],
                ),
                if (widget.contractor.contactInfo != null &&
                    widget.contractor.contactInfo!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.contractor.contactInfo!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Contracts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: contracts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No contracts for this contractor',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: contracts.length,
                    itemBuilder: (context, index) {
                      return ContractListItem(
                        contract: contracts[index],
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/contract/detail',
                            arguments: contracts[index],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
