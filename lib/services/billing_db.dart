// lib/services/billing_db.dart
import 'dart:io' show File;

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class InvoiceLineInsert {
  final String name;
  final int qty;
  final double rate;
  final double amount;

  InvoiceLineInsert({
    required this.name,
    required this.qty,
    required this.rate,
    required this.amount,
  });
}

class BillingDb {
  BillingDb._();
  static final BillingDb instance = BillingDb._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    // NOTE: on web, databaseFactory should already be set in main()
    if (kIsWeb) {
      _db = await databaseFactory.openDatabase(
        'billing.db',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _onCreate,
        ),
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/billing.db';
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
      );
    }
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT,
        date TEXT,
        sub_total REAL,
        discount REAL,
        tax_percent REAL,
        tax_amount REAL,
        grand_total REAL
      );
    ''');

    await db.execute('''
      CREATE TABLE invoice_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER,
        name TEXT,
        qty INTEGER,
        rate REAL,
        amount REAL,
        FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      );
    ''');
  }

  Future<void> insertInvoiceWithLines({
    required String invoiceNo,
    required DateTime date,
    required double subTotal,
    required double discount,
    required double taxPercent,
    required double taxAmount,
    required double grandTotal,
    required List<InvoiceLineInsert> lines,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final invoiceId = await txn.insert('invoices', {
        'invoice_no': invoiceNo,
        'date': date.toIso8601String(),
        'sub_total': subTotal,
        'discount': discount,
        'tax_percent': taxPercent,
        'tax_amount': taxAmount,
        'grand_total': grandTotal,
      });

      for (final line in lines) {
        await txn.insert('invoice_lines', {
          'invoice_id': invoiceId,
          'name': line.name,
          'qty': line.qty,
          'rate': line.rate,
          'amount': line.amount,
        });
      }
    });
  }
}

/// Export entire history from SQLite into Billing_Record.xlsx
/// with merged cells per invoice (like your example screenshot)
Future<bool> exportHistoryToExcel() async {
  final db = await BillingDb.instance.database;

  final invoices = await db.query('invoices', orderBy: 'date ASC');
  if (invoices.isEmpty) return false;

  final excel = Excel.createExcel();
  final sheet = excel['History'];

  // Header row – uses CellValue types
  sheet.appendRow([
    TextCellValue('Invoice No'), // col 0
    TextCellValue('DateTime'), // col 1
    TextCellValue('Item Name'), // col 2
    TextCellValue('Qty'), // col 3
    TextCellValue('Rate'), // col 4
    TextCellValue('Amount'), // col 5
    TextCellValue('Subtotal'), // col 6
    TextCellValue('Discount'), // col 7
    TextCellValue('Tax %'), // col 8
    TextCellValue('Tax Amt'), // col 9
    TextCellValue('Grand Total'), // col 10
  ]);

  final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  // Row index tracking (0 = header)
  int rowIndex = 1;

  for (final inv in invoices) {
    final lines = await db.query(
      'invoice_lines',
      where: 'invoice_id = ?',
      whereArgs: [inv['id']],
    );
    if (lines.isEmpty) continue;

    final invoiceNo = inv['invoice_no'] as String;
    final dateStr =
        dateFmt.format(DateTime.parse(inv['date'] as String)); // ISO stored

    final subTotal = (inv['sub_total'] as num).toDouble();
    final discount = (inv['discount'] as num).toDouble();
    final taxPercent = (inv['tax_percent'] as num).toDouble();
    final taxAmount = (inv['tax_amount'] as num).toDouble();
    final grandTotal = (inv['grand_total'] as num).toDouble();

    // Remember where this invoice starts
    final startRow = rowIndex;

    for (final line in lines) {
      sheet.appendRow([
        TextCellValue(invoiceNo), // merged later
        TextCellValue(dateStr), // merged later
        TextCellValue(line['name'] as String),
        IntCellValue(line['qty'] as int),
        DoubleCellValue((line['rate'] as num).toDouble()),
        DoubleCellValue((line['amount'] as num).toDouble()),
        DoubleCellValue(subTotal), // merged later
        DoubleCellValue(discount), // merged later
        DoubleCellValue(taxPercent), // merged later
        DoubleCellValue(taxAmount), // merged later
        DoubleCellValue(grandTotal), // merged later
      ]);
      rowIndex++;
    }

    // End row for this invoice
    final endRow = rowIndex - 1;

    // If more than one line, merge appropriate columns vertically
    if (endRow > startRow) {
      void mergeCol(int col) {
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: startRow),
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: endRow),
        );
      }

      // Merge like your image:
      // Invoice No + Date + Subtotal + Discount + Tax% + Tax Amt + Grand Total
      mergeCol(0); // Invoice No
      mergeCol(1); // DateTime
      mergeCol(6); // Subtotal
      mergeCol(7); // Discount
      mergeCol(8); // Tax %
      mergeCol(9); // Tax Amt
      mergeCol(10); // Grand Total
    }
  }

  final bytes = excel.encode();
  final data = Uint8List.fromList(bytes!);

  const filename = 'Billing_Record';

  if (kIsWeb) {
    // Use saveFile (saveAs is not implemented on web)
    await FileSaver.instance.saveFile(
      name: filename,
      bytes: data,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  } else {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename.xlsx');
    await file.writeAsBytes(bytes, flush: true);
  }

  return true;
}
