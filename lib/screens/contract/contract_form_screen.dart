import '../../l10n/strings.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_design.dart';
import '../../widgets/workspace_notice.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../models/contract.dart';
import '../../models/contractor.dart';
import '../../providers/contract_provider.dart';
import '../../providers/contractor_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/date_picker_form_field.dart';
import '../../widgets/decimal_form_field.dart';
import '../../utils/localized_input.dart';

class ContractFormScreen extends StatefulWidget {
  final Contract? contract;
  final ApiService? api;

  const ContractFormScreen({super.key, this.contract, this.api});

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
  String? _billingPeriod = 'Monthly';
  final _priceDateController = TextEditingController();
  final _priceNotesController = TextEditingController();
  int? _selectedContractorId;
  final _contractorQueryController = TextEditingController();
  final _contractorFocusNode = FocusNode();
  bool _creatingContractor = false;
  bool _saving = false;
  bool _currencyEdited = false;
  bool _active = true;
  int? _responsible;
  bool _responsibleChanged = false;
  List<Map<String, dynamic>> _members = [];
  String? _membersError;

  Future<void> _loadMembers() async {
    if (widget.api == null &&
        Provider.of<AuthProvider?>(context, listen: false) == null) {
      return;
    }
    try {
      final members =
          await (widget.api ?? ApiService()).getResponsibleMembers();
      if (mounted) {
        setState(() {
          _members = members;
          _membersError = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _membersError = e.message);
    }
  }

  Future<void> _loadDefaultCurrency() async {
    if (widget.api == null &&
        Provider.of<AuthProvider?>(context, listen: false) == null) {
      return;
    }
    try {
      final currency = await (widget.api ?? ApiService()).getDefaultCurrency();
      if (mounted && !_saving && !_currencyEdited) {
        setState(() => _currencyController.text = currency);
      }
    } on ApiException {
      // The existing EUR form default remains available on older servers.
    }
  }

  bool get _isEditing => widget.contract != null;
  final _ibanController = TextEditingController();
  final _notesController = TextEditingController();
  String? _type;

  @override
  void initState() {
    super.initState();
    _contractorFocusNode.addListener(_onContractorFocusChanged);
    final c = widget.contract;
    _responsible = c?.responsibleUserId ??
        (c == null
            ? Provider.of<AuthProvider?>(context, listen: false)?.user?.id
            : null);
    _active = c?.isActive ?? true;
    if (c != null) {
      _titleController.text = c.title;
      _descriptionController.text = c.description ?? '';
      _ibanController.text = c.iban ?? '';
      _notesController.text = c.notes ?? '';
      _type = c.type;
      _startDateController.text = c.startDate ?? '';
      _endDateController.text = c.endDate ?? '';
      _minContractDateController.text = c.minimumContractDate ?? '';
      _valueController.text = c.value ?? '';
      _currencyController.text = c.currency ?? '';
      _contractNumberController.text = c.contractNumber ?? '';
      _status = c.status;
      _billingPeriod = c.billingPeriod;
      _selectedContractorId = c.contractorId;
    } else {
      _currencyController.text = 'EUR';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMembers();
      if (!_isEditing) _loadDefaultCurrency();
      final contractors = context.read<ContractorProvider>();
      if (contractors.contractors.isEmpty) {
        contractors.fetchContractors();
      }
    });
  }

  @override
  void dispose() {
    _ibanController.dispose();
    _notesController.dispose();
    _priceDateController.dispose();
    _priceNotesController.dispose();
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
        provider.errorMessage ?? context.l10n.couldNotCreateContractor,
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
      return context.l10n.startDateMustBeAValidDateYYYY;
    }
    return null;
  }

  String? _validateEndDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final end = DateTime.tryParse(value);
    if (end == null) {
      return context.l10n.endDateMustBeAValidDateYYYY;
    }
    final startText = _startDateController.text.trim();
    if (startText.isNotEmpty) {
      final start = DateTime.tryParse(startText);
      if (start != null && end.isBefore(start)) {
        return context.l10n.endDateMustBeAfterStartDate;
      }
    }
    return null;
  }

  String? _validateContractNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    if (value.trim().length > 100) {
      return context.l10n.contractNumberMustBeAtMost100Characters;
    }
    return null;
  }

  String? _validateValue(String? value) {
    if (_billingPeriod == null) return null;
    if (value == null || value.isEmpty) return null; // optional
    final canonical = canonicalDecimal(value);
    final amount = canonical == null ? null : double.tryParse(canonical);
    if (amount == null || !amount.isFinite || amount < 0) {
      return context.l10n.useANonNegativeBilledAmount;
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.contract;
    final payload = Contract(
      id: existing?.id ?? 0,
      isActive: _active,
      responsibleUserId:
          _responsibleChanged || !_isEditing ? _responsible : null,
      clearResponsibleUser: _responsibleChanged && _responsible == null,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      status: _status,
      iban: _ibanController.text,
      notes: _notesController.text,
      type: _type,
      clearType: _isEditing && widget.contract!.type != null && _type == null,
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
          : _billingPeriod == null
              ? _valueController.text.trim()
              : canonicalDecimal(_valueController.text),
      billingPeriod: _billingPeriod,
      priceEffectiveFrom:
          _priceDateController.text.isEmpty ? null : _priceDateController.text,
      priceNotes: _priceNotesController.text.isEmpty
          ? null
          : _priceNotesController.text,
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
        _isEditing ? context.l10n.contractUpdated : context.l10n.contractSaved,
        style: ToastStyle.success,
      );
      Navigator.of(context).pop(true);
    } else {
      showToast(
        context,
        provider.errorMessage ?? context.l10n.saveFailed,
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
        title: Text(_isEditing
            ? context.l10n.editContract
            : context.l10n.createContract),
      ),
      body: AppPage(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.section),
            children: [
              AppPageHeading(
                  eyebrow: context.l10n.workspace,
                  title: context.l10n.contractDetails,
                  description:
                      context.l10n.keepTheInformationBehindYourContractsInOne),
              const WorkspaceNotice(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.l10n.title,
                  prefixIcon: const Icon(Icons.title),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.pleaseEnterATitle;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contractNumberController,
                decoration: InputDecoration(
                  labelText: context.l10n.contractNumber316,
                  helperText: context.l10n.optionalEGCNT20260042,
                  prefixIcon: const Icon(Icons.tag),
                  border: const OutlineInputBorder(),
                ),
                maxLength: 100,
                validator: _validateContractNumber,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n.description,
                  prefixIcon: const Icon(Icons.description),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contractorQueryController,
                focusNode: _contractorFocusNode,
                decoration: InputDecoration(
                  labelText: context.l10n.contractor,
                  helperText: context.l10n.searchByNameOrCreateANewContractor,
                  prefixIcon: const Icon(Icons.business),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: _onContractorQueryChanged,
              ),
              if (_contractorFocusNode.hasFocus)
                _buildContractorSuggestions(contractors),
              const SizedBox(height: 16),
              AppFormRow(
                children: [
                  Expanded(
                    child: DatePickerFormField(
                      controller: _startDateController,
                      labelText: context.l10n.startDate319,
                      validator: _validateStartDate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DatePickerFormField(
                      controller: _endDateController,
                      labelText: context.l10n.endDate320,
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
                labelText: context.l10n.minimumContractDate321,
                helperText:
                    context.l10n.optionalEarliestDateThisContractCanEndYYYY,
              ),
              const SizedBox(height: 16),
              AppFormRow(
                children: [
                  Expanded(
                    child: DecimalFormField(
                      normalize: _billingPeriod != null,
                      controller: _valueController,
                      decoration: InputDecoration(
                        labelText: context.l10n.billedAmount,
                        prefixIcon: const Icon(Icons.attach_money),
                        border: const OutlineInputBorder(),
                      ),
                      validator: _validateValue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _currencyController,
                      onChanged: (_) => _currencyEdited = true,
                      decoration: InputDecoration(
                        labelText: context.l10n.currency,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: ValueKey('responsible-${_members.length}'),
                initialValue: _responsible ?? 0,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: context.l10n.responsibleMember),
                items: [
                  DropdownMenuItem(
                      value: 0, child: Text(context.l10n.unassigned)),
                  for (final member in _members)
                    DropdownMenuItem(
                        value: (member['id'] as num).toInt(),
                        child: Text(member['name'] as String)),
                  if (_responsible != null &&
                      !_members.any((m) => m['id'] == _responsible))
                    DropdownMenuItem(
                        value: _responsible,
                        child: Text(widget.contract?.responsibleUserName ??
                            context.l10n.currentMember)),
                ],
                onChanged: _saving
                    ? null
                    : (id) => setState(() {
                          _responsible = id == 0 ? null : id;
                          _responsibleChanged = true;
                        }),
              ),
              if (_membersError != null)
                TextButton.icon(
                    onPressed: _loadMembers,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.retryLoadingTenantMembers)),
              if (_isEditing)
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.contractIsActive),
                    subtitle: Text(context.l10n
                        .inactiveContractsRemainAvailableInTheContractList),
                    value: _active,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _active = value)),
              const SizedBox(height: AppSpace.section),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: const Key('billingPeriod'),
                initialValue: _billingPeriod,
                decoration:
                    InputDecoration(labelText: context.l10n.billingPeriod292),
                items: [
                  if (_billingPeriod == null)
                    DropdownMenuItem(
                        value: null,
                        child: Text(context.l10n.unknownSelectAPeriod)),
                  for (final entry in billingPeriods.entries)
                    DropdownMenuItem(
                        value: entry.key, child: Text(entry.value)),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _billingPeriod = value),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                DatePickerFormField(
                    controller: _priceDateController,
                    labelText: context.l10n.priceEffectiveFromDefaultsToToday),
                TextFormField(
                    controller: _priceNotesController,
                    maxLength: 2000,
                    decoration: InputDecoration(
                        labelText: context.l10n.priceChangeNote)),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: context.l10n.status,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final s in ContractStatus.values
                      .where((s) => s != ContractStatus.draft || s == _status))
                    DropdownMenuItem(
                      value: s,
                      child: Text(ContractStatusStyle.label(s)),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _status = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: const Key('contractType'),
                initialValue: _type ?? '',
                decoration: InputDecoration(
                    labelText: context.l10n.contractType,
                    border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(
                      value: '', child: Text(context.l10n.unclassified)),
                  for (final entry in contractTypes.entries)
                    DropdownMenuItem(
                        value: entry.key, child: Text(entry.value)),
                  if (_type != null && !contractTypes.containsKey(_type))
                    DropdownMenuItem(value: _type, child: Text(_type!)),
                ],
                onChanged: _saving
                    ? null
                    : (value) =>
                        setState(() => _type = value == '' ? null : value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('contractIban'),
                controller: _ibanController,
                decoration: InputDecoration(
                    labelText: context.l10n.iban,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('contractNotes'),
                controller: _notesController,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                    labelText: context.l10n.contractNotes,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _handleSave,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : Text(_isEditing
                          ? context.l10n.updateContract
                          : context.l10n.createContract),
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
    final exactMatchExists =
        contractors.any((c) => c.name.trim().toLowerCase() == lower);
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
              c.typeLabel + (c.isActive ? '' : context.l10n.inactive337),
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
              context.l10n.createAsANewContractor((query)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            enabled: !_creatingContractor,
            onTap: () => _createContractorAndSelect(query),
          ),
        if (visible.isEmpty && (lower.isEmpty || exactMatchExists))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(context.l10n.noMatchingContractors,
                  style: const TextStyle(color: Colors.grey)),
            ),
          ),
      ],
    );
  }
}
