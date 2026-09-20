import 'package:flutter/material.dart';

import 'models/contract.dart';
import 'screens/contract/contract_detail_screen.dart';
import 'screens/contract/contract_form_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/document/document_list_screen.dart';
import 'screens/login/login_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String contractDetail = '/contract/detail';
  static const String contractCreate = '/contract/create';
  static const String contractEdit = '/contract/edit';
  static const String documentList = '/documents';

  static final Map<String, Widget Function(BuildContext)> routes = {
    login: (_) => const LoginScreen(),
    dashboard: (_) => const DashboardScreen(),
    contractDetail: (context) {
      final contract = ModalRoute.of(context)?.settings.arguments as Contract?;
      if (contract == null) {
        return Scaffold(
          appBar: AppBar(title: Text('Contract Detail')),
          body: const Center(child: Text('No contract selected')),
        );
      }
      return ContractDetailScreen(contract: contract);
    },
    contractCreate: (_) => const ContractFormScreen(),
    contractEdit: (context) {
      final contract = ModalRoute.of(context)?.settings.arguments as Contract?;
      if (contract == null) {
        return Scaffold(
          appBar: AppBar(title: Text('Edit Contract')),
          body: const Center(child: Text('No contract selected')),
        );
      }
      return ContractFormScreen(contract: contract);
    },
    documentList: (_) => const DocumentListScreen(),
  };
}

/// Shared status colors/labels so all widgets stay consistent.
class ContractStatusStyle {
  static Color color(BuildContext context, String status) {
    switch (status) {
      case ContractStatus.active:
        return Colors.green;
      case ContractStatus.draft:
        return Colors.blue;
      case ContractStatus.expired:
        return Colors.grey;
      case ContractStatus.terminated:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String label(String status) {
    switch (status) {
      case ContractStatus.active:
        return 'Active';
      case ContractStatus.draft:
        return 'Draft';
      case ContractStatus.expired:
        return 'Expired';
      case ContractStatus.terminated:
        return 'Terminated';
      default:
        return status;
    }
  }
}
