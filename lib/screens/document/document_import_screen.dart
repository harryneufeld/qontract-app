import '../../l10n/strings.dart';
import 'import_preview_screen.dart';
import '../../app_routes.dart';
import '../../providers/contract_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/contract.dart';
import '../../models/contractor.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../services/api_service.dart';
import '../../services/document_contract_matcher.dart';
import '../../services/document_import_service.dart';
import '../../services/document_metadata_extractor.dart';
import '../../utils/localized_input.dart';
import '../../widgets/date_picker_form_field.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_selection_sheet.dart';

class DocumentImportScreen extends StatefulWidget {
  final String? incomingId;
  final ApiService? api;
  final DocumentImportService? service;
  final Future<PickedDocument?> Function()? pickFile;
  const DocumentImportScreen({
    super.key,
    this.incomingId,
    this.api,
    this.service,
    this.pickFile,
  });

  @override
  State<DocumentImportScreen> createState() => _DocumentImportScreenState();
}

class _DocumentImportScreenState extends State<DocumentImportScreen> {
  late final api = widget.api ?? ApiService();
  late final service = widget.service ?? DocumentImportService();
  final title = TextEditingController();
  final documentDate = TextEditingController();
  final contractNumber = TextEditingController();
  final dateReview = ExpansibleController();
  bool numberEdited = false, destinationChosen = false;
  List<Contractor> knownContractors = [];
  final metadataForm = GlobalKey<FormState>();
  final scroll = ScrollController();
  DocumentMetadataSuggestion metadata = const DocumentMetadataSuggestion();
  Map<int, String> contractorNames = {};
  List<PendingDocument> inbox = [];
  PickedDocument? file;
  String? incomingId;
  List<Contract> contracts = [];
  List<ContractMatch> matches = [];
  Contract? target;
  String text = '', scope = 'Personal';
  String? warning, error;
  bool busy = false, saving = false, contractsLoaded = false, saved = false;

  @override
  void initState() {
    super.initState();
    if (widget.incomingId != null) {
      openShared(widget.incomingId!);
    } else {
      refreshInbox();
    }
  }

  @override
  void dispose() {
    title.dispose();
    documentDate.dispose();
    contractNumber.dispose();
    dateReview.dispose();
    scroll.dispose();
    super.dispose();
  }

  String message(Object e) => e is ApiException
      ? e.message
      : e is PlatformException
          ? (e.message ?? S.current.importReadFailed)
          : e is StateError
              ? e.message.toString()
              : S.current.importProcessFailed;

  Future<void> refreshInbox() async {
    try {
      final rows = await service.pending();
      if (mounted) setState(() => inbox = rows);
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    }
  }

  Future<void> openShared(String id) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final picked = await service.read(id);
      if (!mounted) return;
      incomingId = id;
      await analyze(picked);
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      PickedDocument? picked;
      if (widget.pickFile != null) {
        picked = await widget.pickFile!();
      } else {
        final files = await FilePicker.pickFiles(
          dialogTitle: S.current.importPickerTitle,
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
            'jpg',
            'jpeg',
            'png',
            'webp',
            'heic',
            'heif',
            'bmp',
            'tif',
            'tiff',
          ],
        );
        final selected = files.singleOrNull;
        if (selected != null) {
          if ((await selected.length() ?? 0) > DocumentImportService.maxBytes) {
            throw StateError(S.current.importSizeLimit);
          }
          picked = PickedDocument(
            name: selected.name,
            bytes: await selected.readAsBytes(),
          );
        }
      }
      if (picked == null || !mounted) return;
      incomingId = null;
      await analyze(picked);
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> analyze(PickedDocument picked) async {
    if (picked.bytes.isEmpty ||
        picked.bytes.length > DocumentImportService.maxBytes) {
      throw StateError(S.current.importSizeLimit);
    }
    setState(() {
      file = picked;
      title.text = picked.name;
      documentDate.clear();
      contractNumber.clear();
      numberEdited = false;
      destinationChosen = false;
      metadata = const DocumentMetadataSuggestion();
      target = null;
      text = '';
      matches = [];
      warning = null;
      error = null;
      contractsLoaded = false;
    });
    // A recognition failure must still allow a manual destination and upload.
    try {
      final result = await service.recognize(picked);
      if (!mounted) return;
      text = result.text;
      metadata =
          DocumentMetadataExtractor.extract(text, positions: result.lines);
      contractNumber.text = metadata.contractNumber ?? '';
      if (metadata.subject != null) title.text = metadata.subject!;
      if (metadata.date != null) documentDate.text = isoDate(metadata.date!);
      warning = result.warning;
      if (text.trim().isEmpty) {
        warning ??= S.current.importNoText;
      }
    } catch (e) {
      if (!mounted) return;
      warning = '${message(e)} ${S.current.importManualFallback}';
    }
    await loadContracts();
  }

  Future<void> loadContracts() async {
    try {
      final rows = await api.getContractList();
      if (!mounted) return;
      contracts = rows;
      contractsLoaded = true;
      List<Contractor> contractors = [];
      try {
        contractors = await api.getContractors();
      } catch (_) {
        // Contract numbers and titles still work if contractor lookup fails.
      }
      if (!mounted) return;
      knownContractors = contractors;
      contractorNames = {
        for (final contractor in contractors) contractor.id: contractor.name
      };
      final candidates = {
        for (final n in metadata.numbers)
          DocumentMetadataExtractor.normalizeNumber(n.number): n
      };
      for (final n in DocumentContractMatcher.knownNumberEvidence(text, rows)) {
        candidates.putIfAbsent(
            DocumentMetadataExtractor.normalizeNumber(n.number), () => n);
      }
      metadata = DocumentMetadataSuggestion(
          subject: metadata.subject,
          subjectPassage: metadata.subjectPassage,
          date: metadata.date,
          dates: metadata.dates,
          numbers: candidates.values.toList());
      if (!numberEdited) contractNumber.text = metadata.contractNumber ?? '';
      matches = DocumentContractMatcher.rank(
        text,
        rows,
        contractors: contractors,
        reviewedNumber: numberEdited ? contractNumber.text : null,
      );
      if (!destinationChosen) {
        target = DocumentContractMatcher.bestDefault(matches)?.contract;
      }
    } catch (e) {
      if (!mounted) return;
      error = '${S.current.importLoadContractsFailed} ${message(e)}';
    }
    if (mounted) setState(() {});
  }

  void updateNumber(String value) {
    setState(() {
      if (contractNumber.text != value) contractNumber.text = value;
      numberEdited = true;
      destinationChosen = false;
      matches = DocumentContractMatcher.rank(text, contracts,
          contractors: knownContractors, reviewedNumber: value);
      target = DocumentContractMatcher.bestDefault(matches)?.contract;
    });
  }

  Future<void> chooseContract() async {
    var query = '';
    final chosen = await showAppSelection<Contract>(
      context: context,
      title: context.l10n.importChooseContract,
      builder: (context) => StatefulBuilder(builder: (context, update) {
        final rows = contracts
            .where((c) =>
                '${c.title} ${c.contractNumber ?? ''} ${contractorNames[c.contractorId] ?? ''}'
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
        return SizedBox(
            height: 420,
            child: Column(children: [
              TextField(
                  decoration: InputDecoration(
                      labelText: context.l10n.importSearchContracts,
                      prefixIcon: const Icon(Icons.search)),
                  onChanged: (value) => update(() => query = value)),
              const SizedBox(height: AppSpace.group),
              Expanded(
                  child: ListView(children: [
                if (rows.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.l10n.importNoContracts)),
                AppCollection(compact: true, children: [
                  for (final contract in rows)
                    ListTile(
                      title: Text(contract.title),
                      subtitle: Text(
                          '${contract.contractNumber ?? context.l10n.importNoNumber}\n${contractorNames[contract.contractorId] ?? context.l10n.importContractorUnknown}'),
                      trailing: target?.id == contract.id
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, contract),
                    )
                ]),
              ])),
            ]));
      }),
    );
    if (chosen != null && mounted) {
      setState(() {
        target = chosen;
        destinationChosen = true;
      });
    }
  }

  Future<void> save() async {
    if (file == null || busy || saved) return;
    // Validate the retained date value before submitting either destination.
    if (documentDate.text.trim().isNotEmpty &&
        parseDateInput(documentDate.text) == null) {
      dateReview.expand();
      metadataForm.currentState?.validate();
      setState(() => error = context.l10n.importInvalidDate);
      await revealError();
      return;
    }
    setState(() {
      busy = true;
      saving = true;
      error = null;
    });
    try {
      final picked = file!;
      final destination = target;
      if (destination != null) {
        await api.uploadDocument(
          destination.id,
          fileName: picked.name,
          fileType: DocumentProvider.guessMimeType(picked.name),
          fileData: picked.bytes,
          title: title.text,
          documentDate: parseDateInput(documentDate.text),
        );
      } else {
        await api.uploadLibraryDocument(
          scope: scope,
          fileName: picked.name,
          fileType: DocumentProvider.guessMimeType(picked.name),
          fileData: picked.bytes,
          title: title.text,
          documentDate: parseDateInput(documentDate.text),
        );
      }
      // Never offer another upload if removing the local inbox copy fails.
      saved = true;
      if (incomingId != null) {
        try {
          await service.discard(incomingId!);
        } catch (_) {
          if (mounted) {
            setState(() => warning = context.l10n.importCleanupFailed);
          }
        }
      }
      if (!mounted) return;
      if (destination != null) {
        // Refresh before opening so the new attachment is visible even when the
        // same contract's documents were previously cached.
        try {
          await context
              .read<DocumentProvider?>()
              ?.loadFor(destination.id, force: true);
        } catch (_) {}
        if (!mounted) return;
        try {
          await context
              .read<ContractProvider?>()
              ?.refreshContract(destination.id);
        } catch (_) {}
        if (!mounted) return;
        if (warning == context.l10n.importCleanupFailed) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(warning!)));
        }
        Navigator.pushReplacementNamed(context, AppRoutes.contractDetail,
            arguments: destination, result: true);
      } else if (warning != context.l10n.importCleanupFailed) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = message(e));
        await revealError();
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          saving = false;
        });
      }
    }
  }

  Future<void> revealError() async {
    if (scroll.hasClients) {
      await scroll.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  Widget contractChoice(Contract contract, {ContractMatch? match}) {
    final selected = target?.id == contract.id;
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListTile(
        selected: selected,
        selectedTileColor: colors.primaryContainer,
        leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off),
        title: Text(contract.title),
        subtitle: Text(
            '${contract.contractNumber ?? context.l10n.importNoNumber} · ${contractorNames[contract.contractorId] ?? context.l10n.importContractorUnknown}${match == null ? '' : '\n${context.l10n.importMatchPoints(match.score)}'}'),
        onTap: busy || saved
            ? null
            : () => setState(() {
                  target = contract;
                  destinationChosen = true;
                }),
      ),
      if (match != null && match.passages.isNotEmpty)
        ExpansionTile(
          key: ValueKey('match-${contract.id}'),
          title: Text(context.l10n.importMatchingPassages,
              style: Theme.of(context).textTheme.labelLarge),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final passage in match.passages)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText('“$passage”'))
          ],
        ),
    ]);
  }

  Widget parameterReview() {
    final enabled = !busy && !saved;
    final date = parseDateInput(documentDate.text);
    return AppCollection(compact: true, children: [
      ExpansionTile(
        controller: dateReview,
        key: const ValueKey('date-review'),
        leading: const Icon(Icons.event_outlined),
        title: Text(context.l10n.importReviewDate),
        subtitle: Text(
            date != null ? S.date(date) : context.l10n.importNoDateDetected),
        childrenPadding: const EdgeInsets.all(AppSpace.group),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
              key: metadataForm,
              child: DatePickerFormField(
                  controller: documentDate,
                  enabled: enabled,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  labelText: context.l10n.documentDate,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100, 12, 31),
                  onDateSelected: (_) => setState(() {}),
                  validator: (value) => documentDate.text.trim().isEmpty ||
                          parseDateInput(documentDate.text) != null
                      ? null
                      : context.l10n.importInvalidDate)),
          if (metadata.date == null && metadata.dates.isNotEmpty)
            Text(context.l10n.importChooseDate),
          for (final candidate in metadata.dates.take(8))
            ListTile(
                title: Text(S.date(candidate.date)),
                subtitle: Text(
                    '${candidate.passage}\n${context.l10n.importMatchPoints(candidate.priority)}'),
                trailing:
                    date != null && isoDate(date) == isoDate(candidate.date)
                        ? const Icon(Icons.check)
                        : null,
                onTap: enabled
                    ? () => setState(
                        () => documentDate.text = isoDate(candidate.date))
                    : null),
        ],
      ),
      ExpansionTile(
        key: const ValueKey('number-review'),
        leading: const Icon(Icons.tag),
        title: Text(context.l10n.importReviewNumber),
        subtitle: Text(contractNumber.text.isNotEmpty
            ? contractNumber.text
            : metadata.numbers.length > 1
                ? context.l10n.importChooseNumber
                : context.l10n.importNoNumberDetected),
        childrenPadding: const EdgeInsets.all(AppSpace.group),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
              controller: contractNumber,
              enabled: enabled,
              decoration: InputDecoration(
                  labelText: context.l10n.importMatchNumber,
                  helper: Text(context.l10n.importNumberHint)),
              onChanged: updateNumber),
          for (final candidate in metadata.numbers)
            ListTile(
                title: Text(candidate.number),
                subtitle: Text(candidate.passage),
                trailing: contractNumber.text == candidate.number
                    ? const Icon(Icons.check)
                    : null,
                onTap: enabled ? () => updateNumber(candidate.number) : null),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final personal = context.watch<AuthProvider?>()?.user?.isPersonal ?? true;
    final colors = Theme.of(context).colorScheme;
    final enabled = !busy && !saved;
    final notice = target != null
        ? (personal
            ? context.l10n.importPrivateContractNotice
            : context.l10n.importSharedContractNotice)
        : scope == 'Personal'
            ? context.l10n.importPrivateNotice
            : context.l10n.importSharedNotice;
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.importDocument)),
        bottomNavigationBar: file == null
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(
                          top: BorderSide(color: colors.outlineVariant))),
                  child: Align(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(notice,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: AppSpace.control),
                                FilledButton.icon(
                                  onPressed: enabled ? save : null,
                                  icon: const Icon(Icons.check),
                                  label: Text(saving
                                      ? context.l10n.importSaving
                                      : saved
                                          ? context.l10n.importSaved
                                          : target == null
                                              ? context
                                                  .l10n.importWithoutContract
                                              : context
                                                  .l10n.importAddToContract),
                                ),
                              ]),
                        ),
                      )),
                ),
              ),
        body: AppPage(
            child: SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(AppSpace.section),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (error != null) ...[
              Text(error!, style: TextStyle(color: colors.error)),
              if (file != null && !contractsLoaded)
                TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            await loadContracts();
                            if (mounted) setState(() => busy = false);
                          },
                    child: Text(context.l10n.importRetryContracts)),
              const SizedBox(height: AppSpace.group),
            ],
            if (busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpace.control),
              Text(saving
                  ? context.l10n.importSaving
                  : context.l10n.importReading),
              const SizedBox(height: AppSpace.section),
            ],
            if (file == null) ...[
              AppPanel(
                  child: AppFormColumn(children: [
                Icon(Icons.upload_file_outlined,
                    size: 40, color: colors.primary),
                Text(context.l10n.importStartHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                FilledButton.icon(
                    onPressed: busy ? null : pick,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.importChooseFile)),
                Text(context.l10n.importLimits,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ])),
              const SizedBox(height: AppSpace.group),
              Text(context.l10n.importPrivacyHint,
                  style: Theme.of(context).textTheme.bodySmall),
              if (inbox.isNotEmpty) ...[
                const SizedBox(height: AppSpace.section),
                Text(context.l10n.importPending,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpace.control),
                AppCollection(compact: true, children: [
                  for (final item in inbox)
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(item.name),
                      onTap: busy ? null : () => openShared(item.id),
                      trailing: IconButton(
                          tooltip: context.l10n.importDiscard,
                          icon: const Icon(Icons.close),
                          onPressed: busy
                              ? null
                              : () async {
                                  try {
                                    await service.discard(item.id);
                                    await refreshInbox();
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() => error = message(e));
                                    }
                                  }
                                }),
                    )
                ]),
              ],
            ] else ...[
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.description_outlined,
                        color: colors.onSurfaceVariant),
                    const SizedBox(width: AppSpace.control),
                    Text(file!.name,
                        style: Theme.of(context).textTheme.bodyMedium),
                    TextButton.icon(
                        key: const Key('openImportPreview'),
                        onPressed: saving
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ImportPreviewScreen(file: file!))),
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(context.l10n.preview)),
                  ]),
              const SizedBox(height: AppSpace.control),
              Text(context.l10n.importFirstPageHint,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpace.section),
              TextField(
                  controller: title,
                  enabled: enabled,
                  decoration: InputDecoration(
                      labelText: context.l10n.importTitle,
                      helper: !busy && metadata.subject == null
                          ? Text(context.l10n.importTitleFallback)
                          : null)),
              const SizedBox(height: AppSpace.group),
              parameterReview(),
              if (text.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(context.l10n.importRecognized,
                      style: Theme.of(context).textTheme.labelLarge),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (metadata.subjectPassage != null)
                      Text(
                          '${context.l10n.importSubjectSource}: ${metadata.subjectPassage}'),
                    SelectableText(text)
                  ],
                ),
              if (warning != null)
                Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpace.group),
                    child: Text(warning!)),
              const SizedBox(height: AppSpace.section),
              Text(context.l10n.importDestination,
                  style: Theme.of(context).textTheme.titleMedium),
              Text(context.l10n.importScoreHint,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpace.group),
              if (!busy && contractsLoaded && matches.isEmpty)
                Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.group),
                    child: Text(context.l10n.importNoMatch)),
              AppCollection(compact: true, children: [
                for (final match in matches.take(3))
                  contractChoice(match.contract, match: match),
                if (target != null &&
                    !matches.take(3).any((m) => m.contract.id == target!.id))
                  contractChoice(target!),
                ListTile(
                  leading: Icon(target == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off),
                  selected: target == null,
                  selectedTileColor: colors.primaryContainer,
                  title: Text(context.l10n.importNoContractChoice),
                  onTap: enabled
                      ? () => setState(() {
                            target = null;
                            destinationChosen = true;
                          })
                      : null,
                ),
              ]),
              const SizedBox(height: AppSpace.control),
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        enabled && contractsLoaded ? chooseContract : null,
                    icon: const Icon(Icons.search),
                    label: Text(context.l10n.importAnotherContract),
                  )),
              if (target == null && !personal) ...[
                const SizedBox(height: AppSpace.group),
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  isExpanded: true,
                  decoration:
                      InputDecoration(labelText: context.l10n.importLibrary),
                  items: [
                    DropdownMenuItem(
                        value: 'Personal',
                        child: Text(context.l10n.importPrivateLibrary,
                            overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'Tenant',
                        child: Text(context.l10n.importSharedLibrary,
                            overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: enabled
                      ? (value) => setState(() => scope = value!)
                      : null,
                ),
              ],
            ],
          ]),
        )),
      ),
    );
  }
}
