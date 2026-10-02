import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contractor.dart';
import '../../app_routes.dart';
import '../../providers/contractor_provider.dart';
import '../../widgets/app_toast.dart';

/// Create/edit form for a contractor.
///
/// [contractor] is null for create. The form covers the structured contact
/// fields and legacy description, website and notes. The postal address is a
/// separate [Address] record that requires a
/// contractor id, so it is managed on the detail screen, not here.
/// "Deactivate" is a separate destructive action surfaced from the
/// list/detail screens, not part of this form.
class ContractorFormScreen extends StatefulWidget {
  final Contractor? contractor;

  const ContractorFormScreen({super.key, this.contractor});

  @override
  State<ContractorFormScreen> createState() => _ContractorFormScreenState();
}

class _ContractorFormScreenState extends State<ContractorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  ContractorType _type = ContractorType.individual;
  bool _saving = false;

  bool get _isEditing => widget.contractor != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contractor;
    if (c != null) {
      _nameController.text = c.name;
      _emailController.text = c.email ?? '';
      _phoneController.text = c.phone ?? '';
      _websiteController.text = c.website ?? '';
      _descriptionController.text = c.description ?? '';
      _notesController.text = c.notes ?? '';
      _type = c.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a name';
    }
    if (value.trim().length > 100) {
      return 'Name must be at most 100 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // optional
    if (v.length > 200) return 'Email must be at most 200 characters';
    final ok =
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$') // minimal, matches backend check
            .hasMatch(v);
    return ok ? null : 'Please enter a valid email address';
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // optional
    if (v.length > 50) return 'Phone must be at most 50 characters';
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.contractor;
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final payload = Contractor(
      id: existing?.id ?? 0,
      name: _nameController.text.trim(),
      type: _type,
      email: email.isEmpty ? null : email,
      phone: phone.isEmpty ? null : phone,
      website: _websiteController.text,
      description: _descriptionController.text,
      notes: _notesController.text,
      tenantId: existing?.tenantId ?? 0,
      userId: existing?.userId,
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt ?? DateTime.now(),
      modifiedAt: existing?.modifiedAt ?? DateTime.now(),
    );

    setState(() => _saving = true);
    final provider = context.read<ContractorProvider>();
    bool ok;
    Contractor? created;
    if (_isEditing) {
      ok = await provider.updateContractor(payload);
    } else {
      created = await provider.createContractor(payload);
      ok = created != null;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      // Toast on the root ScaffoldMessenger (survives the pop), then back
      // to the caller (app#28).
      showToast(
        context,
        _isEditing ? 'Contractor updated.' : 'Contractor saved.',
        style: ToastStyle.success,
      );
      if (created != null) {
        provider.setSelectedContractor(created);
        Navigator.of(context).pushReplacementNamed(AppRoutes.contractorDetail,
            arguments: created);
      } else {
        Navigator.of(context).pop(true);
      }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Contractor' : 'Add Contractor'),
      ),
      body: AppPage(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.section),
            children: [
              const AppPageHeading(
                  eyebrow: 'Workspace',
                  title: 'Contractor details',
                  description:
                      'Keep the information behind your contracts in one place.'),
              const SizedBox(height: AppSpace.section),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  helperText: 'Who is this contractor?',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ContractorType>(
                isExpanded: true,
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ContractorType.individual,
                    child: Text('Individual'),
                  ),
                  DropdownMenuItem(
                    value: ContractorType.company,
                    child: Text('Company'),
                  ),
                ],
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Optional',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  helperText: 'Optional',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                textCapitalization: TextCapitalization.none,
                validator: _validatePhone,
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('contractorWebsite'),
                controller: _websiteController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Website',
                    helperText: 'Use http:// or https:// to enable opening',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('contractorDescription'),
                controller: _descriptionController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                    labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('contractorNotes'),
                controller: _notesController,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                    labelText: 'Notes', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _handleSave,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : Text(
                          _isEditing ? 'Update Contractor' : 'Add Contractor'),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                Text(
                  'Add or change the postal address from the contractor '
                  'detail page.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
