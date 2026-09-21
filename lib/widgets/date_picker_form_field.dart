import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A form field that combines manual date entry with a calendar picker.
///
/// The user can either type a date directly in YYYY-MM-DD format or tap the
/// calendar icon to open a [showDatePicker] dialog. The text input is
/// continuously validated and the controller text is always kept as a
/// normalized ISO date string when a valid date is chosen.
class DatePickerFormField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?>? onDateSelected;

  const DatePickerFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.helperText,
    this.validator,
    this.firstDate,
    this.lastDate,
    this.onDateSelected,
  });

  @override
  State<DatePickerFormField> createState() => _DatePickerFormFieldState();
}

class _DatePickerFormFieldState extends State<DatePickerFormField> {
  final DateFormat _displayFormat = DateFormat('yyyy-MM-dd');

  Future<void> _pickDate() async {
    final initialDate = _parseCurrent() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: widget.firstDate ?? DateTime(2000),
      lastDate: widget.lastDate ?? DateTime(2100),
    );
    if (picked != null) {
      final formatted = _displayFormat.format(picked);
      widget.controller.text = formatted;
      widget.onDateSelected?.call(picked);
      // Trigger validation update so dependent fields re-validate
      FormFieldState<String>? field = context.findAncestorStateOfType<FormFieldState<String>>();
      field?.didChange(formatted);
      field?.validate();
    }
  }

  DateTime? _parseCurrent() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return null;
    try {
      return DateTime.parse(text);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText ?? 'YYYY-MM-DD (optional)',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: _pickDate,
          tooltip: 'Pick date',
        ),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty && DateTime.tryParse(value) == null) {
          return '${widget.labelText} must be a valid date (YYYY-MM-DD)';
        }
        if (widget.validator != null) {
          return widget.validator!(value);
        }
        return null;
      },
    );
  }
}
