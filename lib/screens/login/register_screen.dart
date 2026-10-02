import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/app_toast.dart';

class RegisterScreen extends StatefulWidget {
  final bool invitationOnly;
  const RegisterScreen({super.key, this.invitationOnly = false});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _tenant = TextEditingController();
  final _code = TextEditingController();
  String _type = 'Family';

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _password,
      _confirm,
      _tenant,
      _code
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register({
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
      if (!widget.invitationOnly) 'tenantName': _tenant.text.trim(),
      if (!widget.invitationOnly) 'tenantType': _type,
      if (widget.invitationOnly) 'invitationCode': _code.text.trim(),
    });
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
    } else {
      showToast(context, auth.errorMessage ?? 'Could not create your account.',
          style: ToastStyle.error);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.invitationOnly
              ? 'Join with invitation'
              : 'Create account')),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(widget.invitationOnly
              ? 'Create an account to join the tenant that invited you. Already have an account? Sign in and accept the invitation from Tenants.'
              : 'Create your account and your first tenant.'),
          const SizedBox(height: 20),
          Form(
              key: _form,
              child: AppFormColumn(children: [
                TextFormField(
                    key: const Key('registerName'),
                    controller: _name,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Your name'),
                    validator: _required),
                TextFormField(
                    key: const Key('registerEmail'),
                    controller: _email,
                    maxLength: 100,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) =>
                        _required(value) ??
                        ((value!.contains('@') && value.contains('.'))
                            ? null
                            : 'Enter a valid email.')),
                TextFormField(
                    key: const Key('registerPassword'),
                    controller: _password,
                    obscureText: true,
                    maxLength: 255,
                    decoration: const InputDecoration(
                        labelText: 'Password',
                        helperText: 'At least 10 characters'),
                    validator: (value) => (value?.length ?? 0) < 10
                        ? 'Use at least 10 characters.'
                        : null),
                TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Confirm password'),
                    validator: (value) => value != _password.text
                        ? 'Passwords do not match.'
                        : null),
                if (widget.invitationOnly)
                  TextFormField(
                      key: const Key('registerCode'),
                      controller: _code,
                      decoration:
                          const InputDecoration(labelText: 'Invitation code'),
                      validator: (value) => value?.trim().length != 64
                          ? 'Paste the complete invitation code.'
                          : null)
                else ...[
                  TextFormField(
                      key: const Key('registerTenant'),
                      controller: _tenant,
                      maxLength: 100,
                      decoration:
                          const InputDecoration(labelText: 'Tenant name'),
                      validator: _required),
                  DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration:
                          const InputDecoration(labelText: 'Tenant type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Family', child: Text('Standard')),
                        DropdownMenuItem(
                            value: 'Company', child: Text('Company'))
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _type = value!)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: busy ? null : _submit,
                    child: Text(busy
                        ? 'Creating account…'
                        : widget.invitationOnly
                            ? 'Join tenant'
                            : 'Create account')),
              ])),
        ]),
      )),
    );
  }
}
