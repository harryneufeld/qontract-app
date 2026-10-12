import '../../l10n/strings.dart';
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
                  child: Text(context.l10n.documents,
                      style: Theme.of(context).textTheme.titleLarge)),
            ),
            if (provider.contractId == widget.contract.id)
              IconButton(
                tooltip: context.l10n.uploadDocument,
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
              context.l10n.noDocumentsYetUseTheUploadButtonTo,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          )
        else
          ...provider.documents.map((doc) => _DocumentTile(doc: doc)),
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
      error ?? p.notice ?? context.l10n.documentUploaded,
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
            helpText: context.l10n.documentDate,
          );
          if (picked != null) {
            setState(() => selectedDate = picked);
          }
        }

        return AlertDialog(
          title: Text(editing
              ? context.l10n.editDocumentDetails
              : context.l10n.newDocument),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: context.l10n.title,
                  helperText: context.l10n.shownInTheDocumentList,
                  hintText: context.l10n.eGLeaseAgreement2026,
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
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop((titleController.text, selectedDate)),
              child: Text(editing ? context.l10n.save : context.l10n.upload),
            ),
          ],
        );
      },
    ),
  );
}

String _formatDate(DateTime d) => S.date(d);

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
        onTap: (doc.isPdf || doc.isImage) && !busy
            ? () => _openPreview(context, doc)
            : null,
        trailing: PopupMenuButton<String>(
          tooltip: context.l10n.documentActions,
          enabled: !busy,
          itemBuilder: (_) => [
            if (doc.isPdf || doc.isImage)
              PopupMenuItem(
                  value: 'preview', child: Text(context.l10n.preview)),
            PopupMenuItem(
                value: 'download', child: Text(context.l10n.download)),
            PopupMenuItem(
                value: 'edit', child: Text(context.l10n.editTitleAndDate)),
            PopupMenuItem(
                value: 'share',
                child: Text(context.l10n.linkToAnotherContract)),
            if (provider.contractId != doc.contractId)
              PopupMenuItem(
                  value: 'unlink',
                  child: Text(context.l10n.removeFromThisContract)),
            PopupMenuItem(
                value: 'delete',
                child: Text(context.l10n.moveToTrashOnAllContracts,
                    style: const TextStyle(color: Colors.red))),
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
      error ?? provider.notice ?? context.l10n.documentUpdated,
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
              ? provider.notice ?? context.l10n.downloaded503
              : context.l10n.couldNotOpenTheDocument),
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
                title: Text(context.l10n.linkToContract),
                children: contracts.isEmpty
                    ? [
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(context.l10n.noOtherContractsAvailable))
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
                  title: Text(context.l10n.removeContractLink),
                  content:
                      Text(context.l10n.theFileAndItsOtherContractLinksAre),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(context.l10n.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(context.l10n.removeLink))
                  ]));
      if (confirmed != true) return;
    }
    if (targetId == null || !context.mounted) return;
    await provider.setContractLink(doc, targetId, linked: linked);
    if (context.mounted) {
      showToast(context,
          provider.errorMessage ?? provider.notice ?? context.l10n.linkUpdated,
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
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            // Danger-zone styling: red, bold title (#5).
            Text(
              context.l10n.deleteDocument,
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.delete512((doc.displayName)),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.thisMovesTheDocumentToTrashOnEvery +
                  context.l10n.itCanBeRestoredDuringTheConfiguredRetention +
                  context.l10n.filesUsedAsInvoiceEvidenceAreProtected,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.delete),
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
        error ?? provider.notice ?? context.l10n.documentDeleted,
        style: error != null ? ToastStyle.error : ToastStyle.success,
      );
    }
  }
}
