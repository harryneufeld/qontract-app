import '../../widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract.dart';
import '../../models/document.dart';
import '../../models/invoice.dart';
import '../../providers/document_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import '../document/document_list_screen.dart';

class InvoicesScreen extends StatefulWidget {
  final int? contractId;
  final ApiService? api;
  const InvoicesScreen({super.key, this.contractId, this.api});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late final ApiService api = widget.api ?? ApiService();
  List<Invoice> rows = [];
  bool loading = true, deleted = false, more = false;
  int page = 1;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool append = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final nextPage = append ? page + 1 : 1;
      final result = await api.getInvoices(
          contractId: widget.contractId, deleted: deleted, page: nextPage);
      if (!mounted) return;
      setState(() {
        rows = append ? [...rows, ...result] : result;
        page = nextPage;
        more = result.length == 50;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Invoice? invoice]) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => InvoiceEditor(
            api: api, invoice: invoice, initialContractId: widget.contractId));
    if (saved == true && mounted) await load();
  }

  Future<void> archive(Invoice invoice) async {
    if (!deleted) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Archive invoice?'),
                  content: const Text(
                      'You can restore it from Archived invoices. Its evidence file is retained.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Archive'))
                  ]));
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => loading = true);
    try {
      if (deleted) {
        await api.restoreInvoice(invoice.id);
      } else {
        await api.archiveInvoice(invoice.id);
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, style: ToastStyle.error);
    }
    if (mounted) await load();
  }

  Future<void> evidence(Invoice invoice) async {
    try {
      final doc = await api.getDocument(invoice.documentId!);
      if (!mounted) return;
      final provider = context.read<DocumentProvider>();
      final ok = await provider.downloadAndOpen(doc);
      if (mounted && !ok) {
        showToast(context, provider.errorMessage ?? 'Could not open evidence.',
            style: ToastStyle.error);
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, style: ToastStyle.error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(
              widget.contractId == null ? 'Invoices' : 'Contract invoices'),
          actions: [
            IconButton(
                tooltip: 'Refresh',
                onPressed: loading ? null : load,
                icon: const Icon(Icons.refresh)),
            IconButton(
                tooltip:
                    deleted ? 'Show active invoices' : 'Show archived invoices',
                onPressed: loading
                    ? null
                    : () {
                        setState(() {
                          deleted = !deleted;
                          rows = [];
                        });
                        load();
                      },
                icon:
                    Icon(deleted ? Icons.receipt_long : Icons.archive_outlined))
          ]),
      floatingActionButton: deleted
          ? null
          : FloatingActionButton(
              tooltip: 'New invoice',
              onPressed: loading ? null : edit,
              child: const Icon(Icons.add)),
      body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (deleted) const Text('Archived invoices'),
                if (loading) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (!loading && rows.isEmpty && error == null)
                  const Text('No invoices yet.'),
                AppCollection(children: [
                  for (final invoice in rows)
                    AppCollectionRow(
                        child: ListTile(
                            title: Text(
                                '${invoice.invoiceNumber ?? 'Invoice'} · ${invoice.amountLabel}'),
                            subtitle: Text(
                                '${invoice.invoiceDate}${invoice.dueDate == null ? '' : ' · Due ${invoice.dueDate}'}${invoice.description == null ? '' : '\n${invoice.description}'}'),
                            onTap:
                                deleted || loading ? null : () => edit(invoice),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              if (invoice.documentId != null && !deleted)
                                IconButton(
                                    tooltip: 'Open evidence',
                                    onPressed: loading
                                        ? null
                                        : () => evidence(invoice),
                                    icon: const Icon(Icons.attach_file)),
                              IconButton(
                                  tooltip: deleted
                                      ? 'Restore invoice'
                                      : 'Archive invoice',
                                  onPressed:
                                      loading ? null : () => archive(invoice),
                                  icon: Icon(deleted
                                      ? Icons.restore
                                      : Icons.archive_outlined))
                            ])))
                ]),
                if (more)
                  TextButton(
                      onPressed: loading ? null : () => load(append: true),
                      child: const Text('Load more')),
                const SizedBox(height: 80)
              ])));
}

class InvoiceEditor extends StatefulWidget {
  final ApiService api;
  final Invoice? invoice;
  final int? initialContractId;
  const InvoiceEditor(
      {super.key, required this.api, this.invoice, this.initialContractId});
  @override
  State<InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<InvoiceEditor> {
  final form = GlobalKey<FormState>();
  late final date = TextEditingController(
      text: widget.invoice?.invoiceDate ??
          DateTime.now().toIso8601String().split('T').first);
  late final due = TextEditingController(text: widget.invoice?.dueDate ?? '');
  late final amount = TextEditingController(text: widget.invoice?.amount ?? '');
  late final currency =
      TextEditingController(text: widget.invoice?.currency ?? '');
  late final number =
      TextEditingController(text: widget.invoice?.invoiceNumber ?? '');
  late final description =
      TextEditingController(text: widget.invoice?.description ?? '');
  late int? contractId = widget.invoice?.contractId ?? widget.initialContractId;
  late int? documentId = widget.invoice?.documentId;
  List<Contract> contracts = [];
  List<Document> documents = [];
  bool busy = false, fetching = true;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    for (final c in [date, due, amount, currency, number, description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      contracts = await widget.api.getContractList();
      if (!mounted) return;
      await fetchDocuments();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          fetching = false;
        });
      }
    }
  }

  Future<void> fetchDocuments() async {
    final request = ++generation;
    setState(() {
      fetching = true;
      error = null;
    });
    try {
      final result = contractId == null
          ? <Document>[]
          : await widget.api.getDocuments(contractId!);
      if (!mounted || request != generation) return;
      setState(() => documents = result);
    } on ApiException catch (e) {
      if (mounted && request == generation) setState(() => error = e.message);
    } finally {
      if (mounted && request == generation) setState(() => fetching = false);
    }
  }

  String? validDate(String? value, {bool optional = false}) {
    if (optional && (value == null || value.isEmpty)) return null;
    final parsed = DateTime.tryParse(value ?? '');
    return parsed != null &&
            RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value!) &&
            parsed.toIso8601String().split('T').first == value
        ? null
        : 'Use yyyy-mm-dd';
  }

  Widget dateField(TextEditingController controller, String label,
          {bool optional = false}) =>
      TextFormField(
          controller: controller,
          decoration: InputDecoration(
              labelText: label,
              suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: busy
                      ? null
                      : () async {
                          final selected = await showDatePicker(
                              context: context,
                              initialDate: DateTime.tryParse(controller.text) ??
                                  DateTime.now(),
                              firstDate: DateTime(1),
                              lastDate: DateTime(9999));
                          if (selected != null) {
                            controller.text =
                                selected.toIso8601String().split('T').first;
                          }
                        })),
          validator: (v) => validDate(v, optional: optional));
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.saveInvoice({
        'invoiceDate': date.text,
        'dueDate': due.text.isEmpty ? null : due.text,
        'amount': amount.text.trim(),
        'currency': currency.text.trim().isEmpty
            ? null
            : currency.text.trim().toUpperCase(),
        'invoiceNumber': number.text,
        'description': description.text,
        'contractId': contractId,
        'documentId': documentId
      }, id: widget.invoice?.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.invoice == null ? 'New invoice' : 'Edit invoice'),
          content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: AbsorbPointer(
                          absorbing: busy,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            if (fetching) const LinearProgressIndicator(),
                            if (error != null)
                              Text(error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                            dateField(date, 'Invoice date'),
                            dateField(due, 'Due date (optional)',
                                optional: true),
                            TextFormField(
                                controller: amount,
                                decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    helperText:
                                        'Negative amounts are allowed for credits.'),
                                validator: (v) => RegExp(
                                            r'^[+-]?\d+([.,]\d+)?$')
                                        .hasMatch(v?.trim() ?? '')
                                    ? null
                                    : 'Enter an amount without currency or grouping'),
                            TextFormField(
                                controller: currency,
                                maxLength: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Currency (optional)',
                                    helperText:
                                        'Leave blank when unknown. Example: EUR'),
                                validator: (v) => v == null ||
                                        v.trim().isEmpty ||
                                        RegExp(r'^[A-Za-z]{3}$')
                                            .hasMatch(v.trim())
                                    ? null
                                    : 'Use a three-letter code'),
                            TextFormField(
                                controller: number,
                                maxLength: 100,
                                decoration: const InputDecoration(
                                    labelText: 'Invoice number (optional)')),
                            TextFormField(
                                controller: description,
                                maxLength: 2000,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Description (optional)')),
                            DropdownButtonFormField<int>(
                                initialValue: contractId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Contract (optional)'),
                                items: [
                                  const DropdownMenuItem<int>(
                                      value: null, child: Text('No contract')),
                                  for (final c in contracts)
                                    DropdownMenuItem(
                                        value: c.id, child: Text(c.title)),
                                  if (contractId != null &&
                                      !contracts.any((c) => c.id == contractId))
                                    DropdownMenuItem(
                                        value: contractId,
                                        child: Text('Contract #$contractId'))
                                ],
                                onChanged: fetching
                                    ? null
                                    : (v) {
                                        setState(() {
                                          contractId = v;
                                          documentId = null;
                                        });
                                        fetchDocuments();
                                      }),
                            DropdownButtonFormField<int>(
                                key: ValueKey('$contractId/$documentId'),
                                initialValue: documentId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Evidence file (optional)'),
                                items: [
                                  const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('No evidence file')),
                                  for (final d in documents)
                                    DropdownMenuItem(
                                        value: d.id,
                                        child: Text(
                                            '${d.displayName} · v${d.version}')),
                                  if (documentId != null &&
                                      !documents.any((d) => d.id == documentId))
                                    DropdownMenuItem(
                                        value: documentId,
                                        child: Text(
                                            'Retained evidence #$documentId'))
                                ],
                                onChanged: fetching
                                    ? null
                                    : (v) => setState(() => documentId = v)),
                            if (contractId == null)
                              TextButton.icon(
                                  icon: const Icon(Icons.attach_file),
                                  label: const Text('Choose tenant file'),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final selected = await Navigator.of(
                                                  context)
                                              .push<Document>(MaterialPageRoute(
                                                  builder: (_) =>
                                                      DocumentListScreen(
                                                          api: widget.api,
                                                          selectEvidence:
                                                              true)));
                                          if (selected != null && mounted) {
                                            setState(() {
                                              documents = [
                                                ...documents.where(
                                                    (d) => d.id != selected.id),
                                                selected
                                              ];
                                              documentId = selected.id;
                                            });
                                          }
                                        }),
                          ]))))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: busy || fetching ? null : save,
                child: Text(busy ? 'Saving…' : 'Save'))
          ]);
}
