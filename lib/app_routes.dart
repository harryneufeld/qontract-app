import 'l10n/strings.dart';
import 'package:flutter/material.dart';

import 'models/contract.dart';
import 'models/contract_list_query.dart';
import 'screens/contract/contract_list_screen.dart';
import 'screens/contract/contract_detail_screen.dart';
import 'screens/contract/contract_form_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'models/contractor.dart';
import 'screens/account/account_screen.dart';
import 'screens/contractor/contractor_list_screen.dart';
import 'screens/contractor/contractor_detail_screen.dart';
import 'screens/contractor/contractor_form_screen.dart';
import 'screens/document/document_list_screen.dart';
import 'screens/document/document_import_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/login/email_confirmation_screen.dart';
import 'screens/login/password_reset_screen.dart';
import 'utils/reset_url.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/tenant/tenants_screen.dart';
import 'screens/login/register_screen.dart';
import 'screens/invoice/invoices_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String confirmEmail = '/confirm-email';

  static final Set<String> _retiredLinks = {};

  /// A confirmation link that already signed the user in must not be re-opened
  /// when the signed-in app rebuilds from its initial route.
  static void retireLink(String token) => _retiredLinks.add(token);

  /// Routes for emailed one-use links (password reset and email confirmation).
  static Route<dynamic>? resetLinkRoute(String name) {
    final uri = Uri.tryParse(name);
    final path = uri?.path;
    if (path != resetPassword && path != confirmEmail) return null;
    String? token;
    String? language;
    try {
      final values = uri!.queryParametersAll['token'];
      if (values?.length == 1) token = values!.single;
      final languages = uri.queryParametersAll['lang'];
      if (languages?.length == 1 && ['en', 'de'].contains(languages!.single)) {
        language = languages.single;
      }
    } on FormatException {
      // Malformed query encodings show the invalid-link screen safely.
    }
    if (token != null && _retiredLinks.contains(token)) return null;
    clearResetTokenFromUrl('#$path');
    if (path == confirmEmail) {
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: confirmEmail),
        builder: (_) => ConfirmEmailScreen(token: token, language: language),
      );
    }
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: resetPassword),
      builder: (_) =>
          PasswordResetScreen(complete: true, token: token, language: language),
    );
  }

  static const String dashboard = '/dashboard';
  static const String contractDetail = '/contract/detail';
  static const String contractList = '/contracts';
  static const String contractCreate = '/contract/create';
  static const String contractEdit = '/contract/edit';
  static const String documentList = '/documents';
  static const String documentImport = '/documents/import';
  static const String contractorList = '/contractors';
  static const String contractorDetail = '/contractor/detail';
  static const String contractorForm = '/contractor/form';
  static const String settings = '/settings';
  static const String account = '/account';
  static const String tenants = '/tenants';
  static const String register = '/register';
  static const String invoices = '/invoices';

  static final Map<String, Widget Function(BuildContext)> routes = {
    login: (_) => const LoginScreen(),
    forgotPassword: (_) => const PasswordResetScreen(),
    resetPassword: (_) => const PasswordResetScreen(complete: true),
    dashboard: (_) => const DashboardScreen(),
    contractList: (context) {
      final query =
          ModalRoute.of(context)?.settings.arguments as ContractListQuery?;
      return ContractListScreen(
          initialFilter: query?.status ?? 'all',
          reviewBilling: query?.reviewBilling ?? false,
          initialScope: query?.scope ?? 'tenant');
    },
    invoices: (_) => const InvoicesScreen(),
    contractDetail: (context) {
      final contract = ModalRoute.of(context)?.settings.arguments as Contract?;
      if (contract == null) {
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.contractDetail)),
          body: Center(child: Text(context.l10n.noContractSelected)),
        );
      }
      return ContractDetailScreen(contract: contract);
    },
    contractCreate: (_) => const ContractFormScreen(),
    contractEdit: (context) {
      final contract = ModalRoute.of(context)?.settings.arguments as Contract?;
      if (contract == null) {
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.editContract)),
          body: Center(child: Text(context.l10n.noContractSelected)),
        );
      }
      return ContractFormScreen(contract: contract);
    },
    documentList: (_) => const DocumentListScreen(),
    documentImport: (_) => const DocumentImportScreen(),
    contractorList: (_) => const ContractorListScreen(),
    contractorDetail: (context) {
      final contractor =
          ModalRoute.of(context)?.settings.arguments as Contractor?;
      if (contractor == null) {
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.contractor)),
          body: Center(child: Text(context.l10n.noContractorSelected)),
        );
      }
      return ContractorDetailScreen(key: ValueKey(contractor.id));
    },
    contractorForm: (context) {
      final contractor =
          ModalRoute.of(context)?.settings.arguments as Contractor?;
      return ContractorFormScreen(
        key: ValueKey(contractor?.id ?? 'new'),
        contractor: contractor,
      );
    },
    settings: (_) => const SettingsScreen(),
    account: (_) => const AccountScreen(),
    tenants: (_) => const TenantsScreen(),
    register: (_) => const RegisterScreen(),
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
        return S.current.active;
      case ContractStatus.draft:
        return S.current.draft;
      case ContractStatus.expired:
        return S.current.expired;
      case ContractStatus.terminated:
        return S.current.terminated;
      default:
        return status;
    }
  }
}
