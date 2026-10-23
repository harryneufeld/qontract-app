import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_routes.dart';
import '../../l10n/strings.dart';
import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_toast.dart';
import 'notification_text.dart';

/// Inbox of recommendations and reminders for the current workspace.
class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().load();
    });
  }

  Future<void> _open(AppNotification n) async {
    final provider = context.read<NotificationProvider>();
    provider.markRead(n);
    final id = n.contractId;
    if (id == null) return;
    try {
      final contract = await ApiService().getContract(id);
      if (!mounted) return;
      Navigator.of(context)
          .pushNamed(AppRoutes.contractDetail, arguments: contract);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, style: ToastStyle.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.ntfTitle),
        actions: [
          IconButton(
            key: const Key('markAllRead'),
            tooltip: l.ntfMarkAllRead,
            icon: const Icon(Icons.done_all),
            onPressed: provider.unread == 0 ? null : provider.markAllRead,
          ),
          IconButton(
            tooltip: l.ntfSettingsTooltip,
            icon: const Icon(Icons.tune),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.notificationSettings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: _body(provider),
      ),
    );
  }

  Widget _body(NotificationProvider provider) {
    final l = context.l10n;
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.items.isEmpty) {
      return ListView(children: [
        Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text(provider.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                  key: const Key('retryNotifications'),
                  onPressed: provider.load,
                  child: Text(l.retry)),
            ]))
      ]);
    }
    if (provider.items.isEmpty) {
      return ListView(children: [
        Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
                child: Text(l.ntfEmpty, key: const Key('notificationsEmpty'))))
      ]);
    }
    return AppPageListView(children: [
      for (final n in provider.items)
        _NotificationTile(
            notification: n,
            onOpen: () => _open(n),
            onDismiss: () => provider.dismiss(n),
            onSnooze: () => provider.snooze(n, 7)),
    ]);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onOpen,
    required this.onDismiss,
    required this.onSnooze,
  });

  final AppNotification notification;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = describeNotification(notification, l10n: l);
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (notification.severity) {
      'Urgent' => (Icons.error_outline, scheme.error),
      'Warning' => (Icons.warning_amber_outlined, Colors.orange),
      _ => (Icons.info_outline, scheme.primary),
    };
    return ListTile(
      key: Key('notification_${notification.id}'),
      leading: Icon(icon, color: color),
      title: Text(text.title,
          style: TextStyle(
              fontWeight:
                  notification.isRead ? FontWeight.normal : FontWeight.bold)),
      subtitle: Text(text.body),
      isThreeLine: true,
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        tooltip: l.ntfActions,
        onSelected: (value) => value == 'snooze' ? onSnooze() : onDismiss(),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'snooze', child: Text(l.ntfSnooze)),
          PopupMenuItem(value: 'dismiss', child: Text(l.ntfDismiss)),
        ],
      ),
    );
  }
}
