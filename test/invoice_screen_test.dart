import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/document.dart';
import 'package:qontract_app/models/invoice.dart';
import 'package:qontract_app/screens/invoice/invoices_screen.dart';
import 'package:qontract_app/services/api_service.dart';

class InvoiceApi extends ApiService {
  Map<String, dynamic>? saved;
  String? savedId;
  String? failure;
  bool archived = false;
  final invoice = Invoice(
      id: 'abc',
      invoiceDate: '2026-10-01',
      amount: '-1234567890.123456789',
      documentId: 42,
      invoiceNumber: 'Credit');
  @override
  Future<List<Contract>> getContractList() async => [];
  @override
  Future<List<Document>> getDocuments(int contractId) async => [];
  @override
  Future<List<Invoice>> getInvoices(
          {int? contractId, bool deleted = false, int page = 1}) async =>
      deleted == archived ? [invoice] : [];
  @override
  Future<Invoice> saveInvoice(Map<String, dynamic> data, {String? id}) async {
    if (failure != null) throw ApiException(message: failure!);
    saved = data;
    savedId = id;
    return invoice;
  }

  @override
  Future<void> archiveInvoice(String id) async {
    archived = true;
  }

  @override
  Future<void> restoreInvoice(String id) async {
    archived = false;
  }
}

Future<void> editor(WidgetTester tester, InvoiceApi api,
    {Invoice? invoice}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: InvoiceEditor(api: api, invoice: invoice))));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save'));
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  test('amount remains exact text and currency stays unknown', () {
    final invoice = Invoice.fromJson({
      'id': 'a',
      'invoiceDate': '2026-10-01',
      'amount': '-1234567890.123456789'
    });
    expect(invoice.amount, '-1234567890.123456789');
    expect(invoice.currency, isNull);
    expect(invoice.amountLabel, contains('currency unknown'));
    final doc = Document.fromJson({
      'id': 1,
      'contractId': 2,
      'contractIds': [3],
      'fileName': 'a',
      'uploadedAt': '2026-10-01T00:00:00Z'
    });
    expect(doc.contractIds, [2, 3]);
  });
  testWidgets(
      'editing preserves exact amount, unknown currency and retained evidence',
      (tester) async {
    final api = InvoiceApi();
    await editor(tester, api, invoice: api.invoice);
    await save(tester);
    expect(api.savedId, 'abc');
    expect(api.saved!['amount'], '-1234567890.123456789');
    expect(api.saved!['currency'], isNull);
    expect(api.saved!['documentId'], 42);
  });
  testWidgets('invalid dates and grouped amounts never save', (tester) async {
    final api = InvoiceApi();
    await editor(tester, api);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '2026-02-30');
    await tester.enterText(fields.at(2), '1.234,56');
    await save(tester);
    expect(api.saved, isNull);
    expect(find.text('Use yyyy-mm-dd'), findsOneWidget);
    expect(find.text('Enter an amount without currency or grouping'),
        findsOneWidget);
  });
  testWidgets('server failure keeps editor and values available for correction',
      (tester) async {
    final api = InvoiceApi()..failure = 'Document not found for this invoice.';
    await editor(tester, api, invoice: api.invoice);
    await save(tester);
    expect(find.text(api.failure!), findsOneWidget);
    expect(find.byType(InvoiceEditor), findsOneWidget);
    expect(api.saved, isNull);
  });
  testWidgets('archive confirmation and restore refresh invoice list',
      (tester) async {
    final api = InvoiceApi();
    await tester.pumpWidget(MaterialApp(home: InvoicesScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Credit ·'), findsOneWidget);
    await tester.tap(find.byTooltip('Archive invoice'));
    await tester.pumpAndSettle();
    expect(api.archived, false);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(api.archived, true);
    expect(find.text('No invoices yet.'), findsOneWidget);
    await tester.tap(find.byTooltip('Show archived invoices'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Restore invoice'));
    await tester.pumpAndSettle();
    expect(api.archived, false);
    await tester.tap(find.byTooltip('Show active invoices'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Credit ·'), findsOneWidget);
  });
}
