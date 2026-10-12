import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../utils/localized_input.dart';

/// Display a decimal comma in German; keep canonical precision in the caller's
/// controller. Unknown legacy free-text amounts can opt out of normalization.
class DecimalFormField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final bool normalize;
  const DecimalFormField(
      {super.key,
      required this.controller,
      required this.decoration,
      this.validator,
      this.normalize = true});
  @override
  State<DecimalFormField> createState() => _DecimalFormFieldState();
}

class _DecimalFormFieldState extends State<DecimalFormField> {
  final _display = TextEditingController();
  bool _changing = false;
  bool _initializedDisplay = false;
  String _language = 'en';
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
  void didUpdateWidget(DecimalFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
    _syncAfterBuild();
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

  void _sync() {
    if (_changing) return;
    var text = widget.controller.text;
    if (widget.normalize && canonicalDecimal(text) != null) {
      text = _language == 'de'
          ? text.replaceAll('.', ',')
          : text.replaceAll(',', '.');
    }
    if (_display.text != text) _display.text = text;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _display.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: _display,
        decoration:
            widget.decoration.copyWith(helperMaxLines: 4, errorMaxLines: 4),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        onChanged: (value) {
          _changing = true;
          widget.controller.text =
              widget.normalize ? canonicalDecimal(value) ?? value : value;
          _changing = false;
        },
        validator: widget.validator,
      );
}
