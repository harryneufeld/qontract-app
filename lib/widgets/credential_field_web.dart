import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// A real `<input>` element, kept in the DOM for the lifetime of the field,
/// inside Flutter's [InputDecorator] so it looks like the other fields.
///
/// Password managers fill it like any HTML form field. DOM changes are copied
/// into [controller], and programmatic controller changes (e.g. clearing the
/// password) are copied back.
class DomCredentialInput extends StatefulWidget {
  const DomCredentialInput({
    super.key,
    required this.controller,
    required this.autocomplete,
    required this.obscureText,
    required this.decoration,
    this.maxLength,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String autocomplete;
  final bool obscureText;
  final InputDecoration decoration;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;

  @override
  State<DomCredentialInput> createState() => _DomCredentialInputState();
}

class _DomCredentialInputState extends State<DomCredentialInput> {
  static const double _lineHeight = 24;
  static bool _fontRegistered = false;
  static int _nextId = 0;

  // Mirrors the DOM focus in Flutter's focus tree, so keyboard traversal can
  // reach the field and Flutter shortcuts (e.g. Tab) leave its keys alone.
  final FocusNode _focusNode = FocusNode(debugLabel: 'DomCredentialInput');
  web.HTMLInputElement? _input;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _registerFont();
    widget.controller.addListener(_controllerChanged);
    _focusNode.addListener(_flutterFocusChanged);
  }

  @override
  void didUpdateWidget(DomCredentialInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerChanged);
      widget.controller.addListener(_controllerChanged);
      _controllerChanged();
    }
    if (oldWidget.obscureText != widget.obscureText) {
      _input?.type = widget.obscureText ? 'password' : 'text';
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  // Flutter draws text with its bundled Roboto; expose the same file to CSS
  // so the DOM input matches the other fields without fetching fonts.
  static void _registerFont() {
    if (_fontRegistered) return;
    _fontRegistered = true;
    final style = web.document.createElement('style') as web.HTMLStyleElement;
    style.textContent = '@font-face{font-family:"qontract-roboto";'
        'src:url("assets/assets/fonts/Roboto-Regular.ttf") format("truetype");}';
    web.document.head?.append(style);
  }

  void _controllerChanged() {
    final input = _input;
    if (input != null && input.value != widget.controller.text) {
      input.value = widget.controller.text;
    }
    if (mounted) setState(() {});
  }

  void _domChanged() {
    final value = _input?.value ?? '';
    if (value == widget.controller.text) return;
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _setFocused(bool focused) {
    if (!mounted) return;
    if (_focused != focused) setState(() => _focused = focused);
    if (focused) {
      _focusNode.requestFocus();
    } else if (_focusNode.hasPrimaryFocus) {
      _focusNode.unfocus();
    }
  }

  // Focus reached the field through Flutter (e.g. Tab from another widget).
  void _flutterFocusChanged() {
    final input = _input;
    if (_focusNode.hasFocus &&
        input != null &&
        web.document.activeElement != input) {
      input.focus();
    }
  }

  void _onCreated(Object element) {
    final input = element as web.HTMLInputElement;
    _input = input;
    final username = widget.autocomplete == 'username';
    input
      ..type = widget.obscureText ? 'password' : 'text'
      ..name = username ? 'username' : widget.autocomplete
      ..id = 'qontract-${widget.autocomplete}-${_nextId++}'
      ..autocomplete = widget.autocomplete
      ..spellcheck = false
      ..value = widget.controller.text;
    input.setAttribute('autocapitalize', 'off');
    input.setAttribute('autocorrect', 'off');
    if (username) input.setAttribute('inputmode', 'email');
    final maxLength = widget.maxLength;
    if (maxLength != null) input.maxLength = maxLength;
    _applyStyle(input);

    void changed(web.Event _) => _domChanged();
    input.addEventListener('input', changed.toJS);
    input.addEventListener('change', changed.toJS);
    input.addEventListener('focus', ((web.Event _) => _setFocused(true)).toJS);
    input.addEventListener('blur', ((web.Event _) => _setFocused(false)).toJS);
    input.addEventListener(
      'keydown',
      ((web.KeyboardEvent event) {
        if (event.key != 'Enter') return;
        event.preventDefault();
        _domChanged();
        widget.onSubmitted?.call(widget.controller.text);
      }).toJS,
    );
  }

  void _applyStyle(web.HTMLInputElement input) {
    final theme = Theme.of(context);
    final text = theme.textTheme.bodyLarge;
    final color = text?.color ?? theme.colorScheme.onSurface;
    input.style
      ..setProperty('box-sizing', 'border-box')
      ..setProperty('width', '100%')
      ..setProperty('height', '100%')
      ..setProperty('margin', '0')
      ..setProperty('padding', '0')
      ..setProperty('border', 'none')
      ..setProperty('outline', 'none')
      ..setProperty('background', 'transparent')
      ..setProperty('color', _css(color))
      ..setProperty('caret-color', _css(theme.colorScheme.primary))
      ..setProperty(
          'font-family',
          '"qontract-roboto", Roboto, system-ui, -apple-system, '
              '"Segoe UI", sans-serif')
      ..setProperty('font-size', '${text?.fontSize ?? 16}px')
      ..setProperty('line-height', '${_lineHeight}px')
      ..setProperty('letter-spacing', '${text?.letterSpacing ?? 0}px');
  }

  static String _css(Color c) =>
      'rgba(${(c.r * 255).round()}, ${(c.g * 255).round()}, '
      '${(c.b * 255).round()}, ${c.a.toStringAsFixed(3)})';

  @override
  Widget build(BuildContext context) {
    // The theme (light/dark) can change while the element lives.
    final input = _input;
    if (input != null) _applyStyle(input);
    return Focus(
      focusNode: _focusNode,
      // Typing, Tab and shortcuts belong to the browser's input.
      onKeyEvent: (_, __) => KeyEventResult.skipRemainingHandlers,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _input?.focus(),
        child: InputDecorator(
          // Same character counter a TextFormField with maxLength shows.
          decoration: widget.maxLength == null
              ? widget.decoration
              : widget.decoration.copyWith(
                  counterText:
                      '${widget.controller.text.characters.length}/${widget.maxLength}',
                ),
          isFocused: _focused,
          isEmpty: widget.controller.text.isEmpty,
          child: SizedBox(
            height: _lineHeight,
            child: HtmlElementView.fromTagName(
              tagName: 'input',
              onElementCreated: _onCreated,
            ),
          ),
        ),
      ),
    );
  }
}
