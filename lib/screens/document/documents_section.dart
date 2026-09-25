import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contract.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';
import 'pdf_preview_screen.dart';

/// Embedded documents area for a contract: list, upload (with title +
/// date dialog), metadata editing, download, and danger-zone delete (#5).
class DocumentsSection extends StatefulWidget {
  final Contract contract;

  const DocumentsSection({super.key, required this.contract});

  @override
  State<DocumentsSection> createState() => _DocumentsSectionState();
}

class _DocumentsSectionState extends State<DocumentsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentProvider>().loadFor(widget.contract.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final busy = provider.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Documents',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (provider.contractId == widget.contract.id)
              IconButton(
                tooltip: 'Upload document',
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.file_upload_outlined),
                onPressed: busy ? null : _startUpload,
              ),
          ],
        ),
        if (provider.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          )
        else if (provider.documents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No documents yet. Use the upload button to attach files.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else
          ...provider.documents.map((doc) => _DocumentTile(doc: doc)),
        if (provider.notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              provider.notice!,
              style: TextStyle(color: Colors.green[700]),
            ),
          ),
      ],
    );
  }

  /// Pick a file, let the user choose a title + date, then upload (#5).
  Future<void> _startUpload() async {
    final provider = context.read<DocumentProvider>();
    final picked = await provider.pickFile();
    if (picked == null) return; // user cancelled the file picker
    if (!mounted) return;

    final meta = await _showMetadataDialog(
      context,
      editing: false,
      initialTitle: picked.name,
      initialDate: DateTime.now(),
    );
    if (meta == null) return; // user cancelled the metadata dialog

    await provider.uploadDocument(
      picked,
      title: meta.$1,
      documentDate: meta.$2,
    );
  }
}

/// The user's metadata choice from the dialog: (title, date).
typedef DocumentMetadataChoice = (String, DateTime);

/// Shared dialog for choosing a document title + date — used both when
/// uploading (defaults: file name, today) and when editing an existing
/// document (#5). Returns null when the user cancels.
Future<DocumentMetadataChoice?> _showMetadataDialog(
  BuildContext context, {
  required bool editing,
  required String initialTitle,
  required DateTime initialDate,
}) {
  return showDialog<DocumentMetadataChoice>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final titleController =
            TextEditingController(text: initialTitle.trim());
        var selectedDate = initialDate;

        Future<void> pickDate() async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: dialogContext,
            initialDate: selectedDate,
            firstDate: DateTime(now.year - 20),
            lastDate: now.add(const Duration(days: 365 * 5)),
            helpText: 'Document date',
          );
          if (picked != null) {
            setState(() => selectedDate = picked);
          }
        }

        return AlertDialog(
          title: Text(editing ? 'Edit document details' : 'New document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  helperText: 'Shown in the document list',
                  hintText: 'e.g. Lease agreement 2026',
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(
                  _formatDate(selectedDate),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop((titleController.text, selectedDate)),
              child: Text(editing ? 'Save' : 'Upload'),
            ),
          ],
        );
      },
    ),
  );
}

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _DocumentTile extends StatelessWidget {
  final Document doc;

  const _DocumentTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DocumentProvider>();
    final busy = provider.isBusy;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          doc.isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
          color: doc.isPdf ? Colors.red : Colors.blueGrey,
        ),
        // The user title (falling back to the file name) is the headline;
        // the raw file name + date + size move to the subtitle (#5).
        title: Text(
          doc.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${doc.fileName} · '
          '${_formatDate(doc.displayDate.toLocal())} · '
          '${doc.fileSizeFormatted} · v${doc.version}'
          '${doc.createdBy != null ? ' · ${doc.createdBy}' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // Tapping a PDF opens the in-app preview (app#27). Non-PDF files keep
        // the previous behaviour (no row tap; the download button handles them).
        onTap:
            doc.isPdf && !busy ? () => _openPreview(context, doc) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (doc.isPdf)
              IconButton(
                tooltip: 'Preview',
                icon: const Icon(Icons.visibility_outlined),
                onPressed:
                    busy ? null : () => _openPreview(context, doc),
              ),
            IconButton(
              tooltip: 'Edit title and date',
              icon: const Icon(Icons.edit_outlined),
              onPressed: busy ? null : () => _editMetadata(context, provider, doc),
            ),
            IconButton(
              tooltip: 'Download & open',
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              onPressed: busy ? null : () => provider.downloadAndOpen(doc),
            ),
            // Danger zone: red icon, red title, explicit warning (#5).
            IconButton(
              tooltip: 'Delete document',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: busy ? null : () => _confirmDelete(context, provider, doc),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the document in the in-app PDF preview (app#27).
  Future<void> _openPreview(BuildContext context, Document doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfPreviewScreen(doc: doc),
      ),
    );
  }

  Future<void> _editMetadata(
      BuildContext context, DocumentProvider provider, Document doc) async {
    final meta = await _showMetadataDialog(
      context,
      editing: true,
      initialTitle: doc.title?.trim() ?? doc.fileName,
      initialDate: doc.displayDate,
    );
    if (meta == null) return;
    await provider.updateMetadata(
      doc,
      title: meta.$1,
      documentDate: meta.$2,
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, DocumentProvider provider, Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            // Danger-zone styling: red, bold title (#5).
            Text(
              'Delete Document',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete "${doc.displayName}"?',
            ),
            const SizedBox(height: 8),
            const Text(
              'This cannot be undone. The document is moved to the '
              'deletion queue and permanently removed after the 90-day '
              'retention period.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteDocument(doc);
    }
  }
}
