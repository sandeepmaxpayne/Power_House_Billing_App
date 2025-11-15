// lib/services/billing_excel_web.dart
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import 'billing_excel.dart';

const _sheetName = 'Records';

Future<void> logInvoiceToExcel({
  required String invoiceNumber,
  required String dateString,
  required List<ExcelInvoiceLine> lines,
  required double subTotal,
  required double discount,
  required double taxPercent,
  required double taxAmount,
  required double grandTotal,
}) async {
  // On web we can't truly append to an existing file on disk,
  // so we create a fresh workbook for this invoice and let user download it.
  final excel = xls.Excel.createExcel();
  excel.rename(excel.getDefaultSheet()!, _sheetName);

  final sh = excel[_sheetName];

  // Header
  sh.appendRow([
    xls.TextCellValue('Invoice No'),
    xls.TextCellValue('DateTime'),
    xls.TextCellValue('Item Name'),
    xls.TextCellValue('Qty'),
    xls.TextCellValue('Rate'),
    xls.TextCellValue('Amount'),
    xls.TextCellValue('Subtotal'),
    xls.TextCellValue('Discount'),
    xls.TextCellValue('Tax %'),
    xls.TextCellValue('Tax Amt'),
    xls.TextCellValue('Grand Total'),
  ]);

  // Rows
  for (final line in lines) {
    sh.appendRow([
      xls.TextCellValue(invoiceNumber),
      xls.TextCellValue(dateString),
      xls.TextCellValue(line.name),
      xls.IntCellValue(line.qty),
      xls.DoubleCellValue(line.rate),
      xls.DoubleCellValue(line.amount),
      xls.DoubleCellValue(subTotal),
      xls.DoubleCellValue(discount),
      xls.DoubleCellValue(taxPercent),
      xls.DoubleCellValue(taxAmount),
      xls.DoubleCellValue(grandTotal),
    ]);
  }

  final Uint8List bytes = Uint8List.fromList(excel.encode()!);

  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = 'Billing_Record.xlsx'
    ..style.display = 'none';

  html.document.body!.children.add(anchor);
  anchor.click();
  html.document.body!.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}
