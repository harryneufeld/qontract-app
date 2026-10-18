import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../../l10n/strings.dart';
import '../../providers/document_provider.dart';
import '../../widgets/app_design.dart';

/// Pre-save preview from existing memory bytes. No download, upload or external app.
class ImportPreviewScreen extends StatefulWidget {
  final PickedDocument file;
  const ImportPreviewScreen({super.key, required this.file});
  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  PdfController? controller;
  int page = 1, pages = 0;
  late final Uint8List bytes = Uint8List.fromList(widget.file.bytes);
  bool get isPdf =>
      widget.file.name.toLowerCase().endsWith('.pdf') ||
      (bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-');
  @override
  void initState() {
    super.initState();
    if (isPdf) {
      controller = PdfController(document: PdfDocument.openData(bytes));
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Widget fallback() => AppPageScrollView(
          child: AppFormColumn(children: [
        const Icon(Icons.visibility_off_outlined, size: 40),
        Text(context.l10n.importPreviewFailed, textAlign: TextAlign.center),
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.importBackToReview)),
      ]));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.file.name,
                maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: isPdf
            ? PdfView(
                controller: controller!,
                onDocumentLoaded: (doc) {
                  if (mounted) setState(() => pages = doc.pagesCount);
                },
                onPageChanged: (value) {
                  if (mounted) setState(() => page = value);
                },
                builders: PdfViewBuilders<DefaultBuilderOptions>(
                  options: const DefaultBuilderOptions(),
                  documentLoaderBuilder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, error) => fallback(),
                ),
              )
            : LayoutBuilder(
                builder: (context, size) => InteractiveViewer(
                    minScale: 1,
                    child: SizedBox(
                        width: size.maxWidth,
                        height: size.maxHeight,
                        child: Image.memory(bytes,
                            fit: BoxFit.contain,
                            semanticLabel: widget.file.name,
                            errorBuilder: (_, error, stack) => fallback())))),
        bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (pages > 1)
                  Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                            tooltip: context.l10n.previousPage,
                            onPressed: page > 1
                                ? () => controller!.jumpToPage(page - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left)),
                        Text(context.l10n.pageOfTotal(page, pages)),
                        IconButton(
                            tooltip: context.l10n.nextPage,
                            onPressed: page < pages
                                ? () => controller!.jumpToPage(page + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right)),
                      ]),
                Text(context.l10n.importLocalPreviewHint,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
              ]),
            )),
      );
}
