import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice.dart';

class PdfService {
  final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  Future<Uint8List> build(Invoice inv,
      {String? companyName,
      String? companyAddress,
      String? phone,
      String? email,
      String? gstin,
      String? contact}) async {
    final pdf = pw.Document();
    final items = inv.items;

    pw.Widget row(String a, String b) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
                width: 110,
                child: pw.Text(a,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text(b)),
          ],
        );

    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(companyName ?? 'Invoico',
                        style: pw.TextStyle(
                            fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    if (contact != null) pw.Text('Attn: $contact'),
                    if (companyAddress != null) pw.Text(companyAddress),
                    if (phone != null) pw.Text(phone),
                    if (email != null) pw.Text(email),
                    if (gstin != null) pw.Text('GSTIN: $gstin'),
                  ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(
                            fontSize: 26, fontWeight: pw.FontWeight.bold)),
                    pw.Text('No: ${inv.number}'),
                    pw.Text('Issue: ${inv.issueDate}'),
                    if (inv.dueDate != null) pw.Text('Due: ${inv.dueDate}'),
                  ])
            ],
          ),
          pw.SizedBox(height: 16),
          row('Bill To', 'Client #${inv.clientId}'),
          if (inv.notes != null) row('Notes', inv.notes!),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Qty', 'Rate', 'Amount'],
            data: [
              for (final it in items)
                [
                  it.name,
                  it.qty.toStringAsFixed(2),
                  _fmt.format(it.rate),
                  _fmt.format(it.lineTotal)
                ]
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFEFEF)),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 220,
                child: pw.Column(children: [
                  _kv('Subtotal', _fmt.format(inv.subTotal)),
                  _kv('Discount', _fmt.format(inv.discount)),
                  _kv(
                      'Tax (${inv.taxPercent.toStringAsFixed(0)}%)',
                      _fmt.format((inv.subTotal - inv.discount) *
                          inv.taxPercent /
                          100)),
                  pw.Divider(),
                  _kv('TOTAL', _fmt.format(inv.total), bold: true),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('Thank you for your business!'),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _kv(String k, String v, {bool bold = false}) {
    return pw
        .Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(k,
          style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      pw.Text(v,
          style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ]);
  }
}
