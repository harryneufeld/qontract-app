import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/contract/contract_detail_screen.dart';
import 'screens/contract/contract_form_screen.dart';
import 'screens/document/document_list_screen.dart';
import 'providers/contract_provider.dart';

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
      final contractProvider = context.watch<ContractProvider>();
      final contract = contractProvider.selectedContract;
      if (contract == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Contract Detail')),
          body: const Center(child: Text('No contract selected')),
        );
      }
      return ContractDetailScreen(contract: contract);
    },
    contractCreate: (_) => const ContractFormScreen(),
    contractEdit: (_) => const ContractFormScreen(),
    documentList: (_) => const DocumentListScreen(),
  };
}