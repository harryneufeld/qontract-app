import 'package:flutter/material.dart';

import 'models/contract.dart';
import 'screens/contract/contract_detail_screen.dart';
import 'screens/contract/contract_form_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'models/contractor.dart';
import 'screens/account/account_screen.dart';
import 'screens/contractor/contractor_list_screen.dart';
import 'screens/contractor/contractor_detail_screen.dart';
import 'screens/contractor/contractor_form_screen.dart';
import 'screens/document/document_list_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/settings/settings_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String contractDetail = '/contract/detail';
  static const String contractCreate = '/contract/create';
  static const String contractEdit = '/contract/edit';
  static const String documentList = '/documents';
  static const String contractorList = '/contractors';
  static const String contractorDetail = '/contractor/detail';
  static const String contractorForm = '/contractor/form';
  static const String settings = '/settings';
  static const String account = '/account';

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
    contractorList: (_) => const ContractorListScreen(),
    contractorDetail: (context) {
      final contractor = ModalRoute.of(context)?.settings.arguments as Contractor?;
      if (contractor == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Contractor')),
          body: const Center(child: Text('No contractor selected')),
        );
      }
      return ContractorDetailScreen(key: ValueKey(contractor.id));
    },
    contractorForm: (context) {
      final contractor = ModalRoute.of(context)?.settings.arguments as Contractor?;
      return ContractorFormScreen(
        key: ValueKey(contractor?.id ?? 'new'),
        contractor: contractor,
      );
    },
    settings: (_) => const SettingsScreen(),
    account: (_) => const AccountScreen(),
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
