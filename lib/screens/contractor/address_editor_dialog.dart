import 'package:flutter/material.dart';

import '../../models/address.dart';

/// A single street/city/zip/country address being edited. Blank means the
/// field is empty.
class _DraftAddress {
  String street;
  String city;
  String zip;
  String country;

  _DraftAddress({
    this.street = '',
    this.city = '',
    this.zip = '',
    this.country = '',
  });

  factory _DraftAddress.from(Address? a) => _DraftAddress(
        street: a?.street ?? '',
        city: a?.city ?? '',
        zip: a?.zip ?? '',
        country: a?.country ?? '',
      );

  bool get isBlank =>
      street.trim().isEmpty &&
      city.trim().isEmpty &&
      zip.trim().isEmpty &&
      country.trim().isEmpty;

  Address toAddress(int contractorId, {int? id}) => Address(
        id: id ?? 0,
        street: street.trim().isEmpty ? null : street.trim(),
        city: city.trim().isEmpty ? null : city.trim(),
        zip: zip.trim().isEmpty ? null : zip.trim(),
        country: country.trim().isEmpty ? null : country.trim(),
        contractorId: contractorId,
      );
}

/// Modal dialog to create ([address] == null) or edit an existing
/// contractor address. Returns an [Address] (with the draft's fields and the
/// given [contractorId]) on save, or null when cancelled.
///
/// The dialog only gathers the fields; the caller (detail screen) decides
/// whether to create or update, so it can wire the provider/snackbar.
Future<Address?> showAddressEditorDialog(
  BuildContext context, {
  required int contractorId,
  required Address? address,
}) {
  return showDialog<Address>(
    context: context,
    builder: (dialogContext) => _AddressEditorDialog(
      contractorId: contractorId,
      address: address,
    ),
  );
}

class _AddressEditorDialog extends StatefulWidget {
  final int contractorId;
  final Address? address;

  const _AddressEditorDialog({
    required this.contractorId,
    required this.address,
  });

  @override
  State<_AddressEditorDialog> createState() => _AddressEditorDialogState();
}

class _AddressEditorDialogState extends State<_AddressEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _draft = _DraftAddress.from(widget.address);
  late final TextEditingController _streetController;
  late final TextEditingController _cityController;
  late final TextEditingController _zipController;
  late final TextEditingController _countryController;

  bool get _isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    _streetController = TextEditingController(text: _draft.street);
    _cityController = TextEditingController(text: _draft.city);
    _zipController = TextEditingController(text: _draft.zip);
    _countryController = TextEditingController(text: _draft.country);
  }

  @override
  void dispose() {
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  String? _validateStreet(String? value) {
    if (value == null || value.trim().isEmpty) return 'Street is required';
    if (value.trim().length > 500) return 'Street must be at most 500 characters';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Sync the draft from the controllers: the draft is initialised from
    // the address being edited, but the user's input lives only in the
    // text controllers — without this, a newly added street was saved as
    // empty and the backend rejected it with "Street is required" (app#33).
    _draft.street = _streetController.text;
    _draft.city = _cityController.text;
    _draft.zip = _zipController.text;
    _draft.country = _countryController.text;
    Navigator.of(context).pop(_draft.toAddress(widget.contractorId,
        id: widget.address?.id));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit address' : 'Add address'),
      content: SizedBox(
        width: 320,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Street',
                  prefixIcon: Icon(Icons.home_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLength: 500,
                validator: _validateStreet,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _zipController,
                      decoration: const InputDecoration(
                        labelText: 'ZIP',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 20,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 100,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child:
                      Text(_isEditing ? 'Save address' : 'Add address'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
