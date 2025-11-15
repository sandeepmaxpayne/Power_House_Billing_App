// lib/services/billing_excel_io.dart
import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';

import 'billing_excel.dart';

const _excelFileName = 'Billing_Record.xlsx';
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
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$_excelFileName');

  xls.Excel excel;

  if (await file.exists()) {
    final bytes = await file.readAsBytes();
    excel = xls.Excel.decodeBytes(bytes);
  } else {
    excel = xls.Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, _sheetName);

    final sh = excel[_sheetName];
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
  }

  final sh = excel[_sheetName];

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

  final encoded = excel.encode()!;
  await file.writeAsBytes(encoded, flush: true);
}
