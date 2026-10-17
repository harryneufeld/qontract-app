import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../l10n/strings.dart';
import '../providers/api_host_provider.dart';
import '../providers/auth_provider.dart';

/// Compact server button for the login screen; [onChanged] runs after the
/// dialog closes so the screen can reload host-dependent state.
class ApiHostButton extends StatelessWidget {
  final VoidCallback? onChanged;
  const ApiHostButton({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (Provider.of<ApiHostProvider?>(context)?.switchingEnabled != true) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('apiHostButton'),
      tooltip: context.l10n.server,
      icon: const Icon(Icons.dns_outlined),
      onPressed: () async {
        await showApiHostDialog(context);
        onChanged?.call();
      },
    );
  }
}

/// Settings row showing the active server.
class ApiHostTile extends StatelessWidget {
  const ApiHostTile({super.key});

  @override
  Widget build(BuildContext context) {
    final hosts = Provider.of<ApiHostProvider?>(context);
    if (hosts == null || !hosts.switchingEnabled) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: const Key('apiHostTile'),
      leading: const Icon(Icons.dns_outlined),
      title: Text(_activeName(context, hosts)),
      subtitle: Text(hosts.effectiveUrl),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showApiHostDialog(context),
    );
  }
}

String _activeName(BuildContext context, ApiHostProvider hosts) {
  for (final host in hosts.hosts) {
    if (host.url == hosts.activeUrl) return host.name;
  }
  return context.l10n.defaultServer;
}

Future<void> showApiHostDialog(BuildContext context) async {
  if (!context.read<ApiHostProvider>().switchingEnabled) return;
  await showDialog<void>(
    context: context,
    builder: (_) => const _ApiHostDialog(),
  );
}

class _ApiHostDialog extends StatelessWidget {
  const _ApiHostDialog();

  @override
  Widget build(BuildContext context) {
    final hosts = context.watch<ApiHostProvider>();
    Widget option(String? url, String name, String address) {
      final selected = url == hosts.activeUrl;
      return ListTile(
        key: Key('apiHost-${url ?? 'default'}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(name),
        subtitle: Text(address),
        selected: selected,
        onTap: selected ? null : () => _switchTo(context, url),
        trailing: url == null || selected
            ? null
            : IconButton(
                tooltip: context.l10n.removeServer,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => hosts.remove(url),
              ),
      );
    }

    return AlertDialog(
      title: Text(context.l10n.server),
      contentPadding: const EdgeInsets.only(top: 12),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            option(null, context.l10n.defaultServer, hosts.defaultUrl),
            for (final host in hosts.hosts)
              option(host.url, host.name, host.url),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                context.l10n.serversAreSavedOnThisDevice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('addApiHostButton'),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.addServer),
          onPressed: () => _addHost(context),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }

  /// Tokens belong to one backend: sign out on the old host before switching,
  /// so the session is never sent to the new one.
  Future<void> _switchTo(BuildContext context, String? url) async {
    final hosts = context.read<ApiHostProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.switchServerQuestion),
          content: Text(context.l10n.switchingTheServerSignsYouOut),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('confirmSwitchServer'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.switchServer),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await auth.logout();
    }
    await hosts.select(url);
  }

  Future<void> _addHost(BuildContext context) async {
    final host = await showDialog<ApiHost>(
      context: context,
      builder: (_) => const _AddApiHostDialog(),
    );
    if (host != null && context.mounted) await _switchTo(context, host.url);
  }
}

class _AddApiHostDialog extends StatefulWidget {
  const _AddApiHostDialog();

  @override
  State<_AddApiHostDialog> createState() => _AddApiHostDialogState();
}

class _AddApiHostDialogState extends State<_AddApiHostDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final host = await context
        .read<ApiHostProvider>()
        .save(_address.text, name: _name.text);
    if (mounted) Navigator.of(context).pop(host);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.addServer),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('apiHostAddressField'),
              controller: _address,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.l10n.serverAddress,
                hintText: 'https://qontract.example.com',
              ),
              validator: (value) => parseApiHostInput(value ?? '') == null
                  ? context.l10n.enterAValidServerAddress
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('apiHostNameField'),
              controller: _name,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(labelText: context.l10n.serverName),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('saveApiHostButton'),
          onPressed: _submit,
          child: Text(context.l10n.add),
        ),
      ],
    );
  }
}
