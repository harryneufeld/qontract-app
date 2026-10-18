import '../../l10n/strings.dart';
import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import 'documents_section.dart';
import 'pdf_preview_screen.dart';
import 'image_preview_screen.dart';
import 'document_import_screen.dart';

class DocumentListScreen extends StatefulWidget {
  final Contract? contract;
  final ApiService? api;
  final Future<PickedDocument?> Function()? pickFile;
  final bool selectEvidence;
  const DocumentListScreen(
      {super.key,
      this.contract,
      this.api,
      this.pickFile,
      this.selectEvidence = false});
  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  late final ApiService api = widget.api ?? ApiService();
  String scope = 'Tenant';
  bool deleted = false, loading = false, busy = false, more = false;
  int page = 1, generation = 0;
  List<Document> documents = [];
  String? error;
  @override
  void initState() {
    super.initState();
    if (widget.contract == null) load();
  }

  Future<void> load({bool append = false}) async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final nextPage = append ? page + 1 : 1;
      final rows = await api.getLibraryDocuments(
          scope: scope, deleted: deleted, page: nextPage);
      if (!mounted || request != generation) return;
      setState(() {
        documents = append ? [...documents, ...rows] : rows;
        page = nextPage;
        more = rows.length == 50;
      });
    } on ApiException catch (e) {
      if (mounted && request == generation) setState(() => error = e.message);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> mutate(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) await load();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<PickedDocument?> pick() async => widget.pickFile != null
      ? await widget.pickFile!()
      : await context.read<DocumentProvider>().pickFile();
  Future<void> upload() async {
    await mutate(() async {
      final picked = await pick();
      if (picked == null || !mounted) return;
      final metadata = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => FileMetadataDialog(fileName: picked.name));
      if (metadata == null || !mounted) return;
      await api.uploadLibraryDocument(
          scope: scope,
          fileName: picked.name,
          fileType: DocumentProvider.guessMimeType(picked.name),
          fileData: picked.bytes,
          title: metadata['title'] as String?,
          description: metadata['description'] as String?,
          category: metadata['category'] as String?,
          documentDate: DateTime.parse(metadata['documentDate'] as String));
    });
  }

  Future<void> metadata(Document doc) async {
    final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) =>
            FileMetadataDialog(document: doc, fileName: doc.fileName));
    if (data != null && mounted) {
      await mutate(() async {
        await api.patchLibraryMetadata(doc.id, data);
      });
    }
  }

  Future<void> open(Document doc) async {
    if (doc.isPdf) {
      await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PdfPreviewScreen(doc: doc)));
    } else if (doc.isImage) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ImagePreviewScreen(doc: doc)));
    } else {
      final provider = context.read<DocumentProvider>();
      final ok = await provider.downloadAndOpen(doc);
      if (mounted && !ok) {
        showToast(
            context, provider.errorMessage ?? context.l10n.couldNotOpenFile,
            style: ToastStyle.error);
      }
    }
  }

  Future<void> remove(Document doc) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(context.l10n.moveFileToTrash),
                content: Text(doc.scope == 'Personal'
                    ? context.l10n.youCanRestoreThisPersonalFileDuringThe
                    : context.l10n.thisHidesTheFileOnAllLinkedContracts),
                actions: [
              if (!widget.selectEvidence)
                IconButton(
                    tooltip: context.l10n.importFindContract,
                    icon: const Icon(Icons.document_scanner_outlined),
                    onPressed: busy
                        ? null
                        : () async {
                            await Navigator.of(context).push(MaterialPageRoute<bool>(
                                builder: (_) => const DocumentImportScreen()));
                            if (mounted) load();
                          }),
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(context.l10n.cancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(context.l10n.moveToTrash))
                ]));
    if (confirmed == true && mounted) {
      await mutate(() => api.deleteDocument(doc.id));
    }
  }

  Future<void> link(Document doc, {bool remove = false}) async {
    await mutate(() async {
      final contracts = (await api.getContractList())
          .where((c) => remove
              ? doc.contractIds.contains(c.id) && c.id != doc.contractId
              : !doc.contractIds.contains(c.id))
          .toList();
      if (!mounted) return;
      final target = await showDialog<int>(
          context: context,
          builder: (c) => SimpleDialog(
              title: Text(remove
                  ? context.l10n.removeContractLink524
                  : context.l10n.linkToContract),
              children: contracts.isEmpty
                  ? [
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(context.l10n.noEligibleContracts))
                    ]
                  : contracts
                      .map((contract) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(c, contract.id),
                          child: Text(contract.title)))
                      .toList()));
      if (target != null && mounted) {
        await api.setDocumentContractLink(doc.id, target, linked: !remove);
      }
    });
  }

  Future<void> replace(Document doc) async {
    await mutate(() async {
      final picked = await pick();
      if (picked == null || !mounted) return;
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: Text(context.l10n.uploadANewVersion),
                  content: Text(context
                      .l10n.theEarlierVersionAndItsInvoiceEvidenceRemain),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(context.l10n.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(context.l10n.uploadVersion))
                  ]));
      if (confirmed == true && mounted) {
        await api.reuploadDocument(doc.id,
            fileName: picked.name,
            fileType: DocumentProvider.guessMimeType(picked.name),
            fileData: picked.bytes);
      }
    });
  }

  Future<void> versions(Document doc) async {
    await mutate(() async {
      final rows = await api.getDocumentVersions(doc.id);
      if (!mounted) return;
      final chosen = await showDialog<Document>(
          context: context,
          builder: (c) => SimpleDialog(
              title: Text(context.l10n.fileVersions),
              children: rows
                  .map((version) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(c, version),
                      child:
                          Text('v${version.version} · ${version.displayName}')))
                  .toList()));
      if (chosen != null && mounted) await open(chosen);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contract != null) {
      return Scaffold(
          appBar: AppBar(title: Text(widget.contract!.title)),
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DocumentsSection(contract: widget.contract!)));
    }
    return Scaffold(
        appBar: AppBar(
            title: Text(widget.selectEvidence
                ? context.l10n.chooseInvoiceEvidence
                : context.l10n.files),
            actions: [
              IconButton(
                  tooltip: context.l10n.refreshFiles,
                  onPressed: busy || loading ? null : load,
                  icon: const Icon(Icons.refresh)),
              if (!widget.selectEvidence)
                IconButton(
                    tooltip: deleted
                        ? context.l10n.showActiveFiles
                        : context.l10n.showTrash,
                    onPressed: busy || loading
                        ? null
                        : () {
                            setState(() {
                              deleted = !deleted;
                              documents = [];
                            });
                            load();
                          },
                    icon: Icon(
                        deleted ? Icons.folder_open : Icons.delete_outline))
            ]),
        floatingActionButton: deleted || widget.selectEvidence
            ? null
            : FloatingActionButton(
                tooltip: context.l10n.uploadFile,
                onPressed: busy || loading ? null : upload,
                child: const Icon(Icons.add)),
        body: RefreshIndicator(
            onRefresh: () => load(),
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  if (!widget.selectEvidence)
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: MediaQuery.textScalerOf(context).scale(14) > 19
                            ? RadioGroup<String>(
                                groupValue: scope,
                                onChanged: (value) {
                                  if (busy || value == null) return;
                                  setState(() {
                                    scope = value;
                                    documents = [];
                                  });
                                  load();
                                },
                                child: Column(children: [
                                  RadioListTile<String>(
                                      value: 'Tenant',
                                      enabled: !busy,
                                      title: Text(context.l10n.tenantFiles)),
                                  RadioListTile<String>(
                                      value: 'Personal',
                                      enabled: !busy,
                                      title: Text(context.l10n.myFiles)),
                                ]))
                            : SegmentedButton<String>(
                                segments: [
                                    ButtonSegment(
                                        value: 'Tenant',
                                        label: Text(context.l10n.tenantFiles)),
                                    ButtonSegment(
                                        value: 'Personal',
                                        label: Text(context.l10n.myFiles))
                                  ],
                                selected: {
                                    scope
                                  },
                                onSelectionChanged: busy
                                    ? null
                                    : (values) {
                                        setState(() {
                                          scope = values.single;
                                          documents = [];
                                        });
                                        load();
                                      })),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(scope == 'Personal'
                          ? context.l10n.onlyYouCanAccessTheseFilesTheyStay
                          : context
                              .l10n.sharedWithMembersOfTheCurrentTenantNo)),
                  if (deleted)
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(context.l10n.trash)),
                  if (busy || loading) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  if (documents.isEmpty && !loading && !busy && error == null)
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(context.l10n.noFilesYet)),
                  AppCollection(children: [
                    for (final doc in documents)
                      AppCollectionRow(
                          child: ListTile(
                              leading: Icon(doc.isPdf
                                  ? Icons.picture_as_pdf
                                  : doc.isImage
                                      ? Icons.image_outlined
                                      : Icons.insert_drive_file),
                              title: Text(doc.displayName),
                              subtitle: Text(
                                  '${doc.category == null ? '' : '${doc.category} · '}v${doc.version} · ${doc.fileSizeFormatted}'
                                  '${doc.description == null ? '' : '\n${doc.description}'}'
                                  '${doc.retainedForInvoice ? '\n${context.l10n.retainedForInvoiceEvidence}' : doc.expiresAt == null ? '' : '\n${context.l10n.removalAfter(S.date(doc.expiresAt!.toLocal()))}'}'),
                              onTap: deleted || busy
                                  ? null
                                  : widget.selectEvidence
                                      ? () => Navigator.pop(context, doc)
                                      : () => open(doc),
                              trailing: widget.selectEvidence
                                  ? const Icon(Icons.chevron_right)
                                  : PopupMenuButton<String>(
                                      tooltip: context.l10n.fileActions,
                                      enabled: !busy && !loading,
                                      itemBuilder: (_) => deleted
                                          ? [
                                              PopupMenuItem(
                                                  value: 'restore',
                                                  child: Text(
                                                      context.l10n.restore))
                                            ]
                                          : [
                                              PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text(context
                                                      .l10n.editFileDetails)),
                                              PopupMenuItem(
                                                  value: 'versions',
                                                  child: Text(
                                                      context.l10n.versions)),
                                              PopupMenuItem(
                                                  value: 'replace',
                                                  child: Text(context
                                                      .l10n.uploadNewVersion)),
                                              if (scope == 'Tenant')
                                                PopupMenuItem(
                                                    value: 'link',
                                                    child: Text(context
                                                        .l10n.linkToContract)),
                                              if (scope == 'Tenant' &&
                                                  doc.contractIds.any((id) =>
                                                      id != doc.contractId))
                                                PopupMenuItem(
                                                    value: 'unlink',
                                                    child: Text(context.l10n
                                                        .removeContractLink524)),
                                              PopupMenuItem(
                                                  value: 'trash',
                                                  child: Text(
                                                      context.l10n.moveToTrash))
                                            ],
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'edit':
                                            metadata(doc);
                                          case 'versions':
                                            versions(doc);
                                          case 'replace':
                                            replace(doc);
                                          case 'link':
                                            link(doc);
                                          case 'unlink':
                                            link(doc, remove: true);
                                          case 'trash':
                                            remove(doc);
                                          case 'restore':
                                            mutate(() async {
                                              await api.restoreDocument(doc.id);
                                            });
                                        }
                                      })))
                  ]),
                  if (more)
                    TextButton(
                        onPressed:
                            loading || busy ? null : () => load(append: true),
                        child: Text(context.l10n.loadMoreFiles)),
                  const SizedBox(height: 80),
                ])));
  }
}

class FileMetadataDialog extends StatefulWidget {
  final Document? document;
  final String fileName;
  const FileMetadataDialog({super.key, this.document, required this.fileName});
  @override
  State<FileMetadataDialog> createState() => _FileMetadataDialogState();
}

class _FileMetadataDialogState extends State<FileMetadataDialog> {
  final form = GlobalKey<FormState>();
  late final title =
      TextEditingController(text: widget.document?.title ?? widget.fileName);
  late final description =
      TextEditingController(text: widget.document?.description ?? '');
  late final category =
      TextEditingController(text: widget.document?.category ?? '');
  late DateTime date = widget.document?.displayDate ?? DateTime.now();
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(context.l10n.fileDetails),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextFormField(
                            controller: title,
                            maxLength: 255,
                            decoration:
                                InputDecoration(labelText: context.l10n.title)),
                        TextFormField(
                            controller: category,
                            maxLength: 100,
                            decoration: InputDecoration(
                                labelText: context.l10n.categoryOptional)),
                        TextFormField(
                            controller: description,
                            maxLength: 2000,
                            maxLines: 3,
                            decoration: InputDecoration(
                                labelText: context.l10n.descriptionOptional)),
                        TextButton.icon(
                            icon: const Icon(Icons.calendar_month),
                            label: Text(S.date(date)),
                            onPressed: () async {
                              final chosen = await showDatePicker(
                                  context: context,
                                  initialDate: date,
                                  firstDate: DateTime(1),
                                  lastDate: DateTime(9999));
                              if (chosen != null && mounted) {
                                setState(() => date = chosen);
                              }
                            }),
                      ])))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel)),
            FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(context, <String, dynamic>{
                      'title': title.text,
                      'category': category.text,
                      'description': description.text,
                      'documentDate':
                          '${date.toIso8601String().split('T').first}T00:00:00Z'
                    });
                  }
                },
                child: Text(context.l10n.save))
          ]);
}
