// lib/services/billing_excel.dart

import 'dart:io' show File;

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ExcelInvoiceLine {
  String name;
  int qty;
  double rate;
  double amount;

  ExcelInvoiceLine({
    required this.name,
    required this.qty,
    required this.rate,
    required this.amount,
  });
}

Future<void> logInvoiceToExcel({
  required String invoiceNumber,
  required DateTime date,
  required List<ExcelInvoiceLine> lines,
  required double subTotal,
  required double discount,
  required double taxPercent,
  required double taxAmount,
  required double grandTotal,
}) async {
  const filename = "Billing_Record.xlsx";
  final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);

  Excel excel;
  Uint8List? fileBytes;

  // --- Load Existing File (Mobile + Windows Only) ---
  if (!kIsWeb) {
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$filename");

    if (await file.exists()) {
      fileBytes = Uint8List.fromList(await file.readAsBytes());
    }
  }

  // --- Decode if exists, else create ---
  excel =
      fileBytes != null ? Excel.decodeBytes(fileBytes) : Excel.createExcel();
  final sheet = excel["Records"];

  // --- Create Header Only Once ---
  if (sheet.rows.isEmpty) {
    sheet.appendRow([
      TextCellValue('Invoice No'),
      TextCellValue('DateTime'),
      TextCellValue('Item Name'),
      TextCellValue('Qty'),
      TextCellValue('Rate'),
      TextCellValue('Amount'),
      TextCellValue('Subtotal'),
      TextCellValue('Discount'),
      TextCellValue('Tax %'),
      TextCellValue('Tax Amt'),
      TextCellValue('Grand Total'),
    ]);
  }

  // --- Append rows ---
  for (final it in lines) {
    sheet.appendRow([
      TextCellValue(invoiceNumber),
      TextCellValue(dateStr),
      TextCellValue(it.name),
      IntCellValue(it.qty),
      DoubleCellValue(it.rate),
      DoubleCellValue(it.amount),
      DoubleCellValue(subTotal),
      DoubleCellValue(discount),
      DoubleCellValue(taxPercent),
      DoubleCellValue(taxAmount),
      DoubleCellValue(grandTotal),
    ]);
  }

  final outBytes = Uint8List.fromList(excel.encode()!);

  if (kIsWeb) {
    // ---- Download Excel File on Web ----
    await FileSaver.instance.saveFile(
      name: "Billing_Record",
      bytes: outBytes,
      fileExtension: "xlsx",
      mimeType: MimeType.microsoftExcel,
    );
  } else {
    // ---- Save Locally on Android / Windows ----
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$filename");
    await file.writeAsBytes(outBytes, flush: true);
  }
}
