import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/contract.dart';
import '../../providers/contract_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/contract_user_filter.dart';
import '../../services/api_service.dart';
import '../../widgets/app_design.dart';

class ContractTrashScreen extends StatefulWidget {
  final ApiService? api;
  final String initialScope;
  const ContractTrashScreen(
      {super.key, this.api, this.initialScope = 'tenant'});
  @override
  State<ContractTrashScreen> createState() => _ContractTrashScreenState();
}

class _ContractTrashScreenState extends State<ContractTrashScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  List<Contract> _contracts = [];
  bool _loading = true;
  int? _restoring;
  String? _error;
  List<Contract> get _visible => _contracts
      .where((c) => matchesContractUser(
          c, widget.initialScope, context.read<AuthProvider?>()?.user?.id))
      .toList();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _api.getContractTrash();
      if (mounted) {
        setState(() {
          _contracts = items;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(Contract contract) async {
    setState(() => _restoring = contract.id);
    try {
      await _api.restoreContract(contract.id);
      if (!mounted) return;
      await context.read<ContractProvider>().refreshContracts();
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _restoring = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Deletion queue')),
        body: AppPage(
            child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  const Text(
                      'Restore contracts before their retention deadline. Inactive contracts are kept in the normal contract list.'),
                  const SizedBox(height: 24),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('Retry'))
                  ],
                  if (!_loading && _error == null && _visible.isEmpty)
                    const Text('No contracts queued for deletion.'),
                  for (final contract in _visible)
                    AppCollectionRow(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(contract.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  if (contract.contractNumber != null)
                                    SelectableText(contract.contractNumber!),
                                  Text(contract.formattedValue),
                                  if (contract.retentionExpiresAt != null)
                                    Text(
                                        'Restore before ${DateFormat.yMMMd().format(contract.retentionExpiresAt!.toLocal())}'),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                      onPressed: _restoring != null ||
                                              contract.retentionExpiresAt !=
                                                      null &&
                                                  !contract.retentionExpiresAt!
                                                      .isAfter(DateTime.now())
                                          ? null
                                          : () => _restore(contract),
                                      icon: const Icon(Icons.restore),
                                      label: Text(_restoring == contract.id
                                          ? 'Restoring…'
                                          : 'Restore')),
                                ]))),
                ]))),
      );
}
