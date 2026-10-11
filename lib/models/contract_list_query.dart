class ContractListQuery {
  final String status;
  final bool reviewBilling;
  final String scope;
  const ContractListQuery(
      {this.status = 'all', this.reviewBilling = false, this.scope = 'tenant'});
}
