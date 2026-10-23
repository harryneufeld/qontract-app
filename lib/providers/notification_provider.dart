import '../models/app_notification.dart';
import '../services/api_service.dart';
import 'session_notifier.dart';

/// Inbox of recommendations for the signed-in workspace. Recreated with the
/// other tenant providers, so a workspace switch never shows stale items.
class NotificationProvider extends SessionNotifier {
  final ApiService _api;

  List<AppNotification> _items = [];
  int _unread = 0;
  bool _isLoading = false;
  String? _error;
  int _request = 0;

  NotificationProvider({ApiService? api}) : _api = api ?? ApiService();

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unread => _unread;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Cheap badge refresh for the dashboard; failures keep the old count.
  Future<void> refreshUnread() async {
    final request = ++_request;
    try {
      final count = await _api.getNotificationUnreadCount();
      if (request != _request) return;
      _unread = count;
      notifyListeners();
    } on ApiException {
      // The badge is optional; the inbox reports errors itself.
    }
  }

  Future<void> load() async {
    final request = ++_request;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final items = await _api.getNotifications();
      if (request != _request) return;
      _items = items;
      _unread = items.where((n) => !n.isRead).length;
    } on ApiException catch (e) {
      if (request != _request) return;
      _error = e.message;
    } finally {
      if (request == _request) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    await _act(() => _api.markNotificationRead(notification.id), () {
      _items = [
        for (final n in _items) n.id == notification.id ? n.asRead() : n
      ];
    });
  }

  Future<void> markAllRead() => _act(() => _api.markAllNotificationsRead(),
      () => _items = [for (final n in _items) n.asRead()]);

  Future<void> dismiss(AppNotification notification) => _act(
      () => _api.dismissNotification(notification.id),
      () => _items = _items.where((n) => n.id != notification.id).toList());

  Future<void> snooze(AppNotification notification, int days) => _act(
      () => _api.snoozeNotification(notification.id, days),
      () => _items = _items.where((n) => n.id != notification.id).toList());

  Future<void> _act(Future<void> Function() call, void Function() apply) async {
    try {
      await call();
      apply();
      _unread = _items.where((n) => !n.isRead).length;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }
}
