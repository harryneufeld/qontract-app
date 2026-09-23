import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contractor.dart';
import '../../providers/contractor_provider.dart';

/// Create/edit form for a contractor.
///
/// [contractor] is null for create. The form only covers the fields the
/// backend model actually has (name, type, contact info); "deactivate" is a
/// separate destructive action surfaced from the list/detail screens, not
/// part of this form.
class ContractorFormScreen extends StatefulWidget {
  final Contractor? contractor;

  const ContractorFormScreen({super.key, this.contractor});

  @override
  State<ContractorFormScreen> createState() => _ContractorFormScreenState();
}

class _ContractorFormScreenState extends State<ContractorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactInfoController = TextEditingController();
  ContractorType _type = ContractorType.individual;
  bool _saving = false;

  bool get _isEditing => widget.contractor != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contractor;
    if (c != null) {
      _nameController.text = c.name;
      _contactInfoController.text = c.contactInfo ?? '';
      _type = c.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactInfoController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a name';
    }
    if (value.trim().length > 200) {
      return 'Name must be at most 200 characters';
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.contractor;
    final payload = Contractor(
      id: existing?.id ?? 0,
      name: _nameController.text.trim(),
      type: _type,
      contactInfo: _contactInfoController.text.trim().isEmpty
          ? null
          : _contactInfoController.text.trim(),
      tenantId: existing?.tenantId ?? 0,
      userId: existing?.userId,
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt ?? DateTime.now(),
      modifiedAt: existing?.modifiedAt ?? DateTime.now(),
    );

    setState(() => _saving = true);
    final provider = context.read<ContractorProvider>();
    bool ok;
    if (_isEditing) {
      ok = await provider.updateContractor(payload);
    } else {
      ok = (await provider.createContractor(payload)) != null;
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
        title: Text(_isEditing ? 'Edit Contractor' : 'Add Contractor'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  helperText: 'Who is this contractor?',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
                textCapitalization: TextCapitalization.words,
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ContractorType>(
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
                controller: _contactInfoController,
                decoration: const InputDecoration(
                  labelText: 'Contact Info',
                  helperText:
                      'Optional — e.g. email, phone or website (one line)',
                  prefixIcon: Icon(Icons.contact_page),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
                          ? 'Update Contractor'
                          : 'Add Contractor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
