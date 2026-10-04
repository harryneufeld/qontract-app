import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// State the visibility before the user creates a record.
class WorkspaceNotice extends StatelessWidget {
  const WorkspaceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider?>()?.user;
    if (user == null) return const SizedBox.shrink();
    final personal = user.isPersonal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(personal ? Icons.lock_outline : Icons.groups_outlined,
            size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(personal
                ? 'Personal workspace · Only you can access this record and its documents.'
                : 'Tenant workspace · This record and its contract documents are shared with tenant members.')),
      ]),
    );
  }
}
