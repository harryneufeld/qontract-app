/// Tenant-wide contract counters from `GET /contracts/stats` (app#33).
///
/// The dashboard list is paginated (issue #21), so the stat chips must be
/// computed over ALL of the tenant's contracts server-side instead of the
/// loaded slice.
class ContractStats {
  final int total;
  final int active;
  final int expiring;
  final int expired;
  final int minDateApproaching;

  const ContractStats({
    required this.total,
    required this.active,
    required this.expiring,
    required this.expired,
    required this.minDateApproaching,
  });

  factory ContractStats.fromJson(Map<String, dynamic> json) => ContractStats(
        total: (json['total'] as num?)?.toInt() ?? 0,
        active: (json['active'] as num?)?.toInt() ?? 0,
        expiring: (json['expiring'] as num?)?.toInt() ?? 0,
        expired: (json['expired'] as num?)?.toInt() ?? 0,
        minDateApproaching:
            (json['minDateApproaching'] as num?)?.toInt() ?? 0,
      );
}
