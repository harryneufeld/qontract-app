import 'sessions_screen.dart';
import 'two_factor_screen.dart';
import '../../widgets/app_design.dart';
import '../../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_lock_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_toast.dart';
import '../../app_routes.dart';
import '../address/address_book_screen.dart';
import '../../services/api_service.dart';

/// User account page (app#11): shows the signed-in account and lets the
/// user change their password.
class AccountScreen extends StatefulWidget {
  final ApiService? api;
  const AccountScreen({super.key, this.api});

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
      showToast(context, context.l10n.passwordChangedPleaseSignInAgain,
          style: ToastStyle.success);
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    } else {
      showToast(
        context,
        auth.errorMessage ?? context.l10n.passwordChangeFailed194,
        style: ToastStyle.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.account)),
      body: AppPageListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(context.l10n.account),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(context.l10n.myAddresses),
                  subtitle:
                      Text(context.l10n.privatePostalDetailsVisibleOnlyToYou),
                  onTap: user == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => AddressBookScreen(
                                  entityType: 'Person',
                                  canEdit: true,
                                  api: widget.api))))),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(context.l10n.workspaces),
                  subtitle: Text(
                      context.l10n.choosePersonalOrATenantAcceptInvitationsAnd),
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.tenants))),
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
                            context.l10n.role((S.role(user?.role))),
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
                            context.l10n.memberSince +
                                S.date(user?.createdAt.toLocal()),
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
          _SectionTitle(context.l10n.changePassword),
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
                      decoration: InputDecoration(
                        labelText: context.l10n.currentPassword,
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: _obscure,
                      validator: (v) => (v == null || v.isEmpty)
                          ? context.l10n.enterYourCurrentPassword
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('newPasswordField'),
                      controller: _newController,
                      decoration: InputDecoration(
                        labelText: context.l10n.newPassword,
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: _obscure,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return context.l10n.enterANewPassword;
                        }
                        if (v.length < 6) {
                          return context.l10n.passwordMustBeAtLeast6Characters;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('confirmPasswordField'),
                      controller: _confirmController,
                      decoration: InputDecoration(
                        labelText: context.l10n.repeatNewPassword,
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: _obscure,
                      validator: (v) => (v != _newController.text)
                          ? context.l10n.passwordsDoNotMatch
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Checkbox(
                            key: const Key('showPasswordCheckbox'),
                            value: !_obscure,
                            onChanged: (v) =>
                                setState(() => _obscure = !(v ?? false)),
                          ),
                          Expanded(child: Text(context.l10n.showPassword)),
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
                        _saving
                            ? context.l10n.changing
                            : context.l10n.changePassword,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Card(
              child: ListTile(
            leading: const Icon(Icons.phonelink_lock_outlined),
            title: Text(context.l10n.twoFactorTitle),
            subtitle: Text(context.l10n.twoFactorDescription),
            onTap: user == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => TwoFactorScreen(api: widget.api))),
          )),
          Card(
              child: ListTile(
            key: const Key('devicesTile'),
            leading: const Icon(Icons.devices_outlined),
            title: Text(context.l10n.devicesTitle),
            subtitle: Text(context.l10n.devicesDescription),
            onTap: user == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => SessionsScreen(api: widget.api))),
          )),
          const _BiometricLockTile(),
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

/// Opt-in biometric lock; hidden where the device cannot offer it (web, desktop).
class _BiometricLockTile extends StatelessWidget {
  const _BiometricLockTile();

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockProvider>();
    if (!lock.available) return const SizedBox.shrink();
    return Card(
      child: SwitchListTile(
        key: const Key('biometricLockSwitch'),
        secondary: const Icon(Icons.fingerprint),
        title: Text(context.l10n.appLockTitle),
        subtitle: Text(context.l10n.appLockDescription),
        value: lock.enabled,
        onChanged: (value) async {
          final ok = await lock.setEnabled(value);
          if (!ok && value && context.mounted) {
            showToast(context, context.l10n.appLockUnavailable,
                style: ToastStyle.error);
          }
        },
      ),
    );
  }
}
