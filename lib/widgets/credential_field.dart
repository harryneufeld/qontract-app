import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'credential_field_stub.dart'
    if (dart.library.js_interop) 'credential_field_web.dart';

/// What a [CredentialField] holds; decides autofill hints and input type.
enum CredentialKind { username, currentPassword }

/// Email or password field of a sign-in form.
///
/// Flutter web only creates a hidden DOM input while a field is focused, so
/// browser extensions such as Bitwarden find no fields to fill. On web this
/// widget therefore hosts a real, permanent `<input>` inside the usual
/// decoration; elsewhere it is a plain [TextFormField] with autofill hints.
class CredentialField extends StatelessWidget {
  const CredentialField({
    super.key,
    required this.controller,
    required this.kind,
    required this.decoration,
    this.obscureText = false,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final CredentialKind kind;
  final InputDecoration decoration;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final username = kind == CredentialKind.username;
    if (kIsWeb) {
      return FormField<String>(
        validator:
            validator == null ? null : (_) => validator!(controller.text),
        builder: (field) => DomCredentialInput(
          controller: controller,
          autocomplete: username ? 'username' : 'current-password',
          obscureText: obscureText,
          decoration: decoration.copyWith(errorText: field.errorText),
          onSubmitted: onFieldSubmitted,
        ),
      );
    }
    return TextFormField(
      controller: controller,
      autofillHints: username
          ? const [AutofillHints.username, AutofillHints.email]
          : const [AutofillHints.password],
      keyboardType:
          username ? TextInputType.emailAddress : TextInputType.visiblePassword,
      autocorrect: false,
      enableSuggestions: false,
      obscureText: obscureText,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.none,
      decoration: decoration,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
