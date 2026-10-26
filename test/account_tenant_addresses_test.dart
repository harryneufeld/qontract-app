import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/providers/app_lock_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/models/address.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/screens/account/account_screen.dart';
import 'package:qontract_app/screens/address/address_book_screen.dart';
import 'package:qontract_app/services/api_service.dart';

class _Api extends ApiService {
  _Api() : super(baseUrl: 'http://localhost');
  List<Address> rows = [];
  Address? saved;
  int myCalls = 0, tenantCalls = 0, mutations = 0;
  bool fail = false;
  Completer<List<Address>>? pending;
  @override
  Future<AuthResult> login(String email, String password) async => AuthResult(
      token: 'private-token',
      user: User(
          id: 4,
          name: 'Private user',
          email: email,
          role: 'User',
          tenantId: 0,
          createdAt: DateTime.utc(2026)));
  @override
  Future<List<Address>> getMyAddresses() async {
    myCalls++;
    if (pending != null) return pending!.future;
    if (fail) throw ApiException(message: 'Address service unavailable');
    return [...rows];
  }

  @override
  Future<List<Address>> getTenantAddresses() async {
    tenantCalls++;
    return [...rows];
  }

  @override
  Future<Address> createAddress(Address address) async {
    mutations++;
    saved = address.copyWith(id: 10);
    rows.add(saved!);
    return saved!;
  }

  @override
  Future<Address> updateAddress(Address address) async {
    mutations++;
    saved = address;
    rows = [for (final row in rows) row.id == address.id ? address : row];
    return address;
  }

  @override
  Future<Address> deactivateAddress(int id) async {
    mutations++;
    final removed = rows.firstWhere((row) => row.id == id);
    rows.removeWhere((row) => row.id == id);
    return removed.copyWith(isActive: false);
  }
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Account opens the private address book even without tenants',
      (tester) async {
    final api = _Api();
    final auth = AuthProvider(api: api);
    await auth.login('private@example.test', 'password');
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider<AppLockProvider>(create: (_) => AppLockProvider()),
    ], child: MaterialApp(home: AccountScreen(api: api))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My addresses'));
    await tester.pumpAndSettle();
    expect(find.text('Your postal addresses'), findsOneWidget);
    expect(api.myCalls, 1);
    expect(api.tenantCalls, 0);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets(
      'private create edit clear and remove preserve scope and raw fields',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(MaterialApp(
        home:
            AddressBookScreen(entityType: 'Person', canEdit: true, api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add address'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Street'), ' First Straße ');
    await tester.enterText(field('House number'), '12/a');
    await tester.enterText(field('City'), 'Berlin');
    await tester.tap(find.widgetWithText(FilledButton, 'Add address'));
    await tester.pumpAndSettle();
    expect(api.saved!.street, ' First Straße ');
    expect(api.saved!.houseNumber, '12/a');
    expect(api.saved!.entityType, 'Person');
    expect(api.saved!.toCreateJson(), isNot(contains('userId')));
    expect(api.saved!.toCreateJson(), isNot(contains('tenantId')));
    await tester.tap(find.text(api.rows.single.display));
    await tester.pump();
    await tester.tap(find.byTooltip('Edit address'));
    await tester.pumpAndSettle();
    await tester.enterText(field('House number'), '');
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();
    expect(api.saved!.houseNumber, '');
    expect(api.saved!.street, ' First Straße ');
    expect(api.saved!.toUpdateJson()['houseNumber'], '');
    await tester.tap(find.byTooltip('Remove address'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(api.rows, isEmpty);
    expect(api.mutations, 3);
    expect(find.text('No addresses yet.'), findsOneWidget);
  });

  testWidgets('members view tenant addresses without editing controls',
      (tester) async {
    final api = _Api()
      ..rows = [
        const Address(
            id: 1,
            entityType: 'Tenant',
            street: 'Shared Street',
            houseNumber: '15')
      ];
    await tester.pumpWidget(MaterialApp(
        home:
            AddressBookScreen(entityType: 'Tenant', canEdit: false, api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Shared Street 15'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(api.tenantCalls, 1);
    expect(api.myCalls, 0);
    expect(api.mutations, 0);
  });

  testWidgets(
      'tenant admins can save a partial address without inventing a street',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(MaterialApp(
        home:
            AddressBookScreen(entityType: 'Tenant', canEdit: true, api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add address'));
    await tester.pumpAndSettle();
    await tester.enterText(field('City'), 'Only city known');
    await tester.tap(find.widgetWithText(FilledButton, 'Add address'));
    await tester.pumpAndSettle();
    expect(api.saved!.entityType, 'Tenant');
    expect(api.saved!.street, '');
    expect(find.text('Only city known'), findsOneWidget);
  });

  testWidgets(
      'failed loading offers a retry and cannot mutate an incomplete list',
      (tester) async {
    final api = _Api()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home:
            AddressBookScreen(entityType: 'Person', canEdit: true, api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Address service unavailable'), findsOneWidget);
    final add = tester.widget<FloatingActionButton>(find.byWidgetPredicate(
        (widget) =>
            widget is FloatingActionButton && widget.tooltip == 'Add address'));
    expect(add.onPressed, isNull);
    api.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Address service unavailable'), findsNothing);
    expect(find.text('No addresses yet.'), findsOneWidget);
  });

  testWidgets('late address responses are ignored after leaving the page',
      (tester) async {
    final api = _Api()..pending = Completer<List<Address>>();
    await tester.pumpWidget(MaterialApp(
        home:
            AddressBookScreen(entityType: 'Person', canEdit: true, api: api)));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('Another workspace')));
    api.pending!
        .complete([const Address(street: 'Private address from old session')]);
    await tester.pumpAndSettle();
    expect(find.text('Private address from old session'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor is scrollable at phone width with large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _Api();
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home:
            AddressBookScreen(entityType: 'Person', canEdit: true, api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add address'));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
