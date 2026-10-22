import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../utils/currency.dart';

/// Picks a currency by symbol; the value stays the ISO code.
class CurrencyField extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  final String? label;
  final bool enabled;

  /// Adds a blank choice (reported as an empty string).
  final bool allowEmpty;
  const CurrencyField(
      {super.key,
      required this.value,
      required this.onChanged,
      this.label,
      this.enabled = true,
      this.allowEmpty = false});

  @override
  Widget build(BuildContext context) {
    final current = value?.trim().toUpperCase();
    final codes = <String>{
      ...offeredCurrencies,
      if (current != null && current.isNotEmpty) current,
    };
    final empty = current == null || current.isEmpty;
    return DropdownButtonFormField<String>(
      // initialValue is read once, so follow outside changes by re-keying.
      key: ValueKey('currency-${current ?? ''}'),
      isExpanded: true,
      initialValue: empty ? (allowEmpty ? '' : null) : current,
      decoration: InputDecoration(labelText: label ?? context.l10n.currency),
      items: [
        if (allowEmpty) const DropdownMenuItem(value: '', child: Text('—')),
        for (final code in codes)
          DropdownMenuItem(value: code, child: Text(currencyLabel(code))),
      ],
      onChanged: enabled ? (v) => v == null ? null : onChanged(v) : null,
    );
  }
}
