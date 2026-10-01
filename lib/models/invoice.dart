class Invoice {
  final String id, invoiceDate, amount;
  final String? dueDate, currency, invoiceNumber, description;
  final int? contractId, documentId;
  final bool isDeleted;
  Invoice(
      {required this.id,
      required this.invoiceDate,
      required this.amount,
      this.dueDate,
      this.currency,
      this.invoiceNumber,
      this.description,
      this.contractId,
      this.documentId,
      this.isDeleted = false});
  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
      id: json['id'] as String,
      invoiceDate: json['invoiceDate'] as String,
      amount: json['amount'] as String,
      dueDate: json['dueDate'] as String?,
      currency: json['currency'] as String?,
      invoiceNumber: json['invoiceNumber'] as String?,
      description: json['description'] as String?,
      contractId: (json['contractId'] as num?)?.toInt(),
      documentId: (json['documentId'] as num?)?.toInt(),
      isDeleted: json['isDeleted'] == true);
  String get amountLabel => '$amount ${currency ?? '(currency unknown)'}';
}
