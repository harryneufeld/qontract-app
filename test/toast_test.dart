import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/providers/contract_provider.dart';
import 'package:qontract_app/providers/contractor_provider.dart';
import 'package:qontract_app/screens/contract/contract_form_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/widgets/app_toast.dart';

/// Toast feedback for user actions (app#28).
///
/// Covers the shared helper's styling (success/error/info) and proves that a
/// real action point (saving a contract) surfaces a toast — both the success
/// and the error path.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('showToast helper', () {
    testWidgets('renders a success toast with a check icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: _Harness(onReady: (ctx) =>
              showToast(ctx, 'Contract saved.', style: ToastStyle.success)),
        ),
      );
      await _showAndHoldToast(tester);

      expect(find.text('Contract saved.'), findsOneWidget);
      final icon = tester.widget<Icon>(
          find.descendant(of: find.byType(SnackBar), matching: find.byType(Icon)));
      expect(icon.icon, Icons.check_circle_rounded);
    });

    testWidgets('renders an error toast with an error icon and container colour',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: _Harness(onReady: (ctx) =>
              showToast(ctx, 'Delete failed.', style: ToastStyle.error)),
        ),
      );
      await _showAndHoldToast(tester);

      expect(find.text('Delete failed.'), findsOneWidget);
      final icon = tester.widget<Icon>(
          find.descendant(of: find.byType(SnackBar), matching: find.byType(Icon)));
      expect(icon.icon, Icons.error_rounded);
      final snackbar = tester.widgetList(find.byType(SnackBar)).first as SnackBar;
      // Error toasts use a themed container (non-null) and a floating shape.
      expect(snackbar.backgroundColor, isNotNull);
      expect(snackbar.behavior, SnackBarBehavior.floating);
    });

    testWidgets('default style is info', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: _Harness(onReady: (ctx) => showToast(ctx, 'Hello.')),
        ),
      );
      await _showAndHoldToast(tester);

      final icon = tester.widget<Icon>(
          find.descendant(of: find.byType(SnackBar), matching: find.byType(Icon)));
      expect(icon.icon, Icons.info_outline_rounded);
    });
  });

  group('contract form save toasts (app#28)', () {
    testWidgets('shows a success toast after creating a contract',
        (tester) async {
      final api = _FakeApi();
      await _pumpContractForm(tester, api);
      await tester.pumpAndSettle();

      // Title is the first text field on the form.
      await tester.enterText(find.byType(TextFormField).first, 'Lease 2026');
      await _tapCreate(tester);

      expect(api.createCalls, 1);
      // The toast renders on the destination screen after the pop.
      expect(find.text('Contract saved.'), findsOneWidget);
    });

    testWidgets('shows an error toast when the API rejects the save',
        (tester) async {
      final api = _FakeApi(
          createException:
              ApiException(message: 'Title is required.', statusCode: 400));
      await _pumpContractForm(tester, api);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Lease 2026');
      await _tapCreate(tester);

      expect(find.text('Title is required.'), findsOneWidget);
    });
  });
}

/// Lets the (async) action complete and the toast appear, but pumps far less
/// than the toast's 3s lifetime so the SnackBar is still on screen when we
/// assert. (A plain `pumpAndSettle` would advance 3s of fake time and let the
/// SnackBar dismiss before the assertion.)
Future<void> _showAndHoldToast(WidgetTester tester) async {
  await tester.pump(); // run the pending async action
  await tester.pump(const Duration(milliseconds: 300)); // toast enters
}

/// Scrolls the (below-the-fold) submit button into view and taps it, then
/// lets the async save complete and the toast appear while keeping it on
/// screen (well under its 3s lifetime).
Future<void> _tapCreate(WidgetTester tester) async {
  // Scope to the ElevatedButton: the AppBar title also reads
  // "Create Contract", so a plain text finder is ambiguous.
  final createButton = find.descendant(
    of: find.byType(ElevatedButton),
    matching: find.text('Create Contract'),
  );
  await tester.scrollUntilVisible(
    createButton,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(createButton);
  await _showAndHoldToast(tester);
}

// ------------------------------------------------------------------ helpers

Future<void> _pumpContractForm(WidgetTester tester, _FakeApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<ContractProvider>.value(
              value: ContractProvider(api: api)),
          ChangeNotifierProvider<ContractorProvider>.value(
              value: ContractorProvider(api: api)),
        ],
        child: const ContractFormScreen(),
      ),
    ),
  );
}

/// A minimal screen with a Scaffold (so a [ScaffoldMessenger] exists) that
/// runs [onReady] once built.
class _Harness extends StatefulWidget {
  const _Harness({required this.onReady});
  final void Function(BuildContext context) onReady;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReady(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

/// Records contract creation and optionally fails it.
class _FakeApi extends ApiService {
  _FakeApi({this.createException}) : super(baseUrl: 'http://localhost');

  final Object? createException;
  int createCalls = 0;

  @override
  Future<Contract> createContract(Contract contract) async {
    createCalls++;
    final ex = createException;
    if (ex != null) throw ex;
    return Contract(
      id: 42,
      title: contract.title,
      description: contract.description,
      status: contract.status,
      startDate: contract.startDate,
      endDate: contract.endDate,
      minimumContractDate: contract.minimumContractDate,
      currency: contract.currency,
      value: contract.value,
      contractorId: contract.contractorId,
      contractNumber: contract.contractNumber,
      createdAt: contract.createdAt,
      modifiedAt: contract.modifiedAt,
    );
  }

  @override
  Future<List<Contractor>> getContractors() async => const [];

  @override
  Future<Contractor> createContractor(Contractor c) async =>
      throw UnimplementedError();
}
