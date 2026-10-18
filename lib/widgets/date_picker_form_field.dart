import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../utils/localized_input.dart';

/// Localized display/manual entry with an invariant ISO controller for callers.
class DatePickerFormField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final bool enabled;
  final FloatingLabelBehavior? floatingLabelBehavior;
  final FormFieldValidator<String>? validator;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?>? onDateSelected;
  const DatePickerFormField(
      {super.key,
      required this.controller,
      required this.labelText,
      this.helperText,
      this.enabled = true,
      this.floatingLabelBehavior,
      this.validator,
      this.firstDate,
      this.lastDate,
      this.onDateSelected});
  @override
  State<DatePickerFormField> createState() => _DatePickerFormFieldState();
}

class _DatePickerFormFieldState extends State<DatePickerFormField> {
  final _display = TextEditingController();
  final _field = GlobalKey<FormFieldState<String>>();
  String _language = 'en';
  bool _changing = false;
  bool _initializedDisplay = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _language = context.l10n.localeName.startsWith('de') ? 'de' : 'en';
    _syncAfterBuild();
  }

  @override
  void didUpdateWidget(DatePickerFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _syncAfterBuild();
    }
  }

  void _syncAfterBuild() {
    if (!_initializedDisplay) {
      _sync();
      _initializedDisplay = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync();
      });
    }
  }

  String _format(DateTime date) => _language == 'de'
      ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().padLeft(4, '0')}'
      : isoDate(date);
  void _sync() {
    if (_changing) return;
    final text = widget.controller.text;
    final date = parseDateInput(text);
    final display = date == null ? text : _format(date);
    if (_display.text != display) _display.text = display;
  }

  void _entered(String text) {
    final date = parseDateInput(text, language: _language);
    _changing = true;
    widget.controller.text = date == null ? text : isoDate(date);
    _changing = false;
    widget.onDateSelected?.call(date);
  }

  Future<void> _pickDate() async {
    final first = widget.firstDate ?? DateTime(2000);
    final last = widget.lastDate ?? DateTime(2100);
    var initial = parseDateInput(widget.controller.text) ?? DateTime.now();
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last);
    if (picked == null || !mounted) return;
    widget.controller.text = isoDate(picked);
    widget.onDateSelected?.call(picked);
    _field.currentState?.didChange(_display.text);
    _field.currentState?.validate();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _display.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        key: _field,
        enabled: widget.enabled,
        controller: _display,
        onChanged: _entered,
        decoration: InputDecoration(
            labelText: widget.labelText,
            floatingLabelBehavior: widget.floatingLabelBehavior,
            helperText: widget.helperText ?? context.l10n.yyyyMMDDOptional,
            helperMaxLines: 4,
            errorMaxLines: 4,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: widget.enabled ? _pickDate : null,
                tooltip: context.l10n.pickDate)),
        validator: (value) {
          final date = parseDateInput(value ?? '', language: _language);
          if ((value?.trim().isNotEmpty ?? false) && date == null) {
            return context.l10n.mustBeAValidDateYYYYMMDD(widget.labelText);
          }
          if (date != null &&
              (widget.firstDate != null &&
                      date.isBefore(DateTime.utc(widget.firstDate!.year,
                          widget.firstDate!.month, widget.firstDate!.day)) ||
                  widget.lastDate != null &&
                      date.isAfter(DateTime.utc(widget.lastDate!.year,
                          widget.lastDate!.month, widget.lastDate!.day)))) {
            return context.l10n
                .invalidDate(_language == 'de' ? 'TT.MM.JJJJ' : 'YYYY-MM-DD');
          }
          return widget.validator?.call(widget.controller.text);
        },
      );
}
