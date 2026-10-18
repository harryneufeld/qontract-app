part of '../dashboard_cost_section_test.dart';

class _DesignApi extends _FakeApiService {
  _DesignApi(List<Contract> contracts)
      : super(contracts: contracts, contractors: [
          Contractor(
              id: 1,
              name: 'Northwind Services',
              type: ContractorType.company,
              tenantId: 7,
              isActive: true,
              website: 'https://example.com',
              description: 'Workspace services',
              email: 'hello@example.com',
              contractCount: 3,
              createdAt: DateTime.utc(2026),
              modifiedAt: DateTime.utc(2026)),
        ]);
  @override
  Future<List<Contract>> getContractTrash() async {
    if (failTrash) throw ApiException(message: 'Unavailable', statusCode: 503);
    return trashRows;
  }

  bool failTrash = false;
  List<Contract> trashRows = [];
  @override
  Future<String> getDefaultCurrency() async => 'EUR';
  @override
  Future<List<Document>> getDocuments(int contractId) async => [
        Document(
            id: 1,
            contractId: contractId,
            title: 'Service agreement',
            fileName: 'agreement.pdf',
            fileType: 'application/pdf',
            fileSize: 148000,
            uploadedAt: DateTime.utc(2026, 1, 5),
            documentDate: DateTime.utc(2026, 1, 1),
            version: 2),
        Document(
            id: 2,
            contractId: contractId,
            title: 'Updated service package',
            fileName: 'services.pdf',
            fileType: 'application/pdf',
            fileSize: 82000,
            uploadedAt: DateTime.utc(2026, 7, 1),
            documentDate: DateTime.utc(2026, 6, 15),
            version: 1),
      ];
  @override
  Future<List<Address>> getContractorAddresses(int contractorId) async => [];
  @override
  Future<List<Map<String, dynamic>>> getMemberships() async => [
        {
          'tenantId': 7,
          'name': 'Northwind workspace',
          'role': 'TenantAdmin',
          'type': 'Company'
        },
      ];
  @override
  Future<Map<String, dynamic>> getTenantDetails(int tenantId) async =>
      {'id': tenantId, 'settings': '{"defaultCurrency":"EUR"}'};
  @override
  Future<List<Map<String, dynamic>>> getTenantMembers(int tenantId) async => [
        {
          'id': 1,
          'name': 'Demo administrator',
          'email': 'demo@example.com',
          'role': 'TenantAdmin',
          'isActive': true
        },
      ];
  @override
  Future<List<Map<String, dynamic>>> getTenantInvitations(int tenantId) async =>
      [];
}

Contract _richContract() => Contract(
        documentCount: 2,
        responsibleUserId: 1,
        id: 1,
        title: 'Workspace services',
        status: 'Active',
        type: 'Subscription',
        contractorId: 1,
        contractNumber: 'CNT-2026-0042',
        currency: 'EUR',
        value: '49.00',
        billingPeriod: 'Monthly',
        startDate: '2026-01-01',
        endDate: '2027-12-31',
        minimumContractDate: '2026-12-31',
        iban: 'DE89 3704 0044 0532 0130 00',
        description:
            'Workspace access, meeting rooms and shared office services for the Northwind team.',
        notes:
            'Review the service package before the next renewal. Contact the account manager for changes.',
        createdAt: DateTime.utc(2026, 1, 5),
        modifiedAt: DateTime.utc(2026, 9, 18),
        createdBy: 'Demo administrator',
        modifiedBy: 'Demo administrator',
        priceHistory: [
          const ContractPrice(
              effectiveFrom: '2026-01-01',
              effectiveUntil: '2026-07-01',
              currency: 'EUR',
              value: '45.00',
              billingPeriod: 'Monthly',
              notes: 'Initial service package'),
          const ContractPrice(
              effectiveFrom: '2026-07-01',
              currency: 'EUR',
              value: '49.00',
              billingPeriod: 'Monthly',
              notes: 'Expanded workspace access'),
        ]);

Widget _designHarness(_DesignApi api, AuthProvider auth,
        {Widget? page, bool dark = false, double scale = 1}) =>
    MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ContractProvider(api: api)),
          ChangeNotifierProvider(create: (_) => ContractorProvider(api: api)),
          ChangeNotifierProvider(create: (_) => DocumentProvider(api: api)),
          ChangeNotifierProvider(
              create: (_) => ContractorAddressProvider(api: api)),
        ],
        child: RepaintBoundary(
            key: const Key('designPreview'),
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppTheme.dark : AppTheme.light,
                routes: AppRoutes.routes,
                home: page ?? DashboardScreen(api: api),
                builder: (context, child) => LayoutBuilder(
                    builder: (context, constraints) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            size: Size(
                                constraints.maxWidth, constraints.maxHeight),
                            textScaler: TextScaler.linear(scale)),
                        child: child!)))));

Future<void> _showOverviewTarget(WidgetTester tester, Finder target,
    {double delta = 200}) async {
  await tester.scrollUntilVisible(target, delta,
      scrollable: find
          .descendant(
              of: find.byType(SingleChildScrollView).first,
              matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
}

void _overviewCases() {
  testWidgets(
      'recent shortcuts do not present stale results during loading or failure',
      (tester) async {
    final pending = Completer<List<Contract>>();
    final api = _DesignApi([])..pending = pending;
    await tester.pumpWidget(_designHarness(api, await _seededAuth()));
    await tester.pump();
    expect(find.byKey(const Key('recentContracts')), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Your recently updated contracts will appear here.'),
        findsOneWidget);
    api.pending = null;
    api.failFullList = true;
    final context = tester.element(find.byType(DashboardScreen));
    await context.read<ContractProvider>().fetchAllContracts();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recentContracts')), findsNothing);
  });
  if (Platform.environment['QONTRACT_RECENT_PREVIEW_DIR'] != null) {
    testWidgets('export recent contract previews', (tester) async {
      final dir =
          Directory(Platform.environment['QONTRACT_RECENT_PREVIEW_DIR']!);
      await tester.runAsync(() async {
        await dir.create(recursive: true);
        const fonts = 'D:/Flutter/flutter/bin/cache/artifacts/material_fonts';
        for (final entry in {
          'Roboto': '$fonts/Roboto-Regular.ttf',
          'RobotoSlab': 'assets/fonts/RobotoSlab-Bold.ttf',
          'MaterialIcons': '$fonts/materialicons-regular.otf'
        }.entries) {
          final loader = FontLoader(entry.key)
            ..addFont(Future.value(
                ByteData.sublistView(await File(entry.value).readAsBytes())));
          await loader.load();
        }
      });
      for (final dark in [false, true]) {
        for (final size in [
          const Size(390, 844),
          const Size(1280, 1000),
          const Size(320, 800)
        ]) {
          for (final empty in [false, true]) {
            await tester.binding.setSurfaceSize(size);
            final api = _DesignApi(empty
                ? []
                : [
                    _richContract(),
                    _contract(2, 'Cloud storage'),
                    _contract(3, 'Insurance renewal')
                  ]);
            await tester.pumpWidget(_designHarness(api, await _seededAuth(),
                dark: dark, scale: size.width == 320 ? 2 : 1));
            await tester.pumpAndSettle();
            await _showOverviewTarget(
                tester, find.byKey(const Key('recentContracts')));
            expect(tester.takeException(), isNull);
            await _savePreview(tester, dir,
                'recent-${empty ? 'empty' : 'filled'}-${size.width.toInt()}-${dark ? 'dark' : 'light'}');
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets(
      'dashboard recent shortcuts sort by update date, cap at three and respect scope',
      (tester) async {
    Contract recent(int id, int day, {int user = 1, bool deleted = false}) =>
        Contract(
            id: id,
            title: 'Recent $id',
            status: 'Active',
            responsibleUserId: user,
            responsibleUserName: 'Member $user',
            contractNumber: 'CNT-$id',
            createdAt: DateTime.utc(2026),
            modifiedAt: DateTime.utc(2026, 10, day),
            deletedAt: deleted ? DateTime.utc(2026, 10, day) : null);
    final api = _DesignApi([
      recent(1, 1),
      recent(2, 12),
      recent(3, 14, user: 2),
      recent(4, 16),
      recent(5, 18, deleted: true)
    ]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth()));
    await tester.pumpAndSettle();
    final section = find.byKey(const Key('recentContracts'));
    await _showOverviewTarget(tester, section);
    final rows = tester
        .widgetList<ListTile>(
            find.descendant(of: section, matching: find.byType(ListTile)))
        .toList();
    expect(rows.map((r) => r.key), [
      const ValueKey('recentContract.4'),
      const ValueKey('recentContract.3'),
      const ValueKey('recentContract.2')
    ]);
    await tester.ensureVisible(find.byKey(const Key('responsibleUserFilter')));
    await tester.tap(find.byKey(const Key('responsibleUserFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'My contracts'));
    await tester.pumpAndSettle();
    await _showOverviewTarget(tester, section);
    expect(
        find.descendant(
            of: section,
            matching: find.byKey(const ValueKey('recentContract.3'))),
        findsNothing);
    expect(
        find.descendant(
            of: section,
            matching: find.byKey(const ValueKey('recentContract.1'))),
        findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('recentContract.4')));
    await tester.tap(find.byKey(const ValueKey('recentContract.4')));
    await tester.pumpAndSettle();
    expect(find.byType(ContractDetailScreen), findsOneWidget);
    expect(
        tester
            .widget<ContractDetailScreen>(find.byType(ContractDetailScreen))
            .contract
            .id,
        4);
  });

  if (Platform.environment['QONTRACT_IMPORT_MENU_PREVIEW_DIR'] != null) {
    testWidgets('export add menu previews', (tester) async {
      final dir =
          Directory(Platform.environment['QONTRACT_IMPORT_MENU_PREVIEW_DIR']!);
      await tester.runAsync(() async {
        await dir.create(recursive: true);
        const fonts = 'D:/Flutter/flutter/bin/cache/artifacts/material_fonts';
        for (final entry in {
          'Roboto': '$fonts/Roboto-Regular.ttf',
          'RobotoSlab': 'assets/fonts/RobotoSlab-Bold.ttf',
          'MaterialIcons': '$fonts/materialicons-regular.otf'
        }.entries) {
          final loader = FontLoader(entry.key)
            ..addFont(Future.value(
                ByteData.sublistView(await File(entry.value).readAsBytes())));
          await loader.load();
        }
      });
      for (final dark in [false, true]) {
        for (final size in [
          const Size(390, 844),
          const Size(1280, 1000),
          const Size(320, 800)
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(_designHarness(
              _DesignApi([]), await _seededAuth(),
              dark: dark, scale: size.width == 320 ? 2 : 1));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Add'));
          await tester.pumpAndSettle();
          expect(find.byType(size.width < 600 ? BottomSheet : Dialog),
              findsOneWidget);
          expect(tester.takeException(), isNull);
          await _savePreview(tester, dir,
              'add-menu-${size.width.toInt()}-${dark ? 'dark' : 'light'}');
          await tester.pumpWidget(const SizedBox());
        }
      }
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets('dashboard plus offers contract or import and routes to either',
      (tester) async {
    final api = _DesignApi([]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Contract'), findsOneWidget);
    expect(find.text('Import document'), findsOneWidget);
    await tester.tap(find.text('Import document'));
    await tester.pumpAndSettle();
    expect(find.text('Choose PDF or image'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contract'));
    await tester.pumpAndSettle();
    expect(find.byType(ContractFormScreen), findsOneWidget);
  });
  testWidgets('dashboard add popup fits a narrow phone with enlarged text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        _designHarness(_DesignApi([]), await _seededAuth(), scale: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Contract'), findsOneWidget);
    expect(find.text('Import document'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('trash metric shows scoped counts and its list matches the scope',
      (tester) async {
    final api = _DesignApi([])
      ..trashRows = [
        for (final user in [1, 2])
          Contract(
              id: user,
              title: 'Queued $user',
              status: 'Active',
              responsibleUserId: user,
              deletedAt: DateTime.utc(2026),
              createdAt: DateTime.utc(2026),
              modifiedAt: DateTime.utc(2026)),
      ];
    await tester.pumpWidget(_designHarness(api, await _seededAuth()));
    await tester.pumpAndSettle();
    final metric = find.byKey(const Key('deletionQueue'));
    expect(
        find.descendant(of: metric, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: metric, matching: find.text('Trash')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('responsibleUserFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My contracts'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(of: metric, matching: find.text('1')), findsOneWidget);
    await _showOverviewTarget(tester, metric);
    await tester.tap(metric);
    await tester.pumpAndSettle();
    expect(find.text('Queued 1'), findsOneWidget);
    expect(find.text('Queued 2'), findsNothing);
  });
  testWidgets('failed trash count remains unknown instead of showing zero',
      (tester) async {
    final api = _DesignApi([])..failTrash = true;
    await tester.pumpWidget(_designHarness(api, await _seededAuth()));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const Key('deletionQueue')),
            matching: find.text('—')),
        findsOneWidget);
  });
  testWidgets('responsible user filters every dashboard sum and count',
      (tester) async {
    final now = DateTime.now();
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final rows = <Contract>[];
    for (final user in [1, 2]) {
      var index = 0;
      for (final period in billingPeriods.keys) {
        index++;
        rows.add(Contract(
            id: user * 100 + index,
            title: '$period for $user',
            responsibleUserId: user,
            responsibleUserName: 'Member $user',
            status: 'Active',
            billingPeriod: period,
            value: '${index * (user == 1 ? 10 : 100)}',
            currency: period == 'Yearly' ? 'USD' : 'EUR',
            startDate: '2000-01-01',
            endDate: iso(now.add(const Duration(days: 14))),
            minimumContractDate: iso(now),
            priceHistory: period == 'Weekly'
                ? [
                    ContractPrice(
                        value: '${index * (user == 1 ? 10 : 100)}',
                        currency: 'EUR',
                        billingPeriod: period,
                        effectiveFrom: '2000-01-01',
                        effectiveUntil: iso(now.add(const Duration(days: 7)))),
                    ContractPrice(
                        value: '999',
                        currency: 'EUR',
                        billingPeriod: period,
                        effectiveFrom: iso(now.add(const Duration(days: 7)))),
                  ]
                : const [],
            createdAt: DateTime.utc(2000),
            modifiedAt: DateTime.utc(2000)));
      }
      for (final status in ['Draft', 'Expired', 'Active']) {
        rows.add(Contract(
            id: user * 100 + rows.length + 20,
            title: '$status extra for $user',
            responsibleUserId: user,
            responsibleUserName: 'Member $user',
            status: status,
            value: 'invalid',
            billingPeriod: 'Monthly',
            currency: 'EUR',
            createdAt: DateTime.utc(2000),
            modifiedAt: DateTime.utc(2000)));
      }
    }
    await tester
        .pumpWidget(_designHarness(_DesignApi(rows), await _seededAuth()));
    await tester.pumpAndSettle();
    void verify(int multiplier, int users) {
      var index = 0;
      for (final period in billingPeriods.keys) {
        index++;
        final currency = period == 'Yearly' ? 'USD' : 'EUR';
        expect(
            tester
                .widget<Text>(find.byKey(ValueKey('cost.$period.$currency')))
                .data,
            '$currency ${(index * multiplier).toStringAsFixed(2)}');
      }
      for (final entry
          in {'statTotal': 9, 'statActive': 7, 'statExpired': 1}.entries) {
        expect(
            find.descendant(
                of: find.byKey(Key(entry.key)),
                matching: find.text('${entry.value * users}')),
            findsOneWidget);
      }
      for (final entry in {
        'statExpiring': 6,
        'statMinDate': 6,
        'billingReview': 1,
        'priceChanges': 1
      }.entries) {
        expect(
            find.descendant(
                of: find.byKey(Key(entry.key)),
                matching: find.text(
                    '${entry.value * users} ${entry.value * users == 1 ? 'contract' : 'contracts'}')),
            findsOneWidget);
      }
      expect(find.text('$users to review: missing or invalid billing data'),
          findsNothing);
    }

    verify(110, 2);
    Future<void> select(String label) async {
      await tester.tap(find.byKey(const Key('responsibleUserFilter')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, label));
      await tester.pumpAndSettle();
    }

    await select('Member 2');
    verify(100, 1);
    await select('My contracts');
    verify(10, 1);
    await select('All workspace contracts');
    verify(110, 2);
  });

  testWidgets(
      'contracts search combines responsible user with search and status across pages',
      (tester) async {
    final rows = [
      for (var id = 1; id <= 26; id++)
        Contract(
            id: id,
            title: id == 26 ? 'Alpha peer contract' : 'Other $id',
            responsibleUserId: id == 26 ? 2 : 1,
            responsibleUserName: id == 26 ? 'Peer member' : 'My member',
            status: 'Active',
            createdAt: DateTime.utc(2000),
            modifiedAt: DateTime.utc(2000)),
    ];
    await tester.pumpWidget(_designHarness(
        _DesignApi(rows), await _seededAuth(),
        page: const ContractListScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('responsibleUserFilter')), findsOneWidget);
    await tester.tap(find.byKey(const Key('responsibleUserFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Peer member'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('resultCount'))).data,
        '1 result');
    await tester.enterText(find.byKey(const Key('contractSearch')), 'Alpha');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('resultCount'))).data,
        '1 result');
    await tester.tap(find.byKey(const Key('statExpired')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('resultCount'))).data,
        '0 results');
    await tester.tap(find.byKey(const Key('clearFilters')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('contractSearch')))
            .controller!
            .text,
        isEmpty);
    expect(
        tester
            .widget<ContractListScreen>(find.byType(ContractListScreen))
            .initialScope,
        'tenant');
    expect(
        find.descendant(
            of: find.byKey(const Key('responsibleUserFilter')),
            matching: find.text('Responsible user')),
        findsOneWidget);
  });

  testWidgets(
      'dashboard scopes costs to responsibility and preserves scope when browsing',
      (tester) async {
    Contract assigned(int id, int? user, String amount, {bool active = true}) =>
        Contract(
            id: id,
            title: 'Account $id',
            responsibleUserId: user,
            status: 'Active',
            isActive: active,
            value: amount,
            currency: 'EUR',
            billingPeriod: 'Monthly',
            startDate: '2000-01-01',
            createdAt: DateTime.utc(2000),
            modifiedAt: DateTime.utc(2000));
    final api = _DesignApi([
      assigned(1, 1, '10'),
      assigned(2, 2, '100'),
      assigned(3, null, '1000'),
      assigned(4, 1, '9999', active: false)
    ]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth()));
    await tester.pumpAndSettle();
    expect(find.text('EUR 1,110.00'), findsOneWidget);
    expect(find.text('EUR 10.00'), findsNothing);
    expect(find.byKey(const Key('browseContracts')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('statTotal'))).height,
        lessThan(160));
    await tester.tap(find.byTooltip('Filter by responsible user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('User #2'));
    await tester.pumpAndSettle();
    expect(find.text('EUR 100.00'), findsOneWidget);
    expect(find.text('EUR 1,110.00'), findsNothing);
    await tester.tap(find.byTooltip('Filter by responsible user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All workspace contracts'));
    await tester.pumpAndSettle();
    expect(find.text('EUR 1,110.00'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter by responsible user'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My contracts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('statTotal')));
    await tester.pumpAndSettle();
    expect(find.text('Account 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Account 4'), 200,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Account 4'), findsOneWidget);
    expect(find.text('Account 2'), findsNothing);
    expect(find.text('Account 3'), findsNothing);
  });

  testWidgets('minimum-term browsing keeps alphabetical order across all pages',
      (tester) async {
    final api = _DesignApi([
      for (var id = 1; id <= 26; id++)
        Contract(
            id: id,
            title: id == 26 ? 'Alpha ending contract' : 'Zed $id',
            status: 'Active',
            minimumContractDate: '2000-01-01',
            createdAt: DateTime.utc(2000),
            modifiedAt: DateTime.utc(2000))
    ]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth(),
        page: const ContractListScreen(initialFilter: 'minDate')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Alpha ending contract'), 200,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Alpha ending contract'), findsOneWidget);
    expect(find.byKey(const Key('loadMore')), findsNothing);
  });

  testWidgets(
      'filter reset updates visible fields and applies a clean selection',
      (tester) async {
    final api = _DesignApi([_richContract()]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth(),
        page: const ContractListScreen(
            initialFilter: 'expired', reviewBilling: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openFilters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    final status = tester
        .state<FormFieldState<String>>(find.byKey(const Key('statusFilter')));
    expect(status.value, 'all');
    expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const Key('reviewBillingFilter')))
            .value,
        false);
    await tester.tap(find.byKey(const Key('applyFilters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clearFilters')), findsNothing);
    expect(find.text('Workspace services'), findsOneWidget);
  });

  testWidgets(
      'type and period filters compose with search over the complete tenant',
      (tester) async {
    final api = _DesignApi([
      for (var i = 1; i <= 25; i++) _contract(i + 1, 'Other $i', value: '15'),
      _richContract(),
    ]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth(),
        page: const ContractListScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('contractSearch')), 'Workspace');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openFilters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('typeFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subscription').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('periodFilter')));
    await tester.tap(find.byKey(const Key('periodFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('applyFilters')));
    await tester.pumpAndSettle();
    expect(find.text('Workspace services'), findsOneWidget);
    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('Other 1'), findsNothing);
    expect(find.byKey(const Key('loadMore')), findsNothing);
  });

  testWidgets(
      'detail has side-by-side sections and bottom edit and delete actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _DesignApi([_richContract()]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth(),
        page: ContractDetailScreen(contract: _richContract())));
    await tester.pumpAndSettle();
    final information = tester.getTopLeft(find.text('Contract information'));
    final dates = tester.getTopLeft(find.text('Important dates'));
    expect(dates.dx, greaterThan(information.dx + 400));
    expect(dates.dy, information.dy);
    expect(find.text('Expanded workspace access'), findsOneWidget);
    expect(find.text('Updated by'), findsOneWidget);
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(tester.getTopLeft(find.byTooltip('Edit')).dy,
        greaterThan(appBarBottom + 700));
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Contract'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(ContractDetailScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(ContractFormScreen), findsOneWidget);
  });

  testWidgets('detail and filter sheet scroll at 320px with doubled text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final dark in [false, true]) {
      final api = _DesignApi([_richContract()]);
      await tester.pumpWidget(_designHarness(api, await _seededAuth(),
          page: ContractDetailScreen(contract: _richContract()),
          dark: dark,
          scale: 2));
      await tester.pumpAndSettle();
      await _showOverviewTarget(tester, find.text('Contract notes'));
      await _showOverviewTarget(tester, find.text('Documents'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_designHarness(api, await _seededAuth(),
          page: const ContractListScreen(), dark: dark, scale: 2));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('openFilters')), 150,
          scrollable: find
              .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable))
              .first);
      await tester.ensureVisible(find.byKey(const Key('openFilters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('openFilters')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('reviewBillingFilter')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close filters'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    }
  });

  test('contracts ending today stay in the upcoming calendar window', () {
    final now = DateTime.now();
    final endingToday = _contract(1, 'Ending today',
        endDate: DateTime(now.year, now.month, now.day)
            .toIso8601String()
            .substring(0, 10));
    expect(endingToday.isExpired, false);
    expect(endingToday.isExpiringSoon, true);
  });
  testWidgets(
      'overview keeps full lists and search on Contracts and drawer omits Invoices',
      (tester) async {
    final api =
        _DesignApi([_contract(1, 'Visible only in the library', value: '15')]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth()));
    await tester.pumpAndSettle();
    expect(find.byType(ContractListItem), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('statsExpand')), findsNothing);
    await tester.tap(find.byType(DrawerButton));
    await tester.pumpAndSettle();
    expect(find.text('Contracts'), findsOneWidget);
    expect(find.text('Invoices'), findsNothing);
    expect(find.text('Files'), findsNothing);
    expect(find.text('Import document'), findsNothing);
    expect(find.text('Tenants'), findsNothing);
    final dashboardTile = find
        .ancestor(
            of: find.text('Dashboard').last, matching: find.byType(ListTile))
        .first;
    expect(tester.getSize(dashboardTile).height, 48);
    await tester.tap(find.text('Contracts'));
    await tester.pumpAndSettle();
    expect(find.byType(ContractListScreen), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('deletion queue replaces the draft overview and opens safely',
      (tester) async {
    await tester
        .pumpWidget(_designHarness(_DesignApi([]), await _seededAuth()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('statDraft')), findsNothing);
    await _showOverviewTarget(tester, find.byKey(const Key('deletionQueue')));
    await tester.tap(find.byKey(const Key('deletionQueue')));
    await tester.pumpAndSettle();
    expect(find.text('Deletion queue'), findsOneWidget);
    expect(find.text('No contracts queued for deletion.'), findsOneWidget);
  });
  testWidgets(
      'billing review opens complete results and clear restores library',
      (tester) async {
    final api = _DesignApi([
      for (var i = 1; i <= 25; i++) _contract(i, 'Valid $i', value: '15'),
      _contract(26, 'Needs amount'),
    ]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth()));
    await tester.pumpAndSettle();
    await _showOverviewTarget(tester, find.byKey(const Key('billingReview')));
    await tester.tap(find.byKey(const Key('billingReview')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ContractListScreen>(find.byType(ContractListScreen))
            .reviewBilling,
        true);
    await tester.scrollUntilVisible(find.text('Needs amount'), 200,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Needs amount'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('clearFilters')), -200,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.byKey(const Key('clearFilters')));
    await tester.pumpAndSettle();
    expect(find.text('Billing details to review'), findsNothing);
  });

  test('price change insight includes next 30 days and excludes drafts', () {
    final now = DateTime.utc(2026, 10, 2);
    Contract changing(String date, {String status = 'Active'}) => Contract(
            responsibleUserId: 1,
            id: 1,
            title: 'Price change',
            status: status,
            createdAt: now,
            modifiedAt: now,
            priceHistory: [
              ContractPrice(
                  effectiveFrom: date, value: '25', billingPeriod: 'Monthly')
            ]);
    expect(hasUpcomingPriceChange(changing('2026-11-01'), now: now), true);
    expect(hasUpcomingPriceChange(changing('2026-11-02'), now: now), false);
    expect(hasUpcomingPriceChange(changing('2026-10-02'), now: now), false);
    expect(
        hasUpcomingPriceChange(changing('2026-10-03', status: 'Draft'),
            now: now),
        false);
  });

  testWidgets('contractor filter finds matches beyond the loaded page',
      (tester) async {
    final api = _DesignApi([
      for (var i = 1; i <= 25; i++) _contract(i, 'Other $i', value: '15'),
      Contract(
          responsibleUserId: 1,
          id: 26,
          title: 'Last-page contractor match',
          contractorId: 1,
          status: 'Active',
          createdAt: DateTime.utc(2026),
          modifiedAt: DateTime.utc(2026)),
    ]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth(),
        page: const ContractListScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openFilters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All contractors').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Northwind Services').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('applyFilters')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Last-page contractor match'), 200,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Last-page contractor match'), findsOneWidget);
    expect(find.text('Other 1'), findsNothing);
    expect(find.byKey(const Key('loadMore')), findsNothing);
  });

  testWidgets('complete-result filter fails explicitly and retries',
      (tester) async {
    final api = _DesignApi([_contract(1, 'Draft example', status: 'Draft')])
      ..failFullList = true;
    await tester.pumpWidget(_designHarness(api, await _seededAuth(),
        page: const ContractListScreen(initialFilter: 'draft')));
    await tester.pumpAndSettle();
    expect(find.text('Complete results unavailable. Please retry.'),
        findsOneWidget);
    expect(find.byType(ContractListItem), findsNothing);
    api.failFullList = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Draft example'), 200,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Draft example'), findsOneWidget);
  });

  testWidgets('library and forms adapt to doubled text at narrow widths',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final page in [
      const ContractListScreen(),
      const ContractFormScreen(),
      const ContractorFormScreen(),
      TenantsScreen(api: _DesignApi([])),
    ]) {
      final api = _DesignApi([
        _contract(1, 'Long contract title to wrap',
            value: '15', endDate: '2030-01-01')
      ]);
      await tester.pumpWidget(_designHarness(api, await _seededAuth(),
          page: page, dark: true, scale: 2));
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
              of: find.byType(
                  page is ContractListScreen ? CustomScrollView : ListView),
              matching: find.byType(Scrollable))
          .first;
      for (var i = 0; i < 12; i++) {
        await tester.drag(scrollable, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${page.runtimeType} scroll $i');
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
      'search and responsible field paint equal heights with enlarged text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final scale in [1.0, 1.3, 2.0]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_designHarness(
          _DesignApi([_richContract()]), await _seededAuth(),
          page: const ContractListScreen(), dark: true, scale: scale));
      await tester.pumpAndSettle();
      Finder borderFor(String key) => find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_BorderContainer'));
      final search = tester.getRect(borderFor('contractSearch'));
      final responsible = tester.getRect(borderFor('responsibleUserFilter'));
      expect(search.height, closeTo(responsible.height, 0.01));
      expect(responsible.top - search.bottom, closeTo(12, 0.01));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('overview handles phone width and doubled text in both themes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final dark in [false, true]) {
      final api = _DesignApi(
          [_contract(1, 'Demo', value: '15', startDate: '2000-01-01')]);
      await tester.pumpWidget(
          _designHarness(api, await _seededAuth(), dark: dark, scale: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('browseContracts')), findsNothing);
      await _showOverviewTarget(tester, find.byKey(const Key('priceChanges')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  if (Platform.environment['QONTRACT_PREVIEW_DIR'] != null) {
    testWidgets('export representative design previews with synthetic data',
        (tester) async {
      final dir = Directory(Platform.environment['QONTRACT_PREVIEW_DIR']!);
      await tester.runAsync(() async {
        await dir.create(recursive: true);
        final fonts = Platform.environment['QONTRACT_PREVIEW_FONT_DIR']!;
        final font = FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(
              await File('$fonts/Roboto-Regular.ttf').readAsBytes())));
        await font.load();
        final slab = FontLoader('RobotoSlab')
          ..addFont(Future.value(ByteData.sublistView(
              await File('assets/fonts/RobotoSlab-Bold.ttf').readAsBytes())));
        await slab.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(
              await File('$fonts/materialicons-regular.otf').readAsBytes())));
        await icons.load();
      });
      final dashboardOnly =
          Platform.environment['QONTRACT_DASHBOARD_PREVIEWS_ONLY'] == '1';
      final samples = [
        _richContract(),
        _contract(2, 'Cloud storage', value: '12', startDate: '2000-01-01'),
        _contract(3, 'Insurance renewal', status: 'Draft'),
      ];
      for (final dark in [false, true]) {
        for (final name in [
          'dashboard',
          'contracts',
          'contracts-active',
          'navigation',
          'contract-form',
          'contract-detail',
          'contracts-filters',
          'contractor-form',
          'contractor-detail',
          'tenants',
          'account',
          'contractors',
        ]) {
          if (dashboardOnly && name != 'dashboard') {
            continue;
          }
          await tester.binding.setSurfaceSize(const Size(1280, 1100));
          final api = _DesignApi(samples);
          final page = switch (name) {
            'contracts' || 'contracts-filters' => const ContractListScreen(),
            'contract-form' => const ContractFormScreen(),
            'contract-detail' => ContractDetailScreen(contract: samples.first),
            'contractor-form' =>
              ContractorFormScreen(contractor: api._contractors.first),
            'tenants' => TenantsScreen(api: api),
            'account' => AccountScreen(api: api),
            'contractors' => const ContractorListScreen(),
            _ => const DashboardScreen(),
          };
          await tester.pumpWidget(
              _designHarness(api, await _seededAuth(), page: page, dark: dark));
          await tester.pumpAndSettle();
          if (name == 'contractor-detail') {
            Navigator.of(tester.element(find.byType(DashboardScreen)))
                .pushNamed(AppRoutes.contractorDetail,
                    arguments: api._contractors.first);
            await tester.pumpAndSettle();
          }
          if (name == 'contracts-filters') {
            await tester.tap(find.byKey(const Key('openFilters')));
            await tester.pumpAndSettle();
          }
          if (name == 'navigation') {
            await tester.tap(find.byType(DrawerButton));
            await tester.pumpAndSettle();
          }
          if (name == 'contracts-active') {
            Navigator.of(tester.element(find.byType(DashboardScreen))).push(
                MaterialPageRoute<void>(
                    builder: (_) =>
                        const ContractListScreen(initialFilter: 'active')));
            await tester.pumpAndSettle();
          }
          await _savePreview(tester, dir, name + (dark ? '-dark' : '-light'));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final api = _DesignApi(samples);
      await tester.pumpWidget(_designHarness(api, await _seededAuth()));
      await tester.pumpAndSettle();
      await _savePreview(tester, dir, 'dashboard-phone');
      await _showOverviewTarget(tester, find.byKey(const Key('costSection')));
      await _savePreview(tester, dir, 'dashboard-phone-costs');
      expect(tester.takeException(), isNull);
      if (!dashboardOnly) {
        for (final dark in [false, true]) {
          for (final name in [
            'contracts-phone',
            'contract-detail-phone',
            'filters-phone',
            'tenants-phone',
            'contractors-phone',
            'contractor-detail-phone',
          ]) {
            await tester.pumpWidget(const SizedBox());
            final api = _DesignApi(samples);
            final page = name == 'contractor-detail-phone'
                ? DashboardScreen(api: api)
                : name == 'contract-detail-phone'
                    ? ContractDetailScreen(contract: samples.first)
                    : name == 'contractors-phone'
                        ? const ContractorListScreen()
                        : name == 'tenants-phone'
                            ? TenantsScreen(api: api)
                            : const ContractListScreen();
            await tester.pumpWidget(_designHarness(api, await _seededAuth(),
                page: page, dark: dark));
            await tester.pumpAndSettle();
            if (name == 'contractor-detail-phone') {
              Navigator.of(tester.element(find.byType(DashboardScreen)))
                  .pushNamed(AppRoutes.contractorDetail,
                      arguments: api._contractors.first);
              await tester.pumpAndSettle();
            }
            if (name == 'tenants-phone') {
              await tester.scrollUntilVisible(find.text('Tenant settings'), 180,
                  scrollable: find
                      .descendant(
                          of: find.byType(ListView).first,
                          matching: find.byType(Scrollable))
                      .first);
              await tester.pumpAndSettle();
            }
            if (name == 'filters-phone') {
              await tester.tap(find.byKey(const Key('openFilters')));
              await tester.pumpAndSettle();
            }
            await _savePreview(tester, dir, name + (dark ? '-dark' : '-light'));
            if (name == 'contracts-phone') {
              await tester.tap(find.byKey(const Key('responsibleUserFilter')));
              await tester.pumpAndSettle();
              await _savePreview(tester, dir,
                  'responsible-menu-phone-${dark ? 'dark' : 'light'}');
            }
            expect(tester.takeException(), isNull);
          }
        }
      }
      if (!dashboardOnly) {
        for (final dark in [false, true]) {
          for (final size in [const Size(375, 812), const Size(812, 375)]) {
            await tester.binding.setSurfaceSize(size);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpWidget(_designHarness(
                _DesignApi(samples), await _seededAuth(),
                page: ContractDetailScreen(contract: samples.first),
                dark: dark));
            await tester.pumpAndSettle();
            await _showOverviewTarget(tester, find.text('Documents'));
            await _savePreview(tester, dir,
                'detail-documents-${size.width.toInt()}-${dark ? 'dark' : 'light'}');
            expect(tester.takeException(), isNull);
          }
        }
      }
      await tester.binding.setSurfaceSize(null);
    });
  }
}

Future<void> _savePreview(
    WidgetTester tester, Directory dir, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('designPreview')));
  await tester.runAsync(() async {
    final rendered = await boundary.toImage(pixelRatio: 1);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    rendered.dispose();
  });
}
