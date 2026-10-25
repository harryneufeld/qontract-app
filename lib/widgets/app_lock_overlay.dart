import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../providers/app_lock_provider.dart';
import '../providers/auth_provider.dart';
import 'app_design.dart';

/// Covers the whole app with the lock screen while the biometric lock is
/// engaged and someone is signed in. The app underneath keeps its state but
/// is neither painted nor reachable.
class AppLockOverlay extends StatelessWidget {
  final Widget child;
  const AppLockOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final locked = context.watch<AppLockProvider>().locked &&
        context.watch<AuthProvider>().isAuthenticated;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: locked, child: child),
        if (locked) const LockScreen(),
      ],
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    // Ask straight away; the buttons are there if the prompt is dismissed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppLockProvider>().unlock();
    });
  }

  Future<void> _signOut() async {
    final lock = context.read<AppLockProvider>();
    await context.read<AuthProvider>().logout();
    await lock.reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.section),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: AppSpace.group),
                  Text(context.l10n.appLockLocked,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppSpace.section),
                  FilledButton.icon(
                    key: const Key('unlockButton'),
                    onPressed: () => context.read<AppLockProvider>().unlock(),
                    icon: const Icon(Icons.fingerprint),
                    label: Text(context.l10n.appLockUnlock),
                  ),
                  const SizedBox(height: AppSpace.control),
                  TextButton(
                    key: const Key('lockSignOutButton'),
                    onPressed: _signOut,
                    child: Text(context.l10n.appLockSignOut),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
