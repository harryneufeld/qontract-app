import '../../l10n/strings.dart';
import '../../models/app_notification.dart';

/// Wording for a notification. The backend sends only the kind and its
/// numbers; the text follows the app language.
class NotificationText {
  final String title;
  final String body;
  const NotificationText(this.title, this.body);
}

NotificationText describeNotification(AppNotification n,
    {AppLocalizations? l10n}) {
  final l = l10n ?? S.current;
  final p = n.params;
  final contract = n.contractTitle ?? l.ntfContractFallback;
  String when() => l.ntfDueIn((p['daysLeft'] as num?)?.toInt() ?? 0);
  String text(String key) => S.dateText('${p[key] ?? ''}');

  switch (n.kind) {
    case NotificationKind.noticeDeadline:
      final body = p['autoRenews'] == true
          ? l.ntfNoticeBodyRenews(contract, text('deadline'), text('termEnd'))
          : l.ntfNoticeBodyEnds(contract, text('deadline'), text('termEnd'));
      return NotificationText(l.ntfNoticeTitle(when()), body);
    case NotificationKind.endDate:
      return NotificationText(
          l.ntfEndTitle(when()), l.ntfEndBody(contract, text('endDate')));
    case NotificationKind.minimumTerm:
      return NotificationText(
          l.ntfMinTitle(when()), l.ntfMinBody(contract, text('minimumDate')));
    case NotificationKind.priceIncrease:
      return NotificationText(
          l.ntfPriceTitle('${p['percent']}'),
          l.ntfPriceBody(
              contract, '${p['from']}', '${p['to']}', text('effectiveFrom')));
    case NotificationKind.insuranceReview:
      return NotificationText(l.ntfInsuranceTitle,
          l.ntfInsuranceBody(contract, '${p['monthsSinceUpdate']}'));
    case NotificationKind.missingData:
      final noDocuments = p['noDocuments'] == true;
      final noContractor = p['noContractor'] == true;
      return NotificationText(
          l.ntfMissingTitle,
          noDocuments && noContractor
              ? l.ntfMissingBoth(contract)
              : noDocuments
                  ? l.ntfMissingDocument(contract)
                  : l.ntfMissingContractor(contract));
    case NotificationKind.adminWithout2fa:
      return NotificationText(l.ntfAdminTitle, l.ntfAdminBody);
    default:
      return NotificationText(n.kind, contract);
  }
}

/// Display names for the settings screens.
String notificationKindLabel(String kind, {AppLocalizations? l10n}) {
  final l = l10n ?? S.current;
  return switch (kind) {
    NotificationKind.noticeDeadline => l.ntfKindNoticeDeadline,
    NotificationKind.endDate => l.ntfKindEndDate,
    NotificationKind.minimumTerm => l.ntfKindMinimumTerm,
    NotificationKind.priceIncrease => l.ntfKindPriceIncrease,
    NotificationKind.insuranceReview => l.ntfKindInsuranceReview,
    NotificationKind.missingData => l.ntfKindMissingData,
    NotificationKind.adminWithout2fa => l.ntfKindAdminWithout2fa,
    _ => kind,
  };
}
