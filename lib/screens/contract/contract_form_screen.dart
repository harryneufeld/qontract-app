import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../models/contract.dart';
import '../../providers/contract_provider.dart';
import '../../providers/contractor_provider.dart';
import '../../widgets/date_picker_form_field.dart';

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
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _valueController = TextEditingController();
  final _currencyController = TextEditingController();
  String _status = ContractStatus.active;
  int? _selectedContractorId;
  bool _saving = false;

  bool get _isEditing => widget.contract != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    if (c != null) {
      _titleController.text = c.title;
      _descriptionController.text = c.description ?? '';
      _startDateController.text = c.startDate ?? '';
      _endDateController.text = c.endDate ?? '';
      _valueController.text = c.value ?? '';
      _currencyController.text = c.currency ?? '';
      _status = c.status;
      _selectedContractorId = c.contractorId;
    } else {
      _currencyController.text = 'EUR';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contractors = context.read<ContractorProvider>();
      if (contractors.contractors.isEmpty) {
        contractors.fetchContractors();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _valueController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  String? _validateStartDate(String? value) {
    if (value == null || value.isEmpty) return null;
    if (DateTime.tryParse(value) == null) {
      return 'Start date must be a valid date (YYYY-MM-DD)';
    }
    return null;
  }

  String? _validateEndDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final end = DateTime.tryParse(value);
    if (end == null) {
      return 'End date must be a valid date (YYYY-MM-DD)';
    }
    final startText = _startDateController.text.trim();
    if (startText.isNotEmpty) {
      final start = DateTime.tryParse(startText);
      if (start != null && end.isBefore(start)) {
        return 'End date must be after start date';
      }
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
      currency: _currencyController.text.trim().isEmpty
          ? null
          : _currencyController.text.trim().toUpperCase(),
      value: _valueController.text.trim().isEmpty
          ? null
          : _valueController.text.trim(),
      contractorId: _selectedContractorId,
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
    final contractors = context.watch<ContractorProvider>().contractors;
    final loadedContractorIds = contractors.map((k) => k.id).toSet();
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
              DropdownButtonFormField<int?>(
                initialValue: _selectedContractorId,
                decoration: const InputDecoration(
                  labelText: 'Contractor',
                  helperText: 'Who is this contract with?',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('None'),
                  ),
                  // Keep the selection visible while the contractor list is
                  // still loading (or if the contractor was removed).
                  if (_selectedContractorId != null &&
                      !loadedContractorIds.contains(_selectedContractorId))
                    DropdownMenuItem<int?>(
                      value: _selectedContractorId,
                      child: Text('Unknown contractor '
                          '(#${_selectedContractorId})'),
                    ),
                  for (final k in contractors)
                    DropdownMenuItem<int?>(
                      value: k.id,
                      child: Text(k.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _selectedContractorId = value);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DatePickerFormField(
                      controller: _startDateController,
                      labelText: 'Start Date',
                      validator: _validateStartDate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DatePickerFormField(
                      controller: _endDateController,
                      labelText: 'End Date',
                      validator: _validateEndDate,
                      onDateSelected: (_) {
                        // Re-validate start date when end date changes so
                        // cross-field errors update reactively.
                        if (_startDateController.text.isNotEmpty) {
                          _formKey.currentState?.validate();
                        }
                      },
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
