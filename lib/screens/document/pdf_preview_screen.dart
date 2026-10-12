import '../../l10n/strings.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///
/// Multi-page documents show a page indicator; on wide (laptop/desktop)
/// layouts previous/next arrows are added, since a mouse cannot swipe the
/// page view. Arrow and Page Up/Down keys turn pages on every layout.
class PdfPreviewScreen extends StatefulWidget {
  final Document doc;

  const PdfPreviewScreen({super.key, required this.doc});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late DocumentProvider _provider;
  late PdfController _controller;
  int _pages = 0;

  /// Width from which page arrows are shown (matches the app's desktop
  /// detail layouts).
  static const double _arrowsBreakpoint = 900;

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

  void _turn(int delta) {
    final target = _controller.page + delta;
    if (_pages == 0 || target < 1 || target > _pages) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(target);
    } else {
      _controller.animateToPage(target,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

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
            tooltip: context.l10n.downloadOpenInApp,
            icon: const Icon(Icons.download),
            onPressed: _openInApp,
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _turn(-1),
          const SingleActivator(LogicalKeyboardKey.pageUp): () => _turn(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _turn(1),
          const SingleActivator(LogicalKeyboardKey.pageDown): () => _turn(1),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              PdfView(
                controller: _controller,
                onDocumentLoaded: (document) =>
                    setState(() => _pages = document.pagesCount),
                builders: PdfViewBuilders<DefaultBuilderOptions>(
                  options: const DefaultBuilderOptions(),
                  documentLoaderBuilder: (_) => const _CenteredLoader(),
                  errorBuilder: (context, error) =>
                      _PreviewFallback(onOpenInApp: _openInApp),
                ),
              ),
              if (_pages > 1)
                Positioned.fill(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _controller.pageListenable,
                    builder: (context, page, _) => _PageControls(
                      page: page,
                      pages: _pages,
                      arrows:
                          MediaQuery.sizeOf(context).width >= _arrowsBreakpoint,
                      onTurn: _turn,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page indicator and, on wide layouts, previous/next arrows over the page.
/// Empty areas let touches and scrolls through to the page view.
class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.page,
    required this.pages,
    required this.arrows,
    required this.onTurn,
  });

  final int page;
  final int pages;
  final bool arrows;
  final void Function(int delta) onTurn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget arrow(int delta) => IconButton.filledTonal(
          key: Key(delta < 0 ? 'pdfPreviousPage' : 'pdfNextPage'),
          tooltip:
              delta < 0 ? context.l10n.previousPage : context.l10n.nextPage,
          iconSize: 28,
          style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
          icon: Icon(delta < 0 ? Icons.chevron_left : Icons.chevron_right),
          onPressed: (delta < 0 ? page > 1 : page < pages)
              ? () => onTurn(delta)
              : null,
        );
    return Stack(
      children: [
        if (arrows) ...[
          Positioned(
              left: 16, top: 0, bottom: 0, child: Center(child: arrow(-1))),
          Positioned(
              right: 16, top: 0, bottom: 0, child: Center(child: arrow(1))),
        ],
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.inverseSurface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  context.l10n.pageOfTotal(page, pages),
                  key: const Key('pdfPageIndicator'),
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: scheme.onInverseSurface),
                ),
              ),
            ),
          ),
        ),
      ],
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
              context.l10n.previewIsNotAvailableForThisDocument,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.thisCanHappenIfTheFileCouldNot +
                  context.l10n.platformCannotRenderPDFsInApp,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(context.l10n.openInApp),
              onPressed: () => unawaited(onOpenInApp()),
            ),
          ],
        ),
      ),
    );
  }
}
