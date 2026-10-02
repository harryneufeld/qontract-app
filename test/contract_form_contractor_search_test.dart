import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/screens/contract/contract_form_screen.dart';
import 'package:qontract_app/services/api_service.dart';

/// Records calls and serves canned data instead of hitting the backend.
class _FakeApiService extends ApiService {
  _FakeApiService(this._initial) : super(baseUrl: 'http://localhost');

  final List<Contractor> _initial;
  final List<String> calls = [];
  Contractor? lastCreated;

  @override
  Future<List<Contractor>> getContractors() async {
    calls.add('get');
    return _initial;
  }

  @override
  Future<Contractor> createContractor(Contractor c) async {
    calls.add('create');
    lastCreated = c;
    return c.copyWith(id: 100);
  }
}

Contractor _c(int id, {String name = 'Contractor'}) => Contractor(
      id: id,
      name: name,
      type: ContractorType.individual,
      tenantId: 1,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      modifiedAt: DateTime.utc(2026, 1, 1),
    );

Widget _harness(ContractorProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<ContractorProvider>.value(
      value: provider,
      child: const ContractFormScreen(),
    ),
  );
}

/// The contractor search field, located via its InputDecorator label.
Finder _contractorField() => find.byWidgetPredicate(
      (w) =>
          w is InputDecorator &&
          (w.decoration as InputDecoration?)?.labelText == 'Contractor',
    );

TextEditingController _contractorController(WidgetTester tester) {
  final element = tester.element(_contractorField());
  final field = element.findAncestorWidgetOfExactType<TextFormField>();
  expect(field, isNotNull, reason: 'contractor field must be a TextFormField');
  return field!.controller!;
}

void main() {
  group('ContractFormScreen contractor search (issue #9)', () {
    testWidgets('typing filters contractors and tapping selects',
        (tester) async {
      final api = _FakeApiService([
        _c(1, name: 'Acme Builders'),
        _c(2, name: 'Alpha Plumbing'),
        _c(3, name: 'Beta Welding'),
      ]);
      final provider = ContractorProvider(api: api);
      await tester.pumpWidget(_harness(provider));
      await tester.pumpAndSettle();

      // Focus the contractor field; names are listed while query is empty.
      await tester.tap(_contractorField());
      await tester.pumpAndSettle();
      expect(find.text('Acme Builders'), findsOneWidget);

      // Filtering narrows the list to name matches.
      await tester.enterText(_contractorField(), 'acme');
      await tester.pumpAndSettle();
      expect(find.text('Acme Builders'), findsOneWidget);
      expect(find.text('Alpha Plumbing'), findsNothing);

      // Tapping a suggestion fills the field with the exact name.
      await tester.ensureVisible(find.text('Acme Builders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acme Builders'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(_contractorField(), -200,
          scrollable: find
              .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable))
              .first);
      expect(_contractorController(tester).text, 'Acme Builders');
    });

    testWidgets('unknown name offers quick create with only a name',
        (tester) async {
      final api = _FakeApiService([_c(1, name: 'Acme Builders')]);
      final provider = ContractorProvider(api: api);
      await tester.pumpWidget(_harness(provider));
      await tester.pumpAndSettle();

      await tester.tap(_contractorField());
      await tester.enterText(_contractorField(), 'Gamma Corp');
      await tester.pumpAndSettle();

      // No exact match, so the create row is offered.
      final createTile = find.text('Create "Gamma Corp" as a new contractor');
      expect(createTile, findsOneWidget);

      await tester.ensureVisible(createTile);
      await tester.pumpAndSettle();
      await tester.tap(createTile);
      await tester.pumpAndSettle();

      expect(api.calls, contains('create'));
      expect(api.lastCreated?.name, 'Gamma Corp');
      expect(provider.contractors.map((c) => c.name), contains('Gamma Corp'));
      await tester.scrollUntilVisible(_contractorField(), -200,
          scrollable: find
              .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable))
              .first);
      expect(_contractorController(tester).text, 'Gamma Corp');
    });

    testWidgets('exact match does not offer the create row', (tester) async {
      final api = _FakeApiService([_c(1, name: 'Acme Builders')]);
      final provider = ContractorProvider(api: api);
      await tester.pumpWidget(_harness(provider));
      await tester.pumpAndSettle();

      await tester.tap(_contractorField());
      await tester.enterText(_contractorField(), 'Acme Builders');
      await tester.pumpAndSettle();

      expect(find.text('Create "Acme Builders" as a new contractor'),
          findsNothing);
    });
  });
}
