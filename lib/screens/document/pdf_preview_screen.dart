import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

import '../../models/document.dart';
import '../../providers/document_provider.dart';

/// Full-screen, in-app PDF preview (app#27).
///
/// The document bytes are downloaded on demand and rendered with [pdfx],
/// which works cross-platform (mobile, desktop and web). When an in-app
/// preview is not possible — the platform has no PDF renderer (e.g. Linux
/// desktop), the download fails, or the file is not a valid PDF — the view
/// falls back to opening the file with a system app via
/// [DocumentProvider.downloadAndOpen], preserving the previous behaviour.
class PdfPreviewScreen extends StatefulWidget {
  final Document doc;

  const PdfPreviewScreen({super.key, required this.doc});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late DocumentProvider _provider;
  late PdfController _controller;

  @override
  void initState() {
    super.initState();
    _provider = context.read<DocumentProvider>();
    _controller = PdfController(document: _openDocument());
  }

  /// Downloads the bytes and opens them as a [PdfDocument]. Any failure
  /// (network error, unsupported platform, corrupt file) rejects this future,
  /// which [PdfView] surfaces through its error builder.
  Future<PdfDocument> _openDocument() async {
    final bytes = await _provider.fetchDocumentBytes(widget.doc);
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    return PdfDocument.openData(data);
  }

  /// Fallback when an in-app preview is not possible: hand the file to the
  /// system app (the pre-app#27 behaviour).
  Future<void> _openInApp() => _provider.downloadAndOpen(widget.doc);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.doc.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Download & open in app',
            icon: const Icon(Icons.download),
            onPressed: _openInApp,
          ),
        ],
      ),
      body: PdfView(
        controller: _controller,
        builders: PdfViewBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const _CenteredLoader(),
          errorBuilder: (context, error) =>
              _PreviewFallback(onOpenInApp: _openInApp),
        ),
      ),
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Shown when the in-app preview could not be loaded: explains why and offers
/// the "open in app" fallback.
class _PreviewFallback extends StatelessWidget {
  final Future<void> Function() onOpenInApp;

  const _PreviewFallback({required this.onOpenInApp});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Preview is not available for this document.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This can happen if the file could not be downloaded or the '
              'platform cannot render PDFs in-app.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in app'),
              onPressed: () => unawaited(onOpenInApp()),
            ),
          ],
        ),
      ),
    );
  }
}
