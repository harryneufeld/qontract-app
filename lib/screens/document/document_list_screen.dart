import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contract_provider.dart';
import '../../models/document.dart';

class DocumentListScreen extends StatefulWidget {
  final String contractId;

  const DocumentListScreen({super.key, required this.contractId});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: _handleUpload,
          ),
        ],
      ),
      body: Consumer<ContractProvider>(
        builder: (context, provider, child) {
          final contract = provider.contracts.firstWhere(
            (c) => c.id == widget.contractId,
            orElse: () => provider.contracts.first,
          );

          if (contract.documents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_drive_file, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No documents',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload documents to this contract',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contract.documents.length,
            itemBuilder: (context, index) {
              final document = contract.documents[index];
              return _buildDocumentItem(context, document);
            },
          );
        },
      ),
    );
  }

  Widget _buildDocumentItem(BuildContext context, Document document) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          _getDocumentIcon(document.type),
          color: Colors.blue,
        ),
        title: Text(document.filename),
        subtitle: Text(document.fileSizeFormatted),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () => _handleView(document),
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _handleDownload(document),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _handleDelete(document),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDocumentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _handleUpload() {
    // TODO: Implement file picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload functionality coming soon')),
    );
  }

  void _handleView(Document document) {
    // TODO: Implement document preview
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing: ${document.filename}')),
    );
  }

  void _handleDownload(Document document) {
    // TODO: Implement download
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading: ${document.filename}')),
    );
  }

  void _handleDelete(Document document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete ${document.filename}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted: ${document.filename}')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}