// lib/screens/web_pos_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/billing_db.dart';

/// ====== BUSINESS & INVOICE SETTINGS ======

const String kShopName = 'Battery Zone';
const String kShopAddress1 = 'Hullung Roas';
const String kShopAddress2 = '';
const String kShopPhone = '912345670';
const String kShopEmail = 'a@bc.com';
const String kShopWebsite = 'none';
const String kShopGst = '1343';

const String kBankAccountHolder = 'Battery';
const String kBankName = 'SBI';
const String kBankAccountNumber = '566556';
const String kBankIfsc = 'birsa0001';
const String kUpiId = ''; // optional

const bool kPrintTwoCopies = false;
const String kInvoicePrefix = 'BZ-';

const bool kIncludeDigitalSignature = true;

// Footer lines
const String kFooterLine1 = 'This is a computer generated invoice.';
const String kFooterLine2 = 'Thank you for your business.';

String formatCurrency(double value) {
  // ₹ 12,500.00 style
  final f = NumberFormat('#,##,##0.00', 'en_IN');
  return '₹ ${f.format(value)}';
}

/// =========================================

class PosItem {
  PosItem({
    required this.name,
    required this.qty,
    required this.rate,
  });

  String name;
  int qty;
  double rate;

  double get amount => qty * rate;
}

class WebPosScreen extends StatefulWidget {
  const WebPosScreen({super.key});

  @override
  State<WebPosScreen> createState() => _WebPosScreenState();
}

class _WebPosScreenState extends State<WebPosScreen> {
  // NEW: customer fields
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();

  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();

  final _discountCtrl = TextEditingController(text: '0');
  final _taxPctCtrl = TextEditingController(text: '0');

  final List<PosItem> _items = [];
  int _invoiceCounter = 1;

  double get subTotal =>
      _items.fold(0.0, (previousValue, e) => previousValue + e.amount);

  double get discount => double.tryParse(_discountCtrl.text.trim()) ?? 0.0;

  double get taxPercent => double.tryParse(_taxPctCtrl.text.trim()) ?? 0.0;

  double get taxAmount =>
      ((subTotal - discount).clamp(0, double.infinity)) * taxPercent / 100.0;

  double get grandTotal =>
      (subTotal - discount + taxAmount).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _loadInvoiceCounter();
  }

  Future<void> _loadInvoiceCounter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _invoiceCounter = prefs.getInt('invoice_no') ?? 1);
  }

  Future<void> _saveCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('invoice_no', _invoiceCounter);
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _discountCtrl.dispose();
    _taxPctCtrl.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final q = int.tryParse(_qtyCtrl.text.trim());
    final r = double.tryParse(_rateCtrl.text.trim());
    if (q == null || r == null) return;

    setState(() {
      _items.add(PosItem(name: name, qty: q, rate: r));
      _nameCtrl.clear();
      _qtyCtrl.text = '1';
      _rateCtrl.clear();
    });
  }

  /// Save invoice & items to SQLite + print PDF
  Future<void> _printAndSave() async {
    if (_items.isEmpty) return;

    final now = DateTime.now();
    final datePart = DateFormat('yyyyMMdd').format(now);
    final invoiceNo =
        '$kInvoicePrefix$datePart-${_invoiceCounter.toString().padLeft(3, '0')}';

    final customerName = _customerNameCtrl.text.trim();
    final customerPhone = _customerPhoneCtrl.text.trim();

    // 1) Save to SQLite (schema unchanged – customer fields not stored yet)
    await BillingDb.instance.insertInvoiceWithLines(
        invoiceNo: invoiceNo,
        date: now,
        subTotal: subTotal,
        discount: discount,
        taxPercent: taxPercent,
        taxAmount: taxAmount,
        grandTotal: grandTotal,
        lines: [
          for (final it in _items)
            InvoiceLineInsert(
              name: it.name,
              qty: it.qty,
              rate: it.rate,
              amount: it.amount,
            ),
        ]);

    // 2) Build & print PDF
    final pdfBytes = await _buildPdf(
      invoiceNo: invoiceNo,
      date: now,
      items: _items,
      subTotal: subTotal,
      discount: discount,
      taxPercent: taxPercent,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      customerName: customerName,
      customerPhone: customerPhone,
    );

    final copies = kPrintTwoCopies ? 2 : 1;
    for (int i = 0; i < copies; i++) {
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    }

    // RESET after print
    setState(() {
      _invoiceCounter++;
      _items.clear();
      _nameCtrl.clear();
      _qtyCtrl.text = '1';
      _rateCtrl.clear();
      _discountCtrl.text = '0';
      _taxPctCtrl.text = '0';
      _customerNameCtrl.clear();
      _customerPhoneCtrl.clear();
    });
    await _saveCounter();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill printed & stored in local history.'),
        ),
      );
    }
  }

  /// Export full history from SQLite → Billing_Record.xlsx
  Future<void> _downloadHistoryExcel() async {
    final exported = await exportHistoryToExcel();
    if (!mounted) return;

    if (exported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Billing_Record.xlsx downloaded/exported.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records found to export.')),
      );
    }
  }

  Future<Uint8List> _buildPdf({
    required String invoiceNo,
    required DateTime date,
    required List<PosItem> items,
    required double subTotal,
    required double discount,
    required double taxPercent,
    required double taxAmount,
    required double grandTotal,
    required String customerName,
    required String customerPhone,
  }) async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy').format(date);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // HEADER
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      kShopName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (kShopAddress1.isNotEmpty) pw.Text(kShopAddress1),
                    if (kShopAddress2.isNotEmpty) pw.Text(kShopAddress2),
                    pw.Text('Phone: $kShopPhone'),
                    if (kShopEmail.isNotEmpty) pw.Text('Email: $kShopEmail'),
                    if (kShopWebsite.isNotEmpty && kShopWebsite != 'none')
                      pw.Text('Website: $kShopWebsite'),
                    if (kShopGst.isNotEmpty) pw.Text('GSTIN: $kShopGst'),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    _kvRight('Invoice No:', invoiceNo),
                    _kvRight('Date:', dateStr),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // BILLED TO (uses customer name + phone)
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILLED TO',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        customerName.isEmpty ? 'Cash Customer' : customerName,
                      ),
                      if (customerPhone.isNotEmpty) pw.Text(customerPhone),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'YOUR COMPANY',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(kShopName),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ITEMS TABLE
          pw.TableHelper.fromTextArray(
            headers: const ['DESCRIPTION', 'UNIT COST', 'QTY', 'AMOUNT'],
            data: [
              for (final it in items)
                [
                  it.name,
                  formatCurrency(it.rate),
                  it.qty.toString(),
                  formatCurrency(it.amount),
                ]
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE0E0E0),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2),
            },
          ),
          pw.SizedBox(height: 16),

          // SUMMARY + BANK DETAILS
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BANK ACCOUNT DETAILS',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (kBankAccountHolder.isNotEmpty)
                      pw.Text('Account holder: $kBankAccountHolder'),
                    if (kBankName.isNotEmpty) pw.Text('Bank name: $kBankName'),
                    if (kBankAccountNumber.isNotEmpty)
                      pw.Text('Account number: $kBankAccountNumber'),
                    if (kBankIfsc.isNotEmpty) pw.Text('IFSC code: $kBankIfsc'),
                    if (kUpiId.isNotEmpty) pw.Text('UPI ID: $kUpiId'),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _kv('SUBTOTAL', formatCurrency(subTotal)),
                    _kv('DISCOUNT', '- ${formatCurrency(discount)}'),
                    _kv('TAX RATE', '${taxPercent.toStringAsFixed(2)}%'),
                    _kv('TAX', formatCurrency(taxAmount)),
                    pw.Divider(),
                    _kv(
                      'INVOICE TOTAL',
                      formatCurrency(grandTotal),
                      bold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // DIGITAL SIGNATURE
          if (kIncludeDigitalSignature) ...[
            pw.Row(
              children: [
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('For $kShopName'),
                    pw.SizedBox(height: 32),
                    pw.Text(
                      'Authorised Signatory',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '(Digitally Signed)',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // FOOTER
          pw.Divider(),
          pw.SizedBox(height: 4),
          pw.Text(
            'TERMS',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
          pw.SizedBox(height: 4),
          if (kFooterLine1.isNotEmpty)
            pw.Text(kFooterLine1, style: const pw.TextStyle(fontSize: 9)),
          if (kFooterLine2.isNotEmpty)
            pw.Text(kFooterLine2, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _kv(String label, String value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  pw.Widget _kvRight(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF8EA394);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Power POS — Chrome'),
        backgroundColor: seed,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // LEFT: Item entry
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NEW: customer fields row
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _field(
                          'Customer Name',
                          _customerNameCtrl,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _field(
                          'Customer Phone',
                          _customerPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Item fields
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _field(
                        'Item',
                        _nameCtrl,
                        width: 260,
                        textInputAction: TextInputAction.next,
                      ),
                      _field(
                        'Qty',
                        _qtyCtrl,
                        width: 80,
                        keyboardType: TextInputType.number,
                      ),
                      _field(
                        'Rate',
                        _rateCtrl,
                        width: 120,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Card(
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, thickness: 0.5),
                        itemBuilder: (context, index) {
                          final it = _items[index];
                          return ListTile(
                            title: Text(
                              it.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Qty ${it.qty} × ${formatCurrency(it.rate)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(formatCurrency(it.amount)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    setState(() {
                                      _items.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
          // RIGHT: Summary
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _moneyRow('Subtotal', subTotal),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'Discount (₹)',
                          _discountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          'Tax %',
                          _taxPctCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _moneyRow('Tax Amount', taxAmount),
                  const Divider(height: 24),
                  _moneyRow('Grand Total', grandTotal, bold: true, big: true),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _items.isEmpty ? null : _printAndSave,
                    icon: const Icon(Icons.print),
                    label: const Text('Print Bill & Save (SQLite)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _downloadHistoryExcel,
                    icon: const Icon(Icons.download),
                    label: const Text('Download Excel History'),
                  ),
                  const SizedBox(height: 8),
                  if (kIsWeb)
                    const Text(
                      'Running in Chrome/Web mode.\n'
                      'History is stored in local SQLite; Excel is generated from it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    double? width,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onChanged,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: const Color(0xFFF4F6F4),
        ),
        onSubmitted: (_) {
          if (label == 'Rate') _addItem();
        },
      ),
    );
  }

  Widget _moneyRow(
    String label,
    double value, {
    bool bold = false,
    bool big = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: big ? 18 : 14,
            ),
          ),
        ),
        Text(
          formatCurrency(value),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: big ? 20 : 14,
          ),
        ),
      ],
    );
  }
}
