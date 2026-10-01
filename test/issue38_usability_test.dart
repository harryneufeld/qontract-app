import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/app_routes.dart';
import 'package:qontract_app/models/address.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/document.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_address_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/providers/document_provider.dart';
import 'package:qontract_app/screens/contract/contract_detail_screen.dart';
import 'package:qontract_app/screens/contractor/contractor_form_screen.dart';
import 'package:qontract_app/screens/contractor/contractor_list_screen.dart';
import 'package:qontract_app/services/api_service.dart';

Contract _contract(String title) => Contract(
    id: 1,
    title: title,
    status: 'Active',
    description: 'Current description',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026));
Contractor _contractor({bool active = true}) => Contractor(
    id: 2,
    name: 'Supplier',
    type: ContractorType.company,
    isActive: active,
    tenantId: 1,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026));

class _Api extends ApiService {
  _Api() : super(baseUrl: 'http://localhost');
  var contractor = _contractor(active: false);
  var contract = _contract('Old title');
  int detailCalls = 0;
  int documentCalls = 0;
  int activationCalls = 0;
  bool failRefresh = false;
  bool emptyContractors = false;
  int listCalls = 0;
  @override
  Future<Contract> updateContract(int id, Contract value) async =>
      contract = value;
  @override
  Future<Contract> getContract(int id) async {
    detailCalls++;
    if (failRefresh) throw ApiException(message: 'Refresh unavailable.');
    return contract;
  }

  @override
  Future<List<Document>> getDocuments(int id) async {
    documentCalls++;
    return [];
  }

  @override
  Future<List<Contractor>> getContractors() async {
    listCalls++;
    return emptyContractors ? [] : [contractor];
  }

  @override
  Future<List<Address>> getContractorAddresses(int id) async => [];
  @override
  Future<Contractor> createContractor(Contractor value) async =>
      contractor = value.copyWith(id: 3);
  @override
  Future<Contractor> activateContractor(int id) async {
    activationCalls++;
    return contractor = contractor.copyWith(isActive: true);
  }
}

Widget _app(_Api api, Widget home, {Map<String, WidgetBuilder>? routes}) =>
    MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => ContractProvider(api: api)),
      ChangeNotifierProvider(create: (_) => ContractorProvider(api: api)),
      ChangeNotifierProvider(
          create: (_) => ContractorAddressProvider(api: api)),
      ChangeNotifierProvider(create: (_) => DocumentProvider(api: api)),
    ], child: MaterialApp(home: home, routes: routes ?? AppRoutes.routes));

void main() {
  testWidgets('empty contractor list can be refreshed by dragging',
      (tester) async {
    final api = _Api()..emptyContractors = true;
    await tester.pumpWidget(_app(api, const ContractorListScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No contractors yet'), findsOneWidget);
    api.emptyContractors = false;
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(api.listCalls, 2);
    expect(find.text('Supplier'), findsOneWidget);
  });

  testWidgets(
      'detail reactivation updates a contractor opened without a cached list',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(_app(
        api,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.pushNamed(
                        context, AppRoutes.contractorDetail,
                        arguments: api.contractor),
                    child: const Text('Open detail'))))));
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reactivate'));
    await tester.pumpAndSettle();
    expect(api.activationCalls, 1);
    expect(find.byTooltip('Deactivate'), findsOneWidget);
    expect(find.text('Inactive'), findsNothing);
  });

  testWidgets(
      'contract detail shows the saved response immediately after editing',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(
        _app(api, ContractDetailScreen(contract: api.contract), routes: {
      '/contract/edit': (context) => Scaffold(
          body: TextButton(
              onPressed: () async {
                await context
                    .read<ContractProvider>()
                    .updateContract(_contract('Saved title'));
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Save edit'))),
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save edit'));
    await tester.pumpAndSettle();
    expect(find.text('Saved title'), findsOneWidget);
    expect(find.text('Old title'), findsNothing);
  });

  testWidgets(
      'pull-to-refresh fetches fresh contract and documents; failure keeps the detail',
      (tester) async {
    final api = _Api();
    await tester
        .pumpWidget(_app(api, ContractDetailScreen(contract: api.contract)));
    await tester.pumpAndSettle();
    api.contract = _contract('Server title');
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(api.detailCalls, 1);
    expect(api.documentCalls, 2);
    expect(find.text('Server title'), findsOneWidget);
    api.failRefresh = true;
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(api.detailCalls, 2);
    expect(find.text('Server title'), findsOneWidget);
  });

  testWidgets(
      'creating contractor opens its details and leaves the list underneath',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(_app(
        api,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const ContractorFormScreen())),
                    child: const Text('List home'))))));
    await tester.tap(find.text('List home'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'New supplier');
    final save = find.widgetWithText(ElevatedButton, 'Add Contractor');
    await tester.scrollUntilVisible(save, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('New supplier'), findsOneWidget);
    expect(find.byType(ContractorFormScreen), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('List home'), findsOneWidget);
  });

  testWidgets('inactive contractor can be reactivated from the list',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(_app(api, const ContractorListScreen()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Refresh'), findsNothing);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reactivate'));
    await tester.pumpAndSettle();
    expect(api.activationCalls, 1);
    expect(find.text('Inactive'), findsNothing);
    await tester.tap(find.text('Supplier'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Deactivate'), findsOneWidget);
  });
}
