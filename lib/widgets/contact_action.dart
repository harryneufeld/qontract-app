import '../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_toast.dart';

Uri contactUri(String value, {required bool email, String? subject}) => Uri(
    scheme: email ? 'mailto' : 'tel',
    path: email ? value.trim() : value.replaceAll(RegExp(r'\s+'), ''),
    query: email && subject != null && subject.trim().isNotEmpty
        ? 'subject=${Uri.encodeComponent(subject.trim())}'
        : null);

class ContactAction extends StatelessWidget {
  final String value;
  final bool email;
  final String? subject;
  const ContactAction(
      {super.key, required this.value, required this.email, this.subject});

  @override
  Widget build(BuildContext context) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(email ? Icons.email_outlined : Icons.phone_outlined),
      title: Text(value),
      trailing: Icon(email ? Icons.outgoing_mail : Icons.call_outlined),
      onTap: () async {
        try {
          if (await launchUrl(
              contactUri(value, email: email, subject: subject))) {
            return;
          }
        } catch (_) {
          // Platform failures leave the contact visible and report the failure.
        }
        if (context.mounted) {
          showToast(
              context,
              email
                  ? context.l10n.couldNotOpenEmailApp
                  : context.l10n.couldNotStartCall,
              style: ToastStyle.error);
        }
      });
}
