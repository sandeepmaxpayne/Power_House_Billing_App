import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  final _itemNameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();

  final _discountCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');

  final List<PosItem> _items = [];

  int _invoiceCounter = 1;

  final _currencyFmt =
      NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');

  double get subTotal => _items.fold(0.0, (sum, item) => sum + item.amount);

  double get discount => double.tryParse(_discountCtrl.text.trim()) ?? 0;

  double get taxPct => double.tryParse(_taxCtrl.text.trim()) ?? 0;

  double get taxable => (subTotal - discount).clamp(0, double.infinity);

  double get taxAmount => taxable * taxPct / 100.0;

  double get grandTotal => (taxable + taxAmount).clamp(0, double.infinity);

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _itemNameCtrl.text.trim();
    if (name.isEmpty) return;

    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;

    if (qty <= 0 || rate <= 0) return;

    setState(() {
      _items.add(PosItem(name: name, qty: qty, rate: rate));
      _itemNameCtrl.clear();
      _qtyCtrl.text = '1';
      _rateCtrl.clear();
    });
  }

  Future<void> _printOrSavePdf() async {
    if (_items.isEmpty) return;

    final now = DateTime.now();
    final invoiceNo =
        '${DateFormat('yyyyMMdd').format(now)}-${_invoiceCounter.toString().padLeft(3, '0')}';

    final pdfBytes = await _buildPdf(
      invoiceNo: invoiceNo,
      dateTime: now,
      items: _items,
      subTotal: subTotal,
      discount: discount,
      taxPct: taxPct,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
    );

    // On web/Chrome: this will open browser's save/print dialog.
    // On other platforms: printing UI.
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
    );

    setState(() {
      _invoiceCounter++;
    });
  }

  Future<Uint8List> _buildPdf({
    required String invoiceNo,
    required DateTime dateTime,
    required List<PosItem> items,
    required double subTotal,
    required double discount,
    required double taxPct,
    required double taxAmount,
    required double grandTotal,
  }) async {
    final doc = pw.Document();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);

    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.all(20),
          pageFormat: PdfPageFormat.a4,
        ),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'Power Battery Zone',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Near Loyola Scholl'),
              pw.Text('Phone: 91234556670'),
              pw.Text('GST: 12334'),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice: $invoiceNo'),
                  pw.Text(dateStr),
                ],
              ),
              pw.Divider(),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Qty', 'Rate', 'Amount'],
            data: [
              for (final it in items)
                [
                  it.name,
                  it.qty.toString(),
                  _currencyFmt.format(it.rate),
                  _currencyFmt.format(it.amount),
                ]
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE0E0E0),
            ),
            border: null,
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.Container()),
              pw.Container(
                width: 220,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _kvRow('Subtotal', subTotal),
                    _kvRow('Discount', discount),
                    _kvRow('Tax (${taxPct.toStringAsFixed(2)}%)', taxAmount),
                    pw.Divider(),
                    _kvRow('Grand Total', grandTotal, bold: true),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Thank you for your purchase!',
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _kvRow(String key, double value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(key),
        pw.Text(
          _currencyFmt.format(value),
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Battery Zone — POS (Web/Chrome)'),
        centerTitle: false,
        actions: [
          if (kIsWeb)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  'Web Mode (Chrome)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: isWide ? 3 : 5,
              child: _buildItemsPanel(),
            ),
            if (isWide)
              Container(
                width: 1,
                color: Theme.of(context).dividerColor,
              ),
            Expanded(
              flex: isWide ? 2 : 5,
              child: _buildSummaryPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _itemNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _qtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _rateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rate (₹)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              FilledButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No items added yet',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
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
                            'Qty ${it.qty} × ${_currencyFmt.format(it.rate)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_currencyFmt.format(it.amount)),
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
    );
  }

  Widget _buildSummaryPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bill Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _summaryRow('Subtotal', subTotal),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Discount (₹)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _taxCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tax %',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _summaryRow('Tax Amount', taxAmount),
          const Divider(height: 24),
          _summaryRow(
            'Grand Total',
            grandTotal,
            bold: true,
            big: true,
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _items.isEmpty ? null : _printOrSavePdf,
            icon: const Icon(Icons.print),
            label: const Text('Print / Save PDF'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _items.isEmpty
                ? null
                : () {
                    // Clear current bill
                    setState(() {
                      _items.clear();
                      _discountCtrl.text = '0';
                      _taxCtrl.text = '0';
                    });
                  },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear Bill'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
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
          _currencyFmt.format(value),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: big ? 20 : 14,
          ),
        ),
      ],
    );
  }
}
