import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// User account page (app#11): shows the signed-in account and lets the
/// user change their password.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      _currentController.text,
      _newController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Password change failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Account'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 24,
                      child: Text(
                        (user?.name.isNotEmpty ?? false)
                            ? user!.name.characters.first.toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(user?.name ?? '—'),
                    subtitle: Text(user?.email ?? '—'),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Role: ${user?.role ?? '—'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Member since '
                            '${user?.createdAt.toLocal().toIso8601String().substring(0, 10) ?? '—'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _SectionTitle('Change password'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('currentPasswordField'),
                      controller: _currentController,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: _obscure,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter your current password.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('newPasswordField'),
                      controller: _newController,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: _obscure,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter a new password.';
                        }
                        if (v.length < 6) {
                          return 'Password must be at least 6 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('confirmPasswordField'),
                      controller: _confirmController,
                      decoration: const InputDecoration(
                        labelText: 'Repeat new password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: _obscure,
                      validator: (v) => (v != _newController.text)
                          ? 'Passwords do not match.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            key: const Key('showPasswordCheckbox'),
                            value: !_obscure,
                            onChanged: (v) => setState(() => _obscure = !(v ?? false)),
                          ),
                          Text('Show password'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('changePasswordButton'),
                      onPressed: _saving ? null : _handleChangePassword,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.lock_reset),
                      label: Text(
                        _saving ? 'Changing…' : 'Change password',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
