import 'package:flutter/material.dart';
import '../models/contract.dart';
import 'app_design.dart';

bool matchesContractUser(Contract contract, String scope, int? userId) {
  if (scope == 'mine') {
    return contract.responsibleUserId == userId ||
        contract.isPersonal && contract.ownerUserId == userId;
  }
  if (scope == 'unassigned') return contract.responsibleUserId == null;
  if (scope.startsWith('user:')) {
    return contract.responsibleUserId == int.tryParse(scope.substring(5));
  }
  return true;
}

class ContractUserFilter extends StatelessWidget {
  final List<Contract> contracts;
  final int? currentUserId;
  final String scope;
  final ValueChanged<String> onChanged;
  const ContractUserFilter(
      {super.key,
      required this.contracts,
      required this.currentUserId,
      required this.scope,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final users = <int, String>{
      for (final c in contracts)
        if (c.responsibleUserId != null && c.responsibleUserId != currentUserId)
          c.responsibleUserId!:
              c.responsibleUserName ?? 'User #${c.responsibleUserId}',
    }.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final selectedScope =
        currentUserId != null && scope == 'user:$currentUserId'
            ? 'mine'
            : scope;
    final label = switch (selectedScope) {
      'mine' => 'My contracts',
      'unassigned' => 'Unassigned',
      'tenant' => 'Responsible user',
      _ => users.where((u) => 'user:${u.key}' == scope).firstOrNull?.value ??
          'Selected user',
    };
    final theme = Theme.of(context);
    return LayoutBuilder(
        builder: (context, constraints) => MenuAnchor(
                crossAxisUnconstrained: false,
                style: MenuStyle(
                  fixedSize: WidgetStatePropertyAll(
                      Size.fromWidth(constraints.maxWidth)),
                  backgroundColor:
                      WidgetStatePropertyAll(theme.colorScheme.surface),
                  surfaceTintColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                  elevation: const WidgetStatePropertyAll(0),
                  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                  side: WidgetStatePropertyAll(
                      BorderSide(color: theme.colorScheme.outlineVariant)),
                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                ),
                builder: (context, controller, child) => Tooltip(
                    message: 'Filter by responsible user',
                    child: SizedBox(
                        height: AppFilterStyle.height(context),
                        child: Material(
                            type: MaterialType.transparency,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: Semantics(
                                button: true,
                                child: InkWell(
                                    key: const Key('responsibleUserFilter'),
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => controller.isOpen
                                        ? controller.close()
                                        : controller.open(),
                                    child: InputDecorator(
                                        expands: true,
                                        isFocused: controller.isOpen,
                                        decoration: AppFilterStyle.decoration(
                                            context: context,
                                            icon: Icons.person_outline,
                                            suffixIcon: const Icon(
                                                Icons.keyboard_arrow_down)),
                                        child: Text(label,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant,
                                                    fontWeight:
                                                        FontWeight.w400),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis))))))),
                menuChildren: [
                  for (final entry in <String, String>{
                    'tenant': 'All workspace contracts',
                    'mine': 'My contracts',
                    'unassigned': 'Unassigned',
                    for (final user in users) 'user:${user.key}': user.value,
                  }.entries)
                    MenuItemButton(
                        onPressed: () => onChanged(entry.key),
                        leadingIcon: Icon(
                            selectedScope == entry.key ? Icons.check : null,
                            size: 20),
                        child: Text(entry.value)),
                ]));
  }
}
