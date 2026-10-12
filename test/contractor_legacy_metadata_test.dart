import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/address.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_address_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/screens/contractor/contractor_form_screen.dart';
import 'package:qontract_app/screens/contractor/contractor_detail_screen.dart';
import 'package:qontract_app/services/api_service.dart';

class _Api extends ApiService {
  _Api() : super(baseUrl: 'http://localhost');
  Contractor? saved;
  @override
  Future<List<Address>> getContractorAddresses(int id) async => [];
  @override
  Future<Contractor> createContractor(Contractor c) async {
    saved = c;
    return c;
  }

  @override
  Future<Contractor> updateContractor(Contractor c) async {
    saved = c;
    return c;
  }
}

Contractor _contractor({String? website = ' https://example.com/path '}) =>
    Contractor.fromJson({
      'id': 1,
      'name': 'Legacy company',
      'type': 'Company',
      'tenantId': 1,
      'website': website,
      'description': ' Original description\n ',
      'notes': ' First line\nSecond line — ÄÖÜ\n ',
      'createdAt': '2026-01-01T00:00:00Z',
      'modifiedAt': '2026-01-01T00:00:00Z',
    });

Future<void> _open(
    WidgetTester tester, _Api api, Contractor? contractor) async {
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => ContractorProvider(api: api),
    child: MaterialApp(
        home: ContractorFormScreen(contractor: contractor),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Saved')))),
  ));
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final website in ['https://example.com', 'www.example.com']) {
    testWidgets('details show metadata at phone width: $website',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _Api();
      final c = _contractor(website: website);
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ContractorProvider(api: api)),
            ChangeNotifierProvider(
                create: (_) => ContractorAddressProvider(api: api)),
            ChangeNotifierProvider(create: (_) => ContractProvider(api: api)),
          ],
          child: MaterialApp(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                    settings: RouteSettings(arguments: c),
                    builder: (_) => const ContractorDetailScreen(),
                  ))));
      await tester.pumpAndSettle();
      await _show(tester, find.text(website));
      expect(find.byTooltip('Open website'),
          c.websiteUri == null ? findsNothing : findsOneWidget);
      await _show(tester, find.text(c.notes!));
      expect(find.text(c.description!), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('metadata remains verbatim in payloads and copies', () {
    final c = _contractor();
    for (final json in [
      c.toCreateJson(),
      c.toUpdateJson(),
      c.copyWith(isActive: false).toUpdateJson()
    ]) {
      expect(json['website'], c.website);
      expect(json['description'], c.description);
      expect(json['notes'], c.notes);
    }
    expect(
        c
            .copyWith(website: '', description: '', notes: '')
            .toUpdateJson()['notes'],
        '');
    expect(_contractor(website: null).toUpdateJson().containsKey('website'),
        false);
  });
  test('only valid absolute HTTP and HTTPS websites enable opening', () {
    expect(_contractor().websiteUri.toString(), 'https://example.com/path');
    expect(_contractor(website: 'http://example.com').websiteUri, isNotNull);
    for (final raw in [
      null,
      '',
      'www.example.com',
      'javascript:alert(1)',
      'file:///private',
      'data:text/html,test',
      'https://',
      'https://user@example.com',
      'https://bad host.com'
    ]) {
      expect(_contractor(website: raw).websiteUri, isNull, reason: '$raw');
    }
  });
  testWidgets('editing preserves source whitespace and multiline text',
      (tester) async {
    final api = _Api();
    await _open(tester, api, _contractor());
    final save = find.widgetWithText(ElevatedButton, 'Update Contractor');
    await _show(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.saved!.website, _contractor().website);
    expect(api.saved!.description, _contractor().description);
    expect(api.saved!.notes, _contractor().notes);
  });
  testWidgets('editing explicitly clears each metadata field', (tester) async {
    final api = _Api();
    await _open(tester, api, _contractor());
    for (final key in [
      'contractorWebsite',
      'contractorDescription',
      'contractorNotes'
    ]) {
      final field = find.byKey(Key(key));
      await _show(tester, field);
      await tester.enterText(field, '');
    }
    final save = find.widgetWithText(ElevatedButton, 'Update Contractor');
    await _show(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.saved!.toUpdateJson()['website'], '');
    expect(api.saved!.toUpdateJson()['description'], '');
    expect(api.saved!.toUpdateJson()['notes'], '');
  });
  testWidgets('creation submits description, website and multiline notes',
      (tester) async {
    final api = _Api();
    await _open(tester, api, null);
    await tester.enterText(find.byType(TextFormField).first, 'New company');
    final values = {
      'contractorWebsite': 'www.example.com',
      'contractorDescription': 'Description',
      'contractorNotes': 'Line one\nLine two'
    };
    for (final entry in values.entries) {
      final field = find.byKey(Key(entry.key));
      await _show(tester, field);
      await tester.enterText(field, entry.value);
    }
    final save = find.widgetWithText(ElevatedButton, 'Add Contractor');
    await _show(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.saved!.website, 'www.example.com');
    expect(api.saved!.description, 'Description');
    expect(api.saved!.notes, 'Line one\nLine two');
  });
}
