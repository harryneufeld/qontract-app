import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/contract.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';

/// Embedded documents area for a contract: list, upload, download, delete.
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
                onPressed:
                    busy ? null : () => provider.pickAndUpload(),
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
}

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
        title: Text(
          doc.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${doc.fileSizeFormatted} · '
          '${doc.uploadedAt.toLocal().toString().split(' ').first} · '
          'v${doc.version}'
          '${doc.createdBy != null ? ' · ${doc.createdBy}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: busy ? null : () => _confirmDelete(context, provider, doc),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, DocumentProvider provider, Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text(
          'Delete "${doc.fileName}"? This action cannot be undone.',
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
