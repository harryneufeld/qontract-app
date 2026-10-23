import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/document/document_import_screen.dart';
import '../services/document_import_service.dart';

/// Runs above navigation so a warm share works from every screen. The native
/// queue survives login and restarts; cancelling review leaves the file there,
/// listed on Import document, without opening it again automatically.
class DocumentInboxListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final DocumentImportService? service;
  const DocumentInboxListener(
      {super.key,
      required this.child,
      required this.navigatorKey,
      this.service});
  @override
  State<DocumentInboxListener> createState() => _DocumentInboxListenerState();
}

class _DocumentInboxListenerState extends State<DocumentInboxListener>
    with WidgetsBindingObserver {
  late final service = widget.service ?? DocumentImportService();
  final shown = <String>{};
  bool checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DocumentImportService.addInboxListener(inboxChanged);
  }

  void inboxChanged() => check();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.watch<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  Future<void> check() async {
    if (!mounted || checking || !context.read<AuthProvider>().isAuthenticated) {
      return;
    }
    checking = true;
    try {
      final files = await service.pending();
      if (!mounted || !context.read<AuthProvider>().isAuthenticated) return;
      final next = files
          .where((file) => !file.shown && !shown.contains(file.id))
          .firstOrNull;
      final navigator = widget.navigatorKey.currentState;
      if (next == null || navigator == null) return;
      shown.add(next.id);
      await service.markShown(next.id);
      await navigator.push(MaterialPageRoute<bool>(
          builder: (_) => DocumentImportScreen(incomingId: next.id)));
    } catch (_) {
      // A native inbox failure must not prevent login or normal navigation.
      // The Import document screen exposes errors and provides manual import.
      return;
    } finally {
      checking = false;
    }
    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DocumentImportService.removeInboxListener(inboxChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
