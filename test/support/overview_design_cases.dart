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
  Future<List<Document>> getDocuments(int contractId) async => [
        Document(
            id: 1,
            contractId: contractId,
            title: 'Service agreement',
            fileName: 'agreement.pdf',
            fileType: 'application/pdf',
            fileSize: 148000,
            uploadedAt: DateTime.utc(2026, 1, 5),
            version: 2),
        Document(
            id: 2,
            contractId: contractId,
            title: 'Updated service package',
            fileName: 'services.pdf',
            fileType: 'application/pdf',
            fileSize: 82000,
            uploadedAt: DateTime.utc(2026, 7, 1),
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
                home: page ?? const DashboardScreen(),
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
    expect(find.text('EUR 10.00'), findsOneWidget);
    expect(find.text('EUR 1,110.00'), findsNothing);
    await tester.tap(find.text('Whole tenant'));
    await tester.pumpAndSettle();
    expect(find.text('EUR 1,110.00'), findsOneWidget);
    await tester.tap(find.text('My contracts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse contracts'));
    await tester.pumpAndSettle();
    expect(find.text('Account 1'), findsOneWidget);
    expect(find.text('Account 4'), findsOneWidget);
    expect(find.text('Account 2'), findsNothing);
    expect(find.text('Account 3'), findsNothing);
  });

  testWidgets(
      'filter reset updates visible fields and applies a clean selection',
      (tester) async {
    final api = _DesignApi([_richContract()]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth(),
        page: const ContractListScreen(
            initialFilter: 'draft', reviewBilling: true)));
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
      'overview has no contract list or filters and drawer omits Invoices',
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

  testWidgets('draft overview opens complete draft results beyond first page',
      (tester) async {
    final api = _DesignApi([
      for (var i = 1; i <= 25; i++) _contract(i, 'Active $i', value: '15'),
      _contract(26, 'Draft beyond page one', status: 'Draft'),
    ]);
    await tester.pumpWidget(_designHarness(api, await _seededAuth()));
    await tester.pumpAndSettle();
    await _showOverviewTarget(tester, find.byKey(const Key('statDraft')));
    await tester.tap(find.byKey(const Key('statDraft')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ContractListScreen>(find.byType(ContractListScreen))
            .initialFilter,
        'draft');
    await tester.scrollUntilVisible(find.text('Draft beyond page one'), 200,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Active 1'), findsNothing);
    expect(find.text('Draft beyond page one'), findsOneWidget);
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
      const ContractorFormScreen()
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
          'tenants'
        ]) {
          await tester.binding.setSurfaceSize(const Size(1280, 1100));
          final api = _DesignApi(samples);
          final page = switch (name) {
            'contracts' || 'contracts-filters' => const ContractListScreen(),
            'contract-form' => const ContractFormScreen(),
            'contract-detail' => ContractDetailScreen(contract: samples.first),
            'contractor-form' =>
              ContractorFormScreen(contractor: api._contractors.first),
            'tenants' => TenantsScreen(api: api),
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
      for (final dark in [false, true]) {
        for (final name in [
          'contracts-phone',
          'contract-detail-phone',
          'filters-phone'
        ]) {
          await tester.pumpWidget(const SizedBox());
          final page = name == 'contract-detail-phone'
              ? ContractDetailScreen(contract: samples.first)
              : const ContractListScreen();
          await tester.pumpWidget(_designHarness(
              _DesignApi(samples), await _seededAuth(),
              page: page, dark: dark));
          await tester.pumpAndSettle();
          if (name == 'filters-phone') {
            await tester.tap(find.byKey(const Key('openFilters')));
            await tester.pumpAndSettle();
          }
          await _savePreview(tester, dir, name + (dark ? '-dark' : '-light'));
          expect(tester.takeException(), isNull);
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
