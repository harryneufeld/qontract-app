import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/models/app_notification.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/providers/notification_provider.dart';
import 'package:qontract_app/screens/notifications/notification_inbox_screen.dart';
import 'package:qontract_app/screens/notifications/notification_settings_screen.dart';
import 'package:qontract_app/screens/notifications/notification_text.dart';
import 'package:qontract_app/services/api_service.dart';

AppNotification note(String id,
        {String kind = NotificationKind.noticeDeadline,
        String severity = 'Warning',
        bool read = false}) =>
    AppNotification(
        id: id,
        kind: kind,
        severity: severity,
        contractId: 7,
        contractTitle: 'Gym',
        dueOn: '2026-11-01',
        params: const {
          'daysLeft': 6,
          'deadline': '2026-11-01',
          'termEnd': '2026-12-01',
          'autoRenews': true
        },
        createdAt: DateTime.utc(2026, 10, 22),
        readAt: read ? DateTime.utc(2026, 10, 22) : null);

class FakeNotificationApi extends ApiService {
  FakeNotificationApi() : super(baseUrl: 'http://localhost');
  List<AppNotification> rows = [note('a'), note('b', read: true)];
  final calls = <String>[];
  bool fail = false;
  NotificationPreferences prefs = const NotificationPreferences();
  NotificationPreferences? saved;

  @override
  Future<List<AppNotification>> getNotifications() async {
    if (fail) throw ApiException(message: 'Offline', statusCode: 503);
    return List.of(rows);
  }

  @override
  Future<int> getNotificationUnreadCount() async =>
      rows.where((n) => !n.isRead).length;

  @override
  Future<void> markNotificationRead(String id) async => calls.add('read:$id');

  @override
  Future<void> markAllNotificationsRead() async => calls.add('readAll');

  @override
  Future<void> dismissNotification(String id) async => calls.add('dismiss:$id');

  @override
  Future<void> snoozeNotification(String id, int days) async =>
      calls.add('snooze:$id:$days');

  @override
  Future<NotificationPreferences> getNotificationPreferences() async => prefs;

  @override
  Future<NotificationPreferences> saveNotificationPreferences(
      NotificationPreferences preferences) async {
    saved = preferences;
    return preferences;
  }
}

void main() {
  test('notification wording follows the language and uses the params', () {
    final en = describeNotification(note('a'));
    expect(en.title, 'Cancellation deadline in 6 days');
    expect(en.body, contains('Gym'));
    expect(en.body, contains('2026-11-01'));
    expect(en.body, contains('or it renews'));
    final de = describeNotification(note('a'),
        l10n: lookupAppLocalizations(const Locale('de')));
    expect(de.title, 'Kündigungsfrist endet in 6 Tagen');
    expect(describeNotification(note('p', kind: 'somethingNew')).title,
        'somethingNew');
  });

  test('contract notice fields round-trip and are sent on save', () {
    final contract = Contract.fromJson({
      'id': 1,
      'title': 'Gym',
      'status': 'Active',
      'noticePeriodValue': 3,
      'noticePeriodUnit': 'Months',
      'autoRenews': true,
      'renewalMonths': 12,
      'createdAt': '2026-01-01T00:00:00Z',
      'modifiedAt': '2026-01-01T00:00:00Z',
    });
    expect(contract.noticePeriodValue, 3);
    expect(contract.autoRenews, isTrue);
    final json = contract.withDocumentCount(2).toJson();
    expect(json['noticePeriodValue'], 3);
    expect(json['noticePeriodUnit'], 'Months');
    expect(json['autoRenews'], isTrue);
    expect(json['renewalMonths'], 12);

    final cleared = Contract(
            id: 1,
            title: 'Gym',
            status: 'Active',
            clearNoticePeriod: true,
            createdAt: DateTime.utc(2026),
            modifiedAt: DateTime.utc(2026))
        .toJson();
    expect(cleared['clearNoticePeriod'], isTrue);
    expect(cleared.containsKey('noticePeriodValue'), isFalse);
    expect(cleared['autoRenews'], isFalse);
    expect(cleared.containsKey('renewalMonths'), isFalse);
  });

  test('provider loads, tracks unread and applies actions', () async {
    final api = FakeNotificationApi();
    final provider = NotificationProvider(api: api);
    await provider.load();
    expect(provider.items.length, 2);
    expect(provider.unread, 1);

    await provider.markRead(provider.items.first);
    expect(provider.unread, 0);
    expect(api.calls, ['read:a']);

    await provider.dismiss(provider.items.first);
    expect(provider.items.map((n) => n.id), ['b']);
    await provider.snooze(provider.items.first, 7);
    expect(provider.items, isEmpty);
    expect(api.calls, ['read:a', 'dismiss:a', 'snooze:b:7']);
  });

  test('provider reports load errors and keeps the badge count on failure',
      () async {
    final api = FakeNotificationApi()..fail = true;
    final provider = NotificationProvider(api: api);
    await provider.load();
    expect(provider.error, 'Offline');
    await provider.refreshUnread();
    expect(provider.unread, 1);
  });

  testWidgets('inbox lists notifications and dismisses one', (tester) async {
    final api = FakeNotificationApi();
    final provider = NotificationProvider(api: api);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: NotificationInboxScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Cancellation deadline in 6 days'), findsNWidgets(2));

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Cancellation deadline in 6 days'), findsOneWidget);
    expect(api.calls, ['dismiss:a']);
  });

  testWidgets('inbox shows an empty state', (tester) async {
    final api = FakeNotificationApi()..rows = [];
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: NotificationProvider(api: api),
        child: const MaterialApp(home: NotificationInboxScreen())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notificationsEmpty')), findsOneWidget);
  });

  testWidgets('settings mute a kind and save the digest', (tester) async {
    final api = FakeNotificationApi();
    await tester
        .pumpWidget(MaterialApp(home: NotificationSettingsScreen(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('kind_priceIncrease')));
    await tester.pumpAndSettle();
    expect(api.saved!.mutedKinds, {NotificationKind.priceIncrease});

    await tester.ensureVisible(find.byKey(const Key('digestSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('digestSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();
    expect(api.saved!.digest, 'Weekly');
    expect(api.saved!.mutedKinds, {NotificationKind.priceIncrease});
  });
}
