import 'package:flutter/material.dart';

import '../../models/contract.dart';

/// Documents are stored server-side via the Documents API (a later phase of
/// #1). This screen shows the per-contract document area; upload/download/
/// preview land with the document integration milestone.
class DocumentListScreen extends StatelessWidget {
  final Contract? contract;

  const DocumentListScreen({super.key, this.contract});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          contract == null ? 'Documents' : contract!.title,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insert_drive_file,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No documents yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Document upload and download for this contract are coming '
                'soon.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
