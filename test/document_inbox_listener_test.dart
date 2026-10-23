import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qontract_app/models/user.dart';
import 'package:qontract_app/providers/auth_provider.dart';
import 'package:qontract_app/screens/document/document_import_screen.dart';
import 'package:qontract_app/services/document_import_service.dart';
import 'package:qontract_app/widgets/document_inbox_listener.dart';

class _Auth extends AuthProvider {
  @override
  bool get isAuthenticated => true;
  @override
  User? get user => null;
}

class _Inbox extends DocumentImportService {
  final List<PendingDocument> files;
  final marked = <String>[];
  _Inbox(this.files);
  @override
  Future<List<PendingDocument>> pending() async => files;
  @override
  Future<void> markShown(String id) async => marked.add(id);
}

Future<void> _pumpListener(WidgetTester tester, _Inbox inbox) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(),
      child: DocumentInboxListener(
          navigatorKey: navigator,
          service: inbox,
          child: MaterialApp(
              navigatorKey: navigator, home: const SizedBox.shrink()))));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a share reviewed before a restart does not reopen',
      (tester) async {
    final inbox = _Inbox([const PendingDocument('a', 'old.pdf', shown: true)]);
    await _pumpListener(tester, inbox);
    expect(find.byType(DocumentImportScreen), findsNothing);
    expect(inbox.marked, isEmpty);
  });

  testWidgets('a new share opens once and is marked as shown',
      (tester) async {
    final inbox = _Inbox([const PendingDocument('b', 'new.pdf')]);
    await _pumpListener(tester, inbox);
    expect(inbox.marked, ['b']);
  });
}
