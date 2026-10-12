import '../../l10n/strings.dart';
import 'package:flutter/material.dart';

import '../../models/address.dart';
import '../../services/api_service.dart';
import '../../widgets/app_bottom_actions.dart';
import '../../widgets/app_design.dart';
import '../../widgets/app_toast.dart';
import '../contractor/address_editor_dialog.dart';

class AddressBookScreen extends StatefulWidget {
  final String entityType;
  final bool canEdit;
  final ApiService? api;
  const AddressBookScreen(
      {super.key, required this.entityType, required this.canEdit, this.api});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  late final _api = widget.api ?? ApiService();
  List<Address> _addresses = [];
  Address? _selected;
  bool _loading = true, _busy = false;
  String? _error;
  int _generation = 0;
  bool get _personal => widget.entityType == 'Person';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = _personal
          ? await _api.getMyAddresses()
          : await _api.getTenantAddresses();
      if (!mounted || generation != _generation) return;
      setState(() {
        _addresses = rows;
        _selected = rows.where((a) => a.id == _selected?.id).firstOrNull;
      });
    } on ApiException catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.message;
          _addresses = [];
          _selected = null;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _edit([Address? address]) async {
    if (_busy || _loading || !widget.canEdit) return;
    final draft = await showAddressEditorDialog(context,
        entityType: widget.entityType, address: address);
    if (draft == null || !mounted) return;
    await _mutate(() async {
      _selected = address == null
          ? await _api.createAddress(draft)
          : await _api.updateAddress(draft);
    });
  }

  Future<void> _remove() async {
    final address = _selected;
    if (address == null || _busy || !widget.canEdit) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: Text(context.l10n.removeAddress),
              content:
                  Text(context.l10n.thisHidesTheAddressWhileKeepingItsSaved),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(context.l10n.cancel)),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(context.l10n.remove)),
              ],
            ));
    if (confirmed == true && mounted) {
      await _mutate(() async {
        await _api.deactivateAddress(address.id);
        _selected = null;
      });
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, style: ToastStyle.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy && !_loading && _error == null;
    return Scaffold(
      appBar: AppBar(
          title: Text(_personal
              ? context.l10n.myAddresses
              : context.l10n.tenantAddresses)),
      floatingActionButton: widget.canEdit
          ? AppBottomActions(
              maxWidth: 760,
              icon: Icons.add,
              tooltip: context.l10n.addAddress,
              onPressed: enabled ? () => _edit() : null,
              secondary: [
                AppBottomAction(
                    icon: Icons.edit_outlined,
                    tooltip: context.l10n.editAddress,
                    onPressed: enabled && _selected != null
                        ? () => _edit(_selected)
                        : null),
                AppBottomAction(
                    icon: Icons.delete_outline,
                    tooltip: context.l10n.removeAddress225,
                    destructive: true,
                    onPressed: enabled && _selected != null ? _remove : null),
              ],
            )
          : null,
      body: RefreshIndicator(
          onRefresh: _load,
          child: AppPageListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 112),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppPageHeading(
                  eyebrow: _personal
                      ? context.l10n.privateAccountDetails
                      : context.l10n.sharedTenantDetails,
                  title: _personal
                      ? context.l10n.yourPostalAddresses
                      : context.l10n.tenantPostalAddresses,
                  description: _personal
                      ? context.l10n.onlyYouCanViewOrChangeTheseAddresses
                      : context.l10n
                          .tenantMembersCanViewTheseAddressesAdministratorsCan),
              const SizedBox(height: AppSpace.section),
              if (_loading || _busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.retry)),
              ] else if (!_loading && _addresses.isEmpty)
                Text(context.l10n.noAddressesYet),
              AppCollection(children: [
                for (final address in _addresses)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: AppCollectionRow(
                        child: ListTile(
                      selected: _selected?.id == address.id,
                      leading: Icon(_selected?.id == address.id
                          ? Icons.check_circle_outline
                          : Icons.location_on_outlined),
                      title: Text(address.display.isEmpty
                          ? context.l10n.addressDetailsNotRecorded
                          : address.display),
                      subtitle: widget.canEdit
                          ? Text(
                              context.l10n.selectToEditOrRemoveUsingTheActions)
                          : null,
                      onTap: widget.canEdit && enabled
                          ? () => setState(() => _selected = address)
                          : null,
                    )),
                  )
              ]),
            ],
          )),
    );
  }
}
