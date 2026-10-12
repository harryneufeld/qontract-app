import '../../l10n/strings.dart';
import 'package:flutter/material.dart';

import '../../models/address.dart';

/// Collect fields only; the server determines account/tenant ownership.
Future<Address?> showAddressEditorDialog(
  BuildContext context, {
  int? contractorId,
  String entityType = 'Contractor',
  required Address? address,
}) =>
    showDialog<Address>(
      context: context,
      builder: (_) => _AddressEditorDialog(
          contractorId: contractorId, entityType: entityType, address: address),
    );

class _AddressEditorDialog extends StatefulWidget {
  final int? contractorId;
  final String entityType;
  final Address? address;
  const _AddressEditorDialog(
      {this.contractorId, required this.entityType, this.address});

  @override
  State<_AddressEditorDialog> createState() => _AddressEditorDialogState();
}

class _AddressEditorDialogState extends State<_AddressEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _street =
      TextEditingController(text: widget.address?.street ?? '');
  late final _house =
      TextEditingController(text: widget.address?.houseNumber ?? '');
  late final _city = TextEditingController(text: widget.address?.city ?? '');
  late final _zip = TextEditingController(text: widget.address?.zip ?? '');
  late final _country =
      TextEditingController(text: widget.address?.country ?? '');

  @override
  void dispose() {
    for (final c in [_street, _house, _city, _zip, _country]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
        context,
        Address(
            id: widget.address?.id ?? 0,
            entityType: widget.entityType,
            contractorId: widget.contractorId,
            street: _street.text,
            houseNumber: _house.text,
            city: _city.text,
            zip: _zip.text,
            country: _country.text));
  }

  Widget _field(TextEditingController controller, String label, int limit,
          {bool validateContent = false}) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        textInputAction: TextInputAction.next,
        validator: (value) {
          if (validateContent &&
              [_street, _house, _city, _zip, _country]
                  .every((c) => c.text.trim().isEmpty)) {
            return context.l10n.enterAtLeastOneAddressField;
          }
          // Long imported values remain editable verbatim when unchanged.
          final original = identical(controller, _street)
              ? widget.address?.street
              : identical(controller, _house)
                  ? widget.address?.houseNumber
                  : identical(controller, _city)
                      ? widget.address?.city
                      : identical(controller, _zip)
                          ? widget.address?.zip
                          : widget.address?.country;
          if ((value?.length ?? 0) > limit && value != original) {
            return context.l10n.mustBeAtMostCharacters((label), (limit));
          }
          return null;
        },
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.address == null
            ? context.l10n.addAddress
            : context.l10n.editAddress),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _field(_street, context.l10n.street, 500,
                      validateContent: true),
                  const SizedBox(height: 12),
                  _field(_house, context.l10n.houseNumber, 100),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _field(_zip, context.l10n.zip, 20)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_city, context.l10n.city, 100)),
                  ]),
                  const SizedBox(height: 12),
                  _field(_country, context.l10n.country, 100),
                ])),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel)),
          FilledButton(
              onPressed: _save,
              child: Text(widget.address == null
                  ? context.l10n.addAddress
                  : context.l10n.saveAddress)),
        ],
      );
}
