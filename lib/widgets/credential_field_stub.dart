import 'package:flutter/material.dart';

/// Only used on web; see `credential_field_web.dart`.
class DomCredentialInput extends StatelessWidget {
  const DomCredentialInput({
    super.key,
    required this.controller,
    required this.autocomplete,
    required this.obscureText,
    required this.decoration,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String autocomplete;
  final bool obscureText;
  final InputDecoration decoration;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => throw UnsupportedError('web only');
}
