import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contract.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';
import '../../providers/contract_provider.dart';
import '../../widgets/app_toast.dart';
import '../../services/api_service.dart';
import 'pdf_preview_screen.dart';
import 'image_preview_screen.dart';

/// Embedded documents area for a contract: list, upload (with title +
/// date dialog), metadata editing, download, and danger-zone delete (#5).
class DocumentsSection extends StatefulWidget {
  final Contract contract;

  const DocumentsSection({super.key, required this.contract});

  @override
  State<DocumentsSection> createState() => _DocumentsSectionState();
}

class _DocumentsSectionState extends State<DocumentsSection> {
  String _sort = 'dateDesc';
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
    if (provider.contractId == widget.contract.id &&
        !provider.isLoading &&
        provider.errorMessage == null) {
      final count = provider.documents.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<ContractProvider?>(context, listen: false)
              ?.updateDocumentCount(widget.contract, count);
        }
      });
    }
    final busy = provider.isBusy;
    final documents = List<Document>.of(provider.documents)
      ..sort((a, b) {
        int comparison;
        if (_sort == 'title') {
          comparison = a.displayName
              .toLowerCase()
              .compareTo(b.displayName.toLowerCase());
        } else if (a.documentDate == null || b.documentDate == null) {
          comparison = a.documentDate == b.documentDate
              ? 0
              : a.documentDate == null
                  ? 1
                  : -1;
        } else {
          comparison = _sort == 'dateAsc'
              ? a.documentDate!.compareTo(b.documentDate!)
              : b.documentDate!.compareTo(a.documentDate!);
        }
        return comparison != 0 ? comparison : a.id.compareTo(b.id);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
        const SizedBox(height: AppSpace.group),
        Row(
          children: [
            Expanded(
              child: Semantics(
                  header: true,
                  child: Text('Documents',
                      style: Theme.of(context).textTheme.titleLarge)),
            ),
            PopupMenuButton<String>(
                key: const Key('contractDocumentSort'),
                tooltip: 'Sort documents',
                initialValue: _sort,
                icon: const Icon(Icons.sort),
                onSelected: (value) => setState(() => _sort = value),
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'dateDesc',
                          child: Text('Document date: newest first')),
                      PopupMenuItem(
                          value: 'dateAsc',
                          child: Text('Document date: oldest first')),
                      PopupMenuItem(value: 'title', child: Text('Title A–Z')),
                    ]),
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          )
        else if (provider.documents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No documents yet. Use the upload button to attach files.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          AppCollection(
              children:
                  documents.map((doc) => _DocumentTile(doc: doc)).toList()),
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
    if (!mounted) return;
    final p = context.read<DocumentProvider>();
    final error = p.errorMessage;
    showToast(
      context,
      error ?? p.notice ?? 'Document uploaded.',
      style: error != null ? ToastStyle.error : ToastStyle.success,
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

String _formatDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _DocumentTile extends StatelessWidget {
  final Document doc;

  const _DocumentTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DocumentProvider>();
    final busy = provider.isBusy;

    return AppCollectionRow(
      child: ListTile(
        leading: Icon(
          doc.isPdf
              ? Icons.picture_as_pdf
              : doc.isImage
                  ? Icons.image_outlined
                  : Icons.insert_drive_file,
          color: doc.isPdf ? Colors.red : Colors.blueGrey,
        ),
        // Document title above; file name and business date beneath.
        title: Text(
          (doc.title ?? '').trim().isEmpty
              ? 'Untitled document'
              : doc.title!.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${doc.fileName} · '
          '${doc.documentDate == null ? 'Document date not set' : _formatDate(doc.documentDate!)} · '
          '${doc.fileSizeFormatted} · v${doc.version}'
          '${doc.createdBy != null ? ' · ${doc.createdBy}' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: (doc.isPdf || doc.isImage) && !busy
            ? () => _openPreview(context, doc)
            : null,
        trailing: PopupMenuButton<String>(
          tooltip: 'Document actions',
          enabled: !busy,
          itemBuilder: (_) => [
            if (doc.isPdf || doc.isImage)
              const PopupMenuItem(value: 'preview', child: Text('Preview')),
            const PopupMenuItem(value: 'download', child: Text('Download')),
            const PopupMenuItem(
                value: 'edit', child: Text('Edit title and date')),
            const PopupMenuItem(
                value: 'share', child: Text('Link to another contract')),
            if (provider.contractId != doc.contractId)
              const PopupMenuItem(
                  value: 'unlink', child: Text('Remove from this contract')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Move to trash on all contracts',
                    style: TextStyle(color: Colors.red))),
          ],
          onSelected: (value) {
            switch (value) {
              case 'preview':
                _openPreview(context, doc);
              case 'edit':
                _editMetadata(context, provider, doc);
              case 'download':
                _download(context, provider, doc);
              case 'share':
                _contractLink(context, provider, true);
              case 'unlink':
                _contractLink(context, provider, false);
              case 'delete':
                _confirmDelete(context, provider, doc);
            }
          },
        ),
      ),
    );
  }

  /// Opens a PDF or image in the appropriate in-app viewer.
  Future<void> _openPreview(BuildContext context, Document doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => doc.isImage && !doc.isPdf
            ? ImagePreviewScreen(doc: doc)
            : PdfPreviewScreen(doc: doc),
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
    if (!context.mounted) return;
    final error = provider.errorMessage;
    showToast(
      context,
      error ?? provider.notice ?? 'Document updated.',
      style: error != null ? ToastStyle.error : ToastStyle.success,
    );
  }

  /// Downloads [doc] and hands it to the system app, then toasts the
  /// outcome (app#28).
  Future<void> _download(
      BuildContext context, DocumentProvider provider, Document doc) async {
    final ok = await provider.downloadAndOpen(doc);
    if (!context.mounted) return;
    final error = provider.errorMessage;
    showToast(
      context,
      error ??
          (ok
              ? provider.notice ?? 'Downloaded.'
              : 'Could not open the document.'),
      style: error != null || !ok ? ToastStyle.error : ToastStyle.success,
    );
  }

  Future<void> _contractLink(
      BuildContext context, DocumentProvider provider, bool linked) async {
    int? targetId = provider.contractId;
    if (linked) {
      try {
        final contracts = (await provider.getLinkTargets(doc))
            .where((c) => !doc.contractIds.contains(c.id))
            .toList();
        if (!context.mounted) return;
        targetId = await showDialog<int>(
            context: context,
            builder: (c) => SimpleDialog(
                title: const Text('Link to contract'),
                children: contracts.isEmpty
                    ? [
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No other contracts available.'))
                      ]
                    : contracts
                        .map((contract) => SimpleDialogOption(
                            onPressed: () => Navigator.pop(c, contract.id),
                            child: Text(contract.title)))
                        .toList()));
      } on ApiException catch (e) {
        if (context.mounted) {
          showToast(context, e.message, style: ToastStyle.error);
        }
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Remove contract link?'),
                  content: const Text(
                      'The file and its other contract links are retained.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Remove link'))
                  ]));
      if (confirmed != true) return;
    }
    if (targetId == null || !context.mounted) return;
    await provider.setContractLink(doc, targetId, linked: linked);
    if (context.mounted) {
      showToast(
          context, provider.errorMessage ?? provider.notice ?? 'Link updated.',
          style: provider.errorMessage == null
              ? ToastStyle.success
              : ToastStyle.error);
    }
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
              'This moves the document to trash on every linked contract. '
              'It can be restored during the configured retention period. '
              'Files used as invoice evidence are protected.',
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
      if (!context.mounted) return;
      final error = provider.errorMessage;
      showToast(
        context,
        error ?? provider.notice ?? 'Document deleted.',
        style: error != null ? ToastStyle.error : ToastStyle.success,
      );
    }
  }
}
