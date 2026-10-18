import 'dart:convert';
import 'package:qontract_app/screens/document/import_preview_screen.dart';
import 'package:qontract_app/l10n/strings.dart';
import 'package:qontract_app/app_routes.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:qontract_app/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qontract_app/models/contract.dart';
import 'package:qontract_app/models/contractor.dart';
import 'package:qontract_app/models/document.dart';
import 'package:qontract_app/providers/document_provider.dart';
import 'package:qontract_app/screens/document/document_import_screen.dart';
import 'package:qontract_app/services/api_service.dart';
import 'package:qontract_app/services/document_contract_matcher.dart';
import 'package:qontract_app/services/document_import_service.dart';
import 'package:qontract_app/widgets/date_picker_form_field.dart';

Contract contract(int id, String title, {String? number, String? iban}) =>
    Contract(
        id: id,
        title: title,
        status: 'Active',
        tenantId: 1,
        contractorId: 10,
        contractNumber: number,
        iban: iban,
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026));

final contracts = [
  contract(1, 'Home insurance',
      number: 'CNT-2026-0042', iban: 'DE89 3704 0044 0532 0130 00'),
  contract(2, 'Car insurance', number: 'CNT-2026-0043'),
];
final contractor = Contractor(
    id: 10,
    name: 'Example Insurance',
    type: ContractorType.company,
    tenantId: 1,
    isActive: true,
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026));
const picked = PickedDocument(name: 'scan.pdf', bytes: [37, 80, 68, 70, 45]);

class ImportService extends DocumentImportService {
  String content = 'Contract CNT-2026-0042';
  Object? failure;
  bool discardFails = false;
  PickedDocument? source;
  Completer<void>? recognitionGate;
  final removed = <String>[];
  @override
  Future<List<PendingDocument>> pending() async =>
      [const PendingDocument('pending-1', 'scan.pdf')];
  @override
  Future<PickedDocument> read(String id) async => source ?? picked;
  @override
  Future<void> discard(String id) async {
    if (discardFails) throw StateError('Cleanup failed');
    removed.add(id);
  }

  @override
  Future<DocumentText> recognize(PickedDocument file) async {
    if (recognitionGate != null) await recognitionGate!.future;
    if (failure != null) throw failure!;
    return DocumentText(content);
  }
}

class ImportApi extends ApiService {
  int? destination;
  String? scope;
  List<int>? bytes;
  String? failure;
  bool contractsFail = false;
  int uploads = 0;
  DateTime? savedDate;
  String? savedTitle;
  @override
  Future<List<Contract>> getContractList() async {
    if (contractsFail) throw ApiException(message: 'Offline');
    return contracts;
  }

  @override
  Future<List<Contractor>> getContractors() async => [contractor];
  Document document() => Document(
      id: 1,
      fileName: 'scan.pdf',
      fileType: 'application/pdf',
      fileSize: 5,
      uploadedAt: DateTime(2026),
      version: 1);
  @override
  Future<Document> uploadDocument(int contractId,
      {required String fileName,
      required String fileType,
      required List<int> fileData,
      String? title,
      DateTime? documentDate}) async {
    uploads++;
    if (failure != null) throw ApiException(message: failure!);
    destination = contractId;
    savedDate = documentDate;
    savedTitle = title;
    bytes = fileData;
    return document();
  }

  @override
  Future<Document> uploadLibraryDocument(
      {required String scope,
      required String fileName,
      required String fileType,
      required List<int> fileData,
      String? title,
      String? description,
      String? category,
      DateTime? documentDate}) async {
    uploads++;
    if (failure != null) throw ApiException(message: failure!);
    this.scope = scope;
    savedDate = documentDate;
    savedTitle = title;
    bytes = fileData;
    return document();
  }
}

Future<void> open(WidgetTester tester, ImportApi api, ImportService service,
    {bool shared = true,
    double scale = 1,
    bool dark = false,
    bool settle = true}) async {
  await tester.pumpWidget(RepaintBoundary(
      key: const Key('importPreview'),
      child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          debugShowCheckedModeBanner: false,
          routes: {
            AppRoutes.contractDetail: (context) {
              final contract =
                  ModalRoute.of(context)!.settings.arguments as Contract;
              return Scaffold(
                  appBar: AppBar(title: const Text('Contract details')),
                  body: Text('Opened ${contract.title}',
                      key: ValueKey('openedContract.${contract.id}')));
            }
          },
          builder: (context, child) => LayoutBuilder(
              builder: (context, constraints) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      textScaler: TextScaler.linear(scale)),
                  child: child!)),
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<bool>(
                              builder: (_) => DocumentImportScreen(
                                  api: api,
                                  service: service,
                                  incomingId: shared ? 'pending-1' : null,
                                  pickFile: () async => picked))),
                      child: const Text('Import')))))));
  await tester.tap(find.text('Import'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> press(WidgetTester tester, String label) async {
  if (label == 'Save without a contract' &&
      find.widgetWithText(FilledButton, label).evaluate().isEmpty) {
    await tester.ensureVisible(find.text('Without a contract'));
    await tester.tap(find.text('Without a contract'));
    await tester.pumpAndSettle();
  }
  final finder = find.widgetWithText(FilledButton, label);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'unique highest scoring contract is the default and remains editable',
      (tester) async {
    final api = ImportApi();
    await open(tester, api, ImportService());
    expect(
        find.widgetWithText(FilledButton, 'Add to contract'), findsOneWidget);
    expect(find.textContaining('Match score: 100 points'), findsOneWidget);
    expect(api.uploads, 0);
    await press(tester, 'Add to contract');
    expect(api.destination, 1);
  });
  test('equal matching scores do not default to an arbitrary contract', () {
    final matches = DocumentContractMatcher.rank('Example Insurance', contracts,
        contractors: [contractor]);
    expect(matches, hasLength(2));
    expect(DocumentContractMatcher.bestDefault(matches), isNull);
  });

  testWidgets('PDF preview failure stays local and offers return to review',
      (tester) async {
    const pdfChannel = MethodChannel('io.scer.pdf_renderer');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pdfChannel, (call) async {
      if (call.method == 'open.document.data') {
        expect(call.arguments, picked.bytes);
        throw PlatformException(code: 'invalid_pdf');
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(pdfChannel, null));
    final api = ImportApi();
    final service = ImportService();
    await open(tester, api, service);
    await tester.tap(find.byKey(const Key('openImportPreview')));
    await tester.pumpAndSettle();
    expect(find.byType(ImportPreviewScreen), findsOneWidget);
    expect(find.text('Back to review'), findsOneWidget);
    expect(api.uploads, 0);
    await tester.tap(find.text('Back to review'));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentImportScreen), findsOneWidget);
  });

  testWidgets('known numbers without a label are offered for review',
      (tester) async {
    final api = ImportApi();
    final service = ImportService()..content = 'Your reference CNT-2026-0042';
    await open(tester, api, service);
    await tester.tap(find.text('Review detected contract number'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, 'Contract number'))
            .controller!
            .text,
        'CNT-2026-0042');
    expect(api.uploads, 0);
  });
  testWidgets(
      'local preview preserves edits and does not upload when OCR fails',
      (tester) async {
    final api = ImportApi();
    final service = ImportService()
      ..failure = StateError('Unreadable')
      ..source = PickedDocument(
          name: 'photo.png',
          bytes: base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=='));
    await open(tester, api, service);
    await tester.enterText(
        find.widgetWithText(TextField, 'Document title'), 'My corrected title');
    await tester.tap(find.byKey(const Key('openImportPreview')));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byType(ImportPreviewScreen), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(api.uploads, 0);
    expect(service.removed, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Document title'))
            .controller!
            .text,
        'My corrected title');
  });

  testWidgets(
      'a short OCR heading is saved and its destination opens after import',
      (tester) async {
    final api = ImportApi();
    final service = ImportService()
      ..content =
          'Ihre neue Beitragsrechnung\nfür 2027\nSehr geehrte Kundin\nContract number: CNT-2026-0042';
    await open(tester, api, service);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Document title'))
            .controller!
            .text,
        'Ihre neue Beitragsrechnung für 2027');
    await tester.ensureVisible(find.text('Home insurance'));
    await tester.tap(find.text('Home insurance'));
    await tester.pumpAndSettle();
    await press(tester, 'Add to contract');
    expect(api.savedTitle, 'Ihre neue Beitragsrechnung für 2027');
    expect(find.byKey(const ValueKey('openedContract.1')), findsOneWidget);
    expect(find.byType(DocumentImportScreen), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Import'), findsOneWidget);
  });
  testWidgets(
      'successful attachment still opens its contract if inbox cleanup fails',
      (tester) async {
    final service = ImportService()..discardFails = true;
    final api = ImportApi();
    await open(tester, api, service);
    await tester.ensureVisible(find.text('Home insurance'));
    await tester.tap(find.text('Home insurance'));
    await tester.pumpAndSettle();
    await press(tester, 'Add to contract');
    expect(api.uploads, 1);
    expect(find.byKey(const ValueKey('openedContract.1')), findsOneWidget);
    expect(find.textContaining('Saved successfully.'), findsOneWidget);
  });

  testWidgets(
      'reviewing a number reranks matches and clears a previous destination',
      (tester) async {
    final service = ImportService()..content = 'Policy number: CNT-2026-0042';
    final api = ImportApi();
    await open(tester, api, service);
    await tester.ensureVisible(find.text('Home insurance'));
    await tester.tap(find.text('Home insurance'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review detected contract number'));
    await tester.tap(find.text('Review detected contract number'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(TextField, 'Contract number'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Contract number'), 'CNT-2026-0043');
    await tester.pumpAndSettle();
    expect(find.text('Home insurance'), findsNothing);
    expect(find.text('Car insurance'), findsOneWidget);
    expect(api.uploads, 0);
    await tester.ensureVisible(find.text('Car insurance'));
    await tester.tap(find.text('Car insurance'));
    await tester.pumpAndSettle();
    await press(tester, 'Add to contract');
    expect(api.destination, 2);
  });
  test('invoice and customer numbers do not create contract-number matches',
      () {
    expect(
        DocumentContractMatcher.rank(
            'Invoice number: CNT-2026-0042', contracts),
        isEmpty);
    expect(
        DocumentContractMatcher.rank(
            'Customer number: CNT-2026-0042', contracts),
        isEmpty);
  });

  test('wrapped customer labels do not become contract numbers', () {
    expect(
        DocumentContractMatcher.rank(
            'Customer number:\nCNT-2026-0042', contracts),
        isEmpty);
  });
  testWidgets(
      'metadata sources are disclosed only on request and dates can be selected',
      (tester) async {
    final service = ImportService()
      ..content =
          'Subject: Premium adjustment\nDate: 2026-10-18\nDate: 2026-10-17';
    final api = ImportApi();
    await open(tester, api, service);
    expect(find.text('“Subject: Premium adjustment”'), findsNothing);
    await tester.tap(find.text('Review detected date'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Date: 2026-10-17'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Date: 2026-10-17'));
    await tester.tap(find.textContaining('Date: 2026-10-17'));
    await tester.pumpAndSettle();
    await press(tester, 'Save without a contract');
    expect(api.savedDate, DateTime.utc(2026, 10, 17));
  });
  if (Platform.environment['QONTRACT_PREVIEW_DIR'] != null) {
    testWidgets('export import review previews', (tester) async {
      final dir = Directory(Platform.environment['QONTRACT_PREVIEW_DIR']!);
      S.languageCode = 'de';
      addTearDown(() => S.languageCode = 'en');
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
          for (final state in [
            'review',
            'empty',
            'error',
            'loading',
            'date',
            'number',
            'picker',
            'file-preview',
            'preview-error'
          ]) {
            await tester.binding.setSurfaceSize(size);
            final service = ImportService()
              ..content =
                  'Subject: Premium adjustment\nDocument date: 2026-10-18\nPolicy number: CNT-2026-0042';
            if (state == 'loading') {
              service.recognitionGate = Completer<void>();
            }
            if (state == 'error') {
              service.failure =
                  PlatformException(code: 'ocr', message: 'Unreadable PDF.');
            }
            if (state == 'file-preview' || state == 'preview-error') {
              final sample =
                  Platform.environment['QONTRACT_PREVIEW_SAMPLE_PATH'];
              final bytes = state == 'file-preview' && sample != null
                  ? await tester.runAsync(() => File(sample).readAsBytes())
                  : Uint8List.fromList([1, 2, 3]);
              service.source =
                  PickedDocument(name: 'example-letter.png', bytes: bytes!);
            }
            await open(tester, ImportApi(), service,
                dark: dark,
                shared: state != 'empty',
                settle: state != 'loading',
                scale: size.width == 320 ? 2 : 1);
            if (['date', 'number', 'picker'].contains(state)) {
              final label = state == 'date'
                  ? S.current.importReviewDate
                  : state == 'number'
                      ? S.current.importReviewNumber
                      : S.current.importAnotherContract;
              await tester.ensureVisible(find.text(label));
              await tester.pumpAndSettle();
              await tester.tap(find.text(label));
              await tester.pumpAndSettle();
            }
            if (state == 'file-preview' || state == 'preview-error') {
              await tester.tap(find.byKey(const Key('openImportPreview')));
              await tester.pumpAndSettle();
              await tester.runAsync(() async =>
                  Future<void>.delayed(const Duration(milliseconds: 50)));
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('importPreview')));
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '${dir.path}/import-$state-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets('reading disables save until recognition completes',
      (tester) async {
    final service = ImportService()..recognitionGate = Completer<void>();
    final api = ImportApi();
    await open(tester, api, service, settle: false);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save without a contract'))
            .onPressed,
        isNull);
    expect(api.uploads, 0);
    service.recognitionGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Add to contract'))
            .onPressed,
        isNotNull);
  });
  testWidgets(
      'metadata and evidence cards fit narrow screens with enlarged text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ImportApi();
    final service = ImportService()
      ..content =
          'Subject: Premium adjustment\nDocument date: 2026-10-18\nExample Insurance\nYour reference: CNT-2026-0042';
    await open(tester, api, service, scale: 2);
    final context = tester.element(find.byType(DocumentImportScreen));
    final data = MediaQuery.of(context);
    expect(data.size.width, 320);
    expect(data.textScaler.scale(1), 2);
    await tester.scrollUntilVisible(find.text('Home insurance'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    await press(tester, 'Save without a contract');
    expect(api.savedDate, DateTime.utc(2026, 10, 18));
  });
  testWidgets(
      'suggestions include source passages, contract number and contractor',
      (tester) async {
    final api = ImportApi();
    final service = ImportService()
      ..content = 'Example Insurance\nYour reference: CNT-2026-0042';
    await open(tester, api, service);
    await tester.scrollUntilVisible(find.text('Home insurance'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('CNT-2026-0042 · Example Insurance'),
        findsOneWidget);
    expect(find.text('“Your reference: CNT-2026-0042”'), findsNothing);
    await tester.ensureVisible(find.text('Matching text passages').first);
    await tester.tap(find.text('Matching text passages').first);
    await tester.pumpAndSettle();
    expect(find.text('“Your reference: CNT-2026-0042”'), findsOneWidget);
    expect(find.text('“Example Insurance”'), findsWidgets);
  });
  testWidgets('OCR date and subject are editable and saved with a contract',
      (tester) async {
    final api = ImportApi();
    final service = ImportService()
      ..content =
          'Subject: Premium adjustment\nDocument date: 2026-10-18\nCNT-2026-0042';
    await open(tester, api, service);
    await tester.tap(find.text('Review detected date'));
    await tester.pumpAndSettle();
    final date =
        tester.widget<DatePickerFormField>(find.byType(DatePickerFormField));
    expect(date.controller.text, '2026-10-18');
    final title = tester
        .widget<TextField>(find.widgetWithText(TextField, 'Document title'));
    expect(title.controller!.text, 'Premium adjustment');
    await tester.enterText(
        find.widgetWithText(TextField, 'Document title'), 'Reviewed premium');
    date.controller.text = '2026-10-17';
    await tester.scrollUntilVisible(find.text('Home insurance'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Home insurance'));
    await tester.pumpAndSettle();
    await press(tester, 'Add to contract');
    expect(api.savedTitle, 'Reviewed premium');
    expect(api.savedDate, DateTime.utc(2026, 10, 17));
  });
  testWidgets('suggested metadata also reaches the unassigned file library',
      (tester) async {
    final api = ImportApi();
    final service = ImportService()
      ..content = 'Betreff: Beitragsrechnung\nRechnungsdatum: 18.10.2026';
    await open(tester, api, service);
    await press(tester, 'Save without a contract');
    expect(api.savedTitle, 'Beitragsrechnung');
    expect(api.savedDate, DateTime.utc(2026, 10, 18));
  });
  testWidgets('invalid edited date prevents upload', (tester) async {
    final api = ImportApi();
    final service = ImportService();
    await open(tester, api, service);
    await tester.tap(find.text('Review detected date'));
    await tester.pumpAndSettle();
    tester
        .widget<DatePickerFormField>(find.byType(DatePickerFormField))
        .controller
        .text = '2026-02-31';
    await press(tester, 'Save without a contract');
    expect(api.uploads, 0);
    expect(find.text('Enter a valid calendar date.'), findsWidgets);
  });
  test('native bridge preserves bytes, text and normalized line positions',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(DocumentImportService.channel,
        (call) async {
      calls.add(call);
      switch (call.method) {
        case 'pending':
          return [
            {'id': 'one', 'name': 'scan.pdf'}
          ];
        case 'read':
          return {
            'name': 'scan.pdf',
            'bytes': Uint8List.fromList(picked.bytes)
          };
        case 'recognize':
          return {
            'text': 'CNT-2026-0042',
            'lines': [
              {
                'text': 'CNT-2026-0042',
                'top': 0.2,
                'left': 0.6,
                'height': 0.02,
                'isBold': true
              }
            ]
          };
        default:
          return null;
      }
    });
    try {
      final service = DocumentImportService();
      expect((await service.pending()).single.id, 'one');
      final file = await service.read('one');
      expect(file.bytes, picked.bytes);
      final result = await service.recognize(file);
      expect(result.text, 'CNT-2026-0042');
      expect(result.lines.single.top, .2);
      expect(result.lines.single.left, .6);
      expect(result.lines.single.height, .02);
      expect(result.lines.single.isBold, true);
      expect(result.lines.single.text, 'CNT-2026-0042');
      expect((calls.last.arguments as Map)['bytes'], picked.bytes);
      await service.discard('one');
      expect(calls.last.method, 'discard');
    } finally {
      messenger.setMockMethodCallHandler(DocumentImportService.channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
  test('replacing a workspace listener cannot detach its replacement',
      () async {
    var oldEvents = 0, newEvents = 0;
    void oldListener() => oldEvents++;
    void newListener() => newEvents++;
    DocumentImportService.addInboxListener(oldListener);
    DocumentImportService.addInboxListener(newListener);
    DocumentImportService.removeInboxListener(oldListener);
    try {
      var replied = false;
      ServicesBinding.instance.channelBuffers.push(
          DocumentImportService.channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('inboxChanged')),
          (_) => replied = true);
      await Future<void>.delayed(Duration.zero);
      expect(replied, true);
      expect(oldEvents, 0);
      expect(newEvents, 1);
    } finally {
      DocumentImportService.removeInboxListener(newListener);
    }
  });
  test('exact identifiers outrank shared contractor and IBAN hints', () {
    final result = DocumentContractMatcher.rank(
        'Example Insurance\nCNT / 2026 / 0042\nDE89 3704 0044 0532 0130 00',
        contracts,
        contractors: [contractor]);
    expect(result.first.contract.id, 1);
    expect(result.first.reasons,
        containsAll(['Contract number', 'Contractor name', 'IBAN']));
    expect(result.last.reasons, ['Contractor name']);
  });
  test('identifiers never match a substring of a longer identifier', () {
    expect(DocumentContractMatcher.rank('XCNT-2026-00420', contracts), isEmpty);
    expect(
        DocumentContractMatcher.rank(
            '1112345', [contract(3, 'Phone', number: '1234')]),
        isEmpty);
  });
  test('short numbers and generic partial titles produce no suggestion', () {
    expect(
        DocumentContractMatcher.rank('Insurance invoice 42',
            [contract(3, 'Car insurance', number: '42')]),
        isEmpty);
  });
  test('German spelling and punctuation are normalized for names', () {
    final result = DocumentContractMatcher.rank(
        'MULLER, STROM', [contract(1, 'Müller Strom')]);
    expect(result.single.reasons, ['Contract title']);
  });
  test('empty OCR produces no matches', () {
    expect(
        DocumentContractMatcher.rank('', contracts, contractors: [contractor]),
        isEmpty);
  });
  testWidgets('sharing preselects the strongest contract and waits for Save',
      (tester) async {
    final api = ImportApi();
    final service = ImportService();
    await open(tester, api, service);
    expect(find.text('Home insurance'), findsOneWidget);
    expect(find.textContaining('CNT-2026-0042 · Example Insurance'),
        findsOneWidget);
    expect(api.uploads, 0);
    expect(service.removed, isEmpty);
    await tester.ensureVisible(find.text('Home insurance'));
    await tester.tap(find.text('Home insurance'));
    await tester.pumpAndSettle();
    await press(tester, 'Add to contract');
    expect(api.destination, 1);
    expect(api.bytes, picked.bytes);
    expect(service.removed, ['pending-1']);
  });
  testWidgets('cancel retains the shared document without uploading',
      (tester) async {
    final api = ImportApi();
    final service = ImportService();
    await open(tester, api, service);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(api.uploads, 0);
    expect(service.removed, isEmpty);
  });
  testWidgets('OCR failure permits manual selection and original file upload',
      (tester) async {
    final api = ImportApi();
    final service = ImportService()
      ..failure = PlatformException(code: 'ocr', message: 'Unreadable PDF.');
    await open(tester, api, service);
    expect(find.textContaining('Unreadable PDF.'), findsOneWidget);
    await tester.ensureVisible(find.text('Choose another contract'));
    await tester.tap(find.text('Choose another contract'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Search contracts'), '0043');
    await tester.pumpAndSettle();
    expect(find.text('Home insurance'), findsNothing);
    await tester.tap(find.text('Car insurance'));
    await tester.pumpAndSettle();
    await press(tester, 'Add to contract');
    expect(api.destination, 2);
    expect(api.bytes, picked.bytes);
  });
  testWidgets('unmatched document can be saved privately without a contract',
      (tester) async {
    final api = ImportApi();
    final service = ImportService()..content = 'Unrelated receipt';
    await open(tester, api, service);
    expect(find.textContaining('No matching contract found.'), findsOneWidget);
    await press(tester, 'Save without a contract');
    expect(api.scope, 'Personal');
    expect(api.destination, isNull);
  });
  testWidgets('failed uploads keep the inbox file and allow retry',
      (tester) async {
    final api = ImportApi()..failure = 'Upload failed';
    final service = ImportService();
    await open(tester, api, service);
    await press(tester, 'Save without a contract');
    expect(find.text('Upload failed'), findsOneWidget);
    expect(service.removed, isEmpty);
    api.failure = null;
    await press(tester, 'Save without a contract');
    expect(api.uploads, 2);
    expect(service.removed, ['pending-1']);
  });
  testWidgets('contract loading can be retried without repeating recognition',
      (tester) async {
    final api = ImportApi()..contractsFail = true;
    final service = ImportService();
    await open(tester, api, service);
    expect(find.textContaining('Could not load contracts.'), findsOneWidget);
    api.contractsFail = false;
    await tester.tap(find.text('Retry loading contracts'));
    await tester.pumpAndSettle();
    expect(find.text('Home insurance'), findsOneWidget);
  });
  testWidgets('in-app picker uses the same recognition flow', (tester) async {
    final api = ImportApi();
    final service = ImportService();
    await open(tester, api, service, shared: false);
    await tester.tap(find.text('Choose PDF or image'));
    await tester.pumpAndSettle();
    expect(find.text('Home insurance'), findsOneWidget);
    expect(api.uploads, 0);
  });
}
