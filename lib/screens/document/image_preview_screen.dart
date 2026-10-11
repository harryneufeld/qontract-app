import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/document.dart';
import '../../providers/document_provider.dart';
import '../../widgets/app_toast.dart';

/// Displays authenticated document bytes without writing a temporary file.
class ImagePreviewScreen extends StatefulWidget {
  final Document doc;
  const ImagePreviewScreen({super.key, required this.doc});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late final DocumentProvider _provider;
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _provider = context.read<DocumentProvider>();
    _bytes = _load();
  }

  Future<Uint8List> _load() async =>
      Uint8List.fromList(await _provider.fetchDocumentBytes(widget.doc));

  Future<void> _openInApp() async {
    final opened = await _provider.downloadAndOpen(widget.doc);
    if (mounted && !opened) {
      showToast(context, _provider.errorMessage ?? 'Could not open file.',
          style: ToastStyle.error);
    }
  }

  Widget _fallback() => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.broken_image_outlined, size: 56),
            const SizedBox(height: 16),
            Text('Image preview unavailable.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
                'The image could not be loaded or its format is unsupported.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              OutlinedButton.icon(
                  onPressed: () => setState(() {
                        _bytes = _load();
                      }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry')),
              FilledButton.icon(
                  onPressed: _openInApp,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in app')),
            ]),
          ])));

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.doc.displayName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
                tooltip: 'Download & open in app',
                icon: const Icon(Icons.download),
                onPressed: _openInApp)
          ]),
      body: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) return _fallback();
            return LayoutBuilder(
                builder: (context, constraints) => InteractiveViewer(
                    minScale: 1,
                    maxScale: 8,
                    child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Image.memory(snapshot.data!,
                            key: const Key('documentImagePreview'),
                            fit: BoxFit.contain,
                            semanticLabel: widget.doc.displayName,
                            errorBuilder: (_, error, stack) => _fallback()))));
          }));
}
