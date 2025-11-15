// lib/screens/web_pos_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/billing_excel.dart';

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
    setState(() => _invoiceCounter = prefs.getInt("invoice_no") ?? 1);
  }

  Future<void> _saveCounter() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("invoice_no", _invoiceCounter);
  }

  @override
  void dispose() {
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

  Future<void> _printAndSave() async {
    if (_items.isEmpty) return;

    final now = DateTime.now();
    final invoiceNo = DateFormat('yyyyMMdd').format(now) +
        '-${_invoiceCounter.toString().padLeft(3, '0')}';

    // --- SAVE TO EXCEL (Web / Android / Windows) ---
    await logInvoiceToExcel(
      invoiceNumber: invoiceNo,
      date: now,
      lines: [
        for (final it in _items)
          ExcelInvoiceLine(
            name: it.name,
            qty: it.qty,
            rate: it.rate,
            amount: it.amount,
          )
      ],
      subTotal: subTotal,
      discount: discount,
      taxPercent: taxPercent,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
    );

    // --- GENERATE PDF & PRINT ---
    final pdfBytes = await _buildPdf(
      invoiceNo: invoiceNo,
      date: now,
      items: _items,
      subTotal: subTotal,
      discount: discount,
      taxPercent: taxPercent,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
    );

    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);

    setState(() {
      _invoiceCounter++;
      _items.clear(); // reset bill after printing
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill printed & Billing_Record.xlsx saved.'),
        ),
      );
    }
    _saveCounter();
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
  }) async {
    final doc = pw.Document();
    final currency = NumberFormat.currency(symbol: "₹", decimalDigits: 2);

    doc.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("INVOICE",
                  style: pw.TextStyle(
                      fontSize: 32, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text("Power Battery Zone"),
              pw.Text("Near Loyola School"),
              pw.Text("Phone: 91234556670"),
              pw.SizedBox(height: 18),
              pw.Text("Invoice Number: $invoiceNo"),
              pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(date)}"),
              pw.Divider(height: 30),
              pw.TableHelper.fromTextArray(
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
                headers: ["Description", "Qty", "Rate", "Amount"],
                data: [
                  for (var it in items)
                    [
                      it.name,
                      it.qty.toString(),
                      currency.format(it.rate),
                      currency.format(it.amount)
                    ],
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(children: [
                    _pdfRow("Subtotal", currency.format(subTotal)),
                    _pdfRow("Discount", currency.format(discount)),
                    _pdfRow("Tax (${taxPercent.toStringAsFixed(2)}%)",
                        currency.format(taxAmount)),
                    pw.Divider(),
                    _pdfRow("Grand Total", currency.format(grandTotal),
                        bold: true),
                  ]),
                )
              ]),
              pw.SizedBox(height: 20),
              pw.Center(
                  child: pw.Text("Thank you for your purchase!",
                      style: pw.TextStyle(fontSize: 14))),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label),
        pw.Text(value,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }

  pw.Widget _kv(String label, String value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF8EA394);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Power POS — Chrome'),
        backgroundColor: seed,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            decimal: true),
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
                              'Qty ${it.qty} × ₹${it.rate.toStringAsFixed(2)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹${it.amount.toStringAsFixed(2)}'),
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
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
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
                              decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          'Tax %',
                          _taxPctCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
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
                    label: const Text('Print Bill & Save Excel'),
                  ),
                  const SizedBox(height: 8),
                  if (kIsWeb)
                    const Text(
                      'Running in Chrome/Web mode.\n'
                      'Each bill will download Billing_Record.xlsx.',
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
        ),
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
          '₹${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: big ? 20 : 14,
          ),
        ),
      ],
    );
  }
}
