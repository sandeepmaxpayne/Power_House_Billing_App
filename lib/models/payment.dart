
class Payment {
  final int? id;
  final int invoiceId;
  final double amount;
  final String date; // ISO
  final String? method;
  final String? reference;

  Payment({this.id, required this.invoiceId, required this.amount, required this.date, this.method, this.reference});

  factory Payment.fromMap(Map<String, Object?> m) => Payment(
    id: m['id'] as int?,
    invoiceId: m['invoice_id'] as int,
    amount: (m['amount'] as num).toDouble(),
    date: m['date'] as String,
    method: m['method'] as String?,
    reference: m['reference'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'invoice_id': invoiceId,
    'amount': amount,
    'date': date,
    'method': method,
    'reference': reference,
  };
}
