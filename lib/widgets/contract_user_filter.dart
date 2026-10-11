import 'package:flutter/material.dart';
import '../models/contract.dart';

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
  final String scope;
  final ValueChanged<String> onChanged;
  final double height;
  const ContractUserFilter(
      {super.key,
      required this.contracts,
      required this.scope,
      required this.onChanged,
      this.height = 48});

  @override
  Widget build(BuildContext context) {
    final users = <int, String>{
      for (final c in contracts)
        if (c.responsibleUserId != null)
          c.responsibleUserId!:
              c.responsibleUserName ?? 'User #${c.responsibleUserId}',
    }.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final label = switch (scope) {
      'mine' => 'My contracts',
      'unassigned' => 'Unassigned',
      'tenant' => 'Responsible user',
      _ => users.where((u) => 'user:${u.key}' == scope).firstOrNull?.value ??
          'Selected user',
    };
    return MenuAnchor(
        builder: (context, controller, child) => Tooltip(
            message: 'Filter by responsible user',
            child: SizedBox(
                height: height,
                child: OutlinedButton(
                    key: const Key('responsibleUserFilter'),
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                    child: Row(children: [
                      const Icon(Icons.person_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(label,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.keyboard_arrow_down, size: 20),
                    ])))),
        menuChildren: [
          for (final entry in <String, String>{
            'tenant': 'All workspace contracts',
            'mine': 'My contracts',
            'unassigned': 'Unassigned',
            for (final user in users) 'user:${user.key}': user.value,
          }.entries)
            MenuItemButton(
                onPressed: () => onChanged(entry.key),
                leadingIcon:
                    Icon(scope == entry.key ? Icons.check : null, size: 20),
                child: Text(entry.value)),
        ]);
  }
}
