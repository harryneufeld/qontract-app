import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/document.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_selection_sheet.dart';

/// Every stored detail of a file, with long values wrapped and selectable.
Future<void> showDocumentDetails(BuildContext context, Document doc) {
  final l10n = context.l10n;
  final rows = <(String, String)>[
    (l10n.fdFileName, doc.fileName),
    if ((doc.title ?? '').trim().isNotEmpty) (l10n.title, doc.title!.trim()),
    (l10n.fdFileType, doc.fileType.isEmpty ? '-' : doc.fileType),
    (
      l10n.fdFileSize,
      '${doc.fileSizeFormatted} (${l10n.fdBytes(doc.fileSize)})'
    ),
    (
      l10n.documentDate,
      doc.documentDate == null
          ? l10n.documentDateNotSet
          : S.date(doc.documentDate!)
    ),
    (l10n.fdUploaded, S.date(doc.uploadedAt.toLocal())),
    if (doc.createdBy != null) (l10n.fdUploadedBy, doc.createdBy!),
    if (doc.modifiedBy != null) (l10n.fdModifiedBy, doc.modifiedBy!),
    (l10n.fdVersion, 'v${doc.version}'),
    (l10n.fdVisibility, doc.scope == 'Personal' ? l10n.personal : l10n.workspace),
    if (doc.category != null) (l10n.fdCategory, doc.category!),
    if ((doc.description ?? '').trim().isNotEmpty)
      (l10n.description, doc.description!.trim()),
    if (doc.contractIds.isNotEmpty)
      (l10n.fdLinkedContracts, '${doc.contractIds.length}'),
    if (doc.retainedForInvoice)
      (l10n.retainedForInvoiceEvidence, '')
    else if (doc.expiresAt != null)
      (l10n.removalAfter(S.date(doc.expiresAt!.toLocal())), ''),
  ];
  return showAppSelection<void>(
      context: context,
      title: l10n.fileDetails,
      builder: (context) {
        final theme = Theme.of(context);
        return SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              for (final (label, value) in rows)
                Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.group),
                    child: value.isEmpty
                        ? Text(label)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(label,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant)),
                                SelectableText(value,
                                    style: theme.textTheme.bodyLarge),
                              ])),
            ]));
      });
}
