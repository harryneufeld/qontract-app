import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contract_provider.dart';
import '../../models/contract.dart';

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
  final _expiryDateController = TextEditingController();
  final _valueController = TextEditingController();
  final _currencyController = TextEditingController();
  String _status = 'draft';

  @override
  void initState() {
    super.initState();
    if (widget.contract != null) {
      _titleController.text = widget.contract!.title;
      _descriptionController.text = widget.contract!.description;
      _expiryDateController.text = widget.contract!.expiryDate.toIso8601String().split('T')[0];
      _valueController.text = widget.contract!.value.toString();
      _currencyController.text = widget.contract!.currency ?? 'USD';
      _status = widget.contract!.status;
    } else {
      _currencyController.text = 'USD';
      _expiryDateController.text = DateTime.now().add(const Duration(days: 365)).toIso8601String().split('T')[0];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _expiryDateController.dispose();
    _valueController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final contract = Contract(
      id: widget.contract?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      description: _descriptionController.text,
      createdAt: widget.contract?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      documents: widget.contract?.documents ?? [],
      status: _status,
      expiryDate: DateTime.parse(_expiryDateController.text),
      value: double.tryParse(_valueController.text) ?? 0,
      currency: _currencyController.text,
    );

    try {
      if (widget.contract == null) {
        await context.read<ContractProvider>().createContract(contract);
      } else {
        await context.read<ContractProvider>().updateContract(contract.id, contract);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contract == null ? 'Create Contract' : 'Edit Contract'),
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
                  if (value == null || value.isEmpty) {
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
                controller: _expiryDateController,
                decoration: const InputDecoration(
                  labelText: 'Expiry Date',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(
                  labelText: 'Value',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currencyController,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  prefixIcon: Icon(Icons.currency_exchange),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'expired', child: Text('Expired')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (value) {
                  setState(() => _status = value!);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(widget.contract == null ? 'Create Contract' : 'Update Contract'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}