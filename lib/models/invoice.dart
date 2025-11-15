
class InvoiceItem {
  final int? id;
  final int? invoiceId;
  String name;
  double qty;
  double rate;
  InvoiceItem({this.id, this.invoiceId, required this.name, required this.qty, required this.rate});

  double get lineTotal => qty * rate;

  factory InvoiceItem.fromMap(Map<String, Object?> m) => InvoiceItem(
    id: m['id'] as int?,
    invoiceId: m['invoice_id'] as int?,
    name: m['name'] as String,
    qty: (m['qty'] as num).toDouble(),
    rate: (m['rate'] as num).toDouble(),
  );

  Map<String, Object?> toMap(int invoiceId) => {
    if (id != null) 'id': id,
    'invoice_id': invoiceId,
    'name': name,
    'qty': qty,
    'rate': rate,
  };
}

class Invoice {
  final int? id;
  String number;
  int clientId;
  String issueDate; // ISO yyyy-MM-dd
  String? dueDate;
  String? notes;
  String status; // paid|pending|overdue
  double discount;
  double taxPercent;
  List<InvoiceItem> items;

  Invoice({
    this.id,
    required this.number,
    required this.clientId,
    required this.issueDate,
    this.dueDate,
    this.notes,
    this.status = 'pending',
    this.discount = 0,
    this.taxPercent = 18,
    this.items = const [],
  });

  double get subTotal => items.fold(0, (s, e) => s + e.lineTotal);
  double get total => (subTotal - discount) * (1 + taxPercent / 100);

  factory Invoice.fromMap(Map<String, Object?> m) => Invoice(
    id: m['id'] as int?,
    number: m['number'] as String,
    clientId: m['client_id'] as int,
    issueDate: m['issue_date'] as String,
    dueDate: m['due_date'] as String?,
    notes: m['notes'] as String?,
    status: m['status'] as String,
    discount: (m['discount'] as num).toDouble(),
    taxPercent: (m['tax_percent'] as num).toDouble(),
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'number': number,
    'client_id': clientId,
    'issue_date': issueDate,
    'due_date': dueDate,
    'notes': notes,
    'status': status,
    'discount': discount,
    'tax_percent': taxPercent,
  };
}
