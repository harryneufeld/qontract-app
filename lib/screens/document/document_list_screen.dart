import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import 'documents_section.dart';
import 'pdf_preview_screen.dart';

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
    } else {
      final provider = context.read<DocumentProvider>();
      final ok = await provider.downloadAndOpen(doc);
      if (mounted && !ok) {
        showToast(context, provider.errorMessage ?? 'Could not open file.',
            style: ToastStyle.error);
      }
    }
  }

  Future<void> remove(Document doc) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Move file to trash?'),
                content: Text(doc.scope == 'Personal'
                    ? 'You can restore this personal file during the retention period.'
                    : 'This hides the file on all linked contracts. You can restore it during the tenant retention period. Invoice evidence is protected.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Move to trash'))
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
              title: Text(remove ? 'Remove contract link' : 'Link to contract'),
              children: contracts.isEmpty
                  ? [
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No eligible contracts.'))
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
                  title: const Text('Upload a new version?'),
                  content: const Text(
                      'The earlier version and its invoice evidence remain unchanged.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Upload version'))
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
              title: const Text('File versions'),
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
            title: Text(
                widget.selectEvidence ? 'Choose invoice evidence' : 'Files'),
            actions: [
              IconButton(
                  tooltip: 'Refresh files',
                  onPressed: busy || loading ? null : load,
                  icon: const Icon(Icons.refresh)),
              if (!widget.selectEvidence)
                IconButton(
                    tooltip: deleted ? 'Show active files' : 'Show trash',
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
                tooltip: 'Upload file',
                onPressed: busy || loading ? null : upload,
                child: const Icon(Icons.upload_file)),
        body: Column(children: [
          if (!widget.selectEvidence)
            Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'Tenant', label: Text('Tenant files')),
                      ButtonSegment(value: 'Personal', label: Text('My files'))
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
                  ? 'Only you can access these files. They stay with your account when switching tenants.'
                  : 'Shared with members of the current tenant. No contract is required.')),
          if (deleted)
            const Padding(padding: EdgeInsets.all(8), child: Text('Trash')),
          if (busy || loading) const LinearProgressIndicator(),
          if (error != null)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          Expanded(
              child: RefreshIndicator(
                  onRefresh: () => load(),
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (documents.isEmpty &&
                            !loading &&
                            !busy &&
                            error == null)
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No files yet.')),
                        for (final doc in documents)
                          Card(
                              child: ListTile(
                                  leading: Icon(doc.isPdf
                                      ? Icons.picture_as_pdf
                                      : Icons.insert_drive_file),
                                  title: Text(doc.displayName),
                                  subtitle: Text(
                                      '${doc.category == null ? '' : '${doc.category} · '}v${doc.version} · ${doc.fileSizeFormatted}'
                                      '${doc.description == null ? '' : '\n${doc.description}'}'
                                      '${doc.retainedForInvoice ? '\nRetained for invoice evidence' : doc.expiresAt == null ? '' : '\nRemoval after ${doc.expiresAt!.toIso8601String().split('T').first}'}'),
                                  onTap: deleted || busy
                                      ? null
                                      : widget.selectEvidence
                                          ? () => Navigator.pop(context, doc)
                                          : () => open(doc),
                                  trailing: widget.selectEvidence
                                      ? const Icon(Icons.chevron_right)
                                      : PopupMenuButton<String>(
                                          tooltip: 'File actions',
                                          enabled: !busy && !loading,
                                          itemBuilder: (_) => deleted
                                              ? [
                                                  const PopupMenuItem(
                                                      value: 'restore',
                                                      child: Text('Restore'))
                                                ]
                                              : [
                                                  const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text(
                                                          'Edit file details')),
                                                  const PopupMenuItem(
                                                      value: 'versions',
                                                      child: Text('Versions')),
                                                  const PopupMenuItem(
                                                      value: 'replace',
                                                      child: Text(
                                                          'Upload new version')),
                                                  if (scope == 'Tenant')
                                                    const PopupMenuItem(
                                                        value: 'link',
                                                        child: Text(
                                                            'Link to contract')),
                                                  if (scope == 'Tenant' &&
                                                      doc.contractIds.any(
                                                          (id) =>
                                                              id !=
                                                              doc.contractId))
                                                    const PopupMenuItem(
                                                        value: 'unlink',
                                                        child: Text(
                                                            'Remove contract link')),
                                                  const PopupMenuItem(
                                                      value: 'trash',
                                                      child:
                                                          Text('Move to trash'))
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
                                                  await api
                                                      .restoreDocument(doc.id);
                                                });
                                            }
                                          }))),
                        if (more)
                          TextButton(
                              onPressed: loading || busy
                                  ? null
                                  : () => load(append: true),
                              child: const Text('Load more files')),
                        const SizedBox(height: 80),
                      ]))),
        ]));
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
          title: const Text('File details'),
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
                                const InputDecoration(labelText: 'Title')),
                        TextFormField(
                            controller: category,
                            maxLength: 100,
                            decoration: const InputDecoration(
                                labelText: 'Category (optional)')),
                        TextFormField(
                            controller: description,
                            maxLength: 2000,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Description (optional)')),
                        TextButton.icon(
                            icon: const Icon(Icons.calendar_month),
                            label:
                                Text(date.toIso8601String().split('T').first),
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
                child: const Text('Cancel')),
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
                child: const Text('Save'))
          ]);
}
