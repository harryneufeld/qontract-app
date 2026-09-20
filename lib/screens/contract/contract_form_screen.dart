import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../models/contract.dart';
import '../../providers/contract_provider.dart';

class ContractFormScreen extends StatefulWidget {
  final Contract? contract;

  const ContractFormScreen({super.key, this.contract});

  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _valueController = TextEditingController();
  final _currencyController = TextEditingController();
  String _status = ContractStatus.active;
  bool _saving = false;

  bool get _isEditing => widget.contract != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    if (c != null) {
      _titleController.text = c.title;
      _descriptionController.text = c.description ?? '';
      _counterpartyController.text = c.counterparty ?? '';
      _startDateController.text = c.startDate ?? '';
      _endDateController.text = c.endDate ?? '';
      _valueController.text = c.value ?? '';
      _currencyController.text = c.currency ?? '';
      _status = c.status;
    } else {
      _currencyController.text = 'EUR';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _counterpartyController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _valueController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  String? _validateDate(String? value, String label) {
    if (value == null || value.isEmpty) return null; // optional
    if (DateTime.tryParse(value) == null) {
      return '$label must be a valid date (YYYY-MM-DD)';
    }
    return null;
  }

  String? _validateValue(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    if (double.tryParse(value.replaceAll(',', '.')) == null) {
      return 'Value must be a number';
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.contract;
    final payload = Contract(
      id: existing?.id ?? 0,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      status: _status,
      startDate: _startDateController.text.trim().isEmpty
          ? null
          : _startDateController.text.trim(),
      endDate: _endDateController.text.trim().isEmpty
          ? null
          : _endDateController.text.trim(),
      counterparty: _counterpartyController.text.trim().isEmpty
          ? null
          : _counterpartyController.text.trim(),
      currency: _currencyController.text.trim().isEmpty
          ? null
          : _currencyController.text.trim().toUpperCase(),
      value: _valueController.text.trim().isEmpty
          ? null
          : _valueController.text.trim(),
      contractorId: existing?.contractorId,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: existing?.updatedAt ?? DateTime.now(),
    );

    setState(() => _saving = true);
    final provider = context.read<ContractProvider>();
    bool ok;
    if (_isEditing) {
      ok = await provider.updateContract(payload);
    } else {
      ok = (await provider.createContract(payload)) != null;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Save failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Contract' : 'Create Contract'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _counterpartyController,
                decoration: const InputDecoration(
                  labelText: 'Counterparty',
                  helperText: 'Who is this contract with?',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDateController,
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        helperText: 'YYYY-MM-DD (optional)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _validateDate(v, 'Start date'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _endDateController,
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        helperText: 'YYYY-MM-DD (optional)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _validateDate(v, 'End date'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _valueController,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: _validateValue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _currencyController,
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final s in ContractStatus.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(ContractStatusStyle.label(s)),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _status = value!);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _handleSave,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : Text(_isEditing
                          ? 'Update Contract'
                          : 'Create Contract'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
