import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../models/contract.dart';
import '../../models/contractor.dart';
import '../../providers/contract_provider.dart';
import '../../providers/contractor_provider.dart';
import '../../widgets/app_toast.dart';
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
  final _minContractDateController = TextEditingController();
  final _valueController = TextEditingController();
  final _currencyController = TextEditingController();
  final _contractNumberController = TextEditingController();
  String _status = ContractStatus.active;
  int? _selectedContractorId;
  final _contractorQueryController = TextEditingController();
  final _contractorFocusNode = FocusNode();
  bool _creatingContractor = false;
  bool _saving = false;

  bool get _isEditing => widget.contract != null;

  @override
  void initState() {
    super.initState();
    _contractorFocusNode.addListener(_onContractorFocusChanged);
    final c = widget.contract;
    if (c != null) {
      _titleController.text = c.title;
      _descriptionController.text = c.description ?? '';
      _startDateController.text = c.startDate ?? '';
      _endDateController.text = c.endDate ?? '';
      _minContractDateController.text = c.minimumContractDate ?? '';
      _valueController.text = c.value ?? '';
      _currencyController.text = c.currency ?? '';
      _contractNumberController.text = c.contractNumber ?? '';
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
    _minContractDateController.dispose();
    _valueController.dispose();
    _currencyController.dispose();
    _contractNumberController.dispose();
    _contractorQueryController.dispose();
    _contractorFocusNode.dispose();
    super.dispose();
  }

  void _onContractorFocusChanged() {
    if (mounted) setState(() {});
  }

  /// Keeps [_selectedContractorId] in sync with the query text: the id is
  /// retained only while the text is an exact (case-insensitive) match of an
  /// existing contractor name; otherwise the selection is cleared.
  void _onContractorQueryChanged(String value) {
    final v = value.trim().toLowerCase();
    int? id;
    if (v.isNotEmpty) {
      for (final c in context.read<ContractorProvider>().contractors) {
        if (c.name.trim().toLowerCase() == v) {
          id = c.id;
          break;
        }
      }
    }
    setState(() => _selectedContractorId = id);
  }

  void _selectContractor(Contractor contractor) {
    _contractorQueryController.text = contractor.name;
    _selectedContractorId = contractor.id;
    _contractorFocusNode.unfocus();
    setState(() {});
  }

  /// Quick-create: makes a new contractor from the typed name (type
  /// Individual) and selects it for this contract.
  Future<void> _createContractorAndSelect(String name) async {
    if (_creatingContractor) return;
    setState(() => _creatingContractor = true);
    final provider = context.read<ContractorProvider>();
    final created = await provider.createContractor(
      Contractor(
        id: 0,
        name: name,
        type: ContractorType.individual,
        tenantId: 0,
        isActive: true,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() => _creatingContractor = false);
    if (created == null) {
      showToast(
        context,
        provider.errorMessage ?? 'Could not create contractor.',
        style: ToastStyle.error,
      );
      return;
    }
    _contractorQueryController.text = created.name;
    _selectedContractorId = created.id;
    _contractorFocusNode.unfocus();
    setState(() {});
  }

  Contractor? _contractorById(List<Contractor> contractors, int? id) {
    if (id == null) return null;
    for (final c in contractors) {
      if (c.id == id) return c;
    }
    return null;
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

  String? _validateContractNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    if (value.trim().length > 100) {
      return 'Contract number must be at most 100 characters';
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
      minimumContractDate: _minContractDateController.text.trim().isEmpty
          ? null
          : _minContractDateController.text.trim(),
      currency: _currencyController.text.trim().isEmpty
          ? null
          : _currencyController.text.trim().toUpperCase(),
      value: _valueController.text.trim().isEmpty
          ? null
          : _valueController.text.trim(),
      contractorId: _selectedContractorId,
      contractNumber: _contractNumberController.text.trim().isEmpty
          ? null
          : _contractNumberController.text.trim(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      modifiedAt: existing?.modifiedAt ?? DateTime.now(),
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
      // Toast on the root ScaffoldMessenger (so it survives the pop) and
      // navigate back (app#28).
      showToast(
        context,
        _isEditing ? 'Contract updated.' : 'Contract saved.',
        style: ToastStyle.success,
      );
      Navigator.of(context).pop(true);
    } else {
      showToast(
        context,
        provider.errorMessage ?? 'Save failed.',
        style: ToastStyle.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contractors = context.watch<ContractorProvider>().contractors;
    // On edit, show the linked contractor's name once the list is loaded.
    final selectedContractor =
        _contractorById(contractors, _selectedContractorId);
    if (selectedContractor != null &&
        _contractorQueryController.text.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _contractorQueryController.text.trim().isEmpty) {
          _contractorQueryController.text = selectedContractor.name;
        }
      });
    }
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
                controller: _contractNumberController,
                decoration: const InputDecoration(
                  labelText: 'Contract Number',
                  helperText: 'Optional, e.g. CNT-2026-0042',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
                validator: _validateContractNumber,
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
                controller: _contractorQueryController,
                focusNode: _contractorFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Contractor',
                  helperText:
                      'Search by name or create a new contractor',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: _onContractorQueryChanged,
              ),
              if (_contractorFocusNode.hasFocus)
                _buildContractorSuggestions(contractors),
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
              DatePickerFormField(
                controller: _minContractDateController,
                labelText: 'Minimum Contract Date',
                helperText:
                    'Optional — earliest date this contract can end (YYYY-MM-DD)',
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

  /// Searchable suggestion list for the contractor field (issue #9):
  /// name-filtered matches plus a "create new" row when no exact match
  /// exists, so a missing contractor can be created without leaving the form.
  Widget _buildContractorSuggestions(List<Contractor> contractors) {
    final query = _contractorQueryController.text.trim();
    final lower = query.toLowerCase();
    final matches = lower.isEmpty
        ? contractors
        : contractors
            .where((c) => c.name.toLowerCase().contains(lower))
            .toList();
    final visible = matches.take(6).toList();
    final exactMatchExists = contractors
        .any((c) => c.name.trim().toLowerCase() == lower);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in visible)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Icon(
              c.type == ContractorType.company ? Icons.business : Icons.person,
              size: 20,
              color: c.isActive ? null : Colors.grey[500],
            ),
            title: Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.isActive ? null : Colors.grey[500]),
            ),
            subtitle: Text(
              c.typeLabel + (c.isActive ? '' : ' · Inactive'),
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => _selectContractor(c),
          ),
        if (query.isNotEmpty && !exactMatchExists)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: _creatingContractor
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt, size: 20),
            title: Text(
              'Create "$query" as a new contractor',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            enabled: !_creatingContractor,
            onTap: () => _createContractorAndSelect(query),
          ),
        if (visible.isEmpty && (lower.isEmpty || exactMatchExists))
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('No matching contractors',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }
}
