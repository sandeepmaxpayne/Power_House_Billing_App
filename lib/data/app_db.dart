
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  static final AppDb instance = AppDb._();
  AppDb._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'invoico.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, v) async {
        // company
        await db.execute('''
        CREATE TABLE company(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          contact_person TEXT,
          address TEXT,
          phone TEXT,
          email TEXT,
          gstin TEXT
        );
        ''');
        // clients
        await db.execute('''
        CREATE TABLE clients(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          company TEXT,
          email TEXT,
          phone TEXT,
          address TEXT
        );
        ''');
        // invoices
        await db.execute('''
        CREATE TABLE invoices(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          number TEXT NOT NULL UNIQUE,
          client_id INTEGER NOT NULL,
          issue_date TEXT NOT NULL,
          due_date TEXT,
          notes TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          discount REAL NOT NULL DEFAULT 0,
          tax_percent REAL NOT NULL DEFAULT 18,
          FOREIGN KEY(client_id) REFERENCES clients(id) ON DELETE RESTRICT
        );
        ''');
        // invoice items
        await db.execute('''
        CREATE TABLE invoice_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          qty REAL NOT NULL,
          rate REAL NOT NULL,
          FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
        );
        ''');
        // payments
        await db.execute('''
        CREATE TABLE payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          method TEXT,
          reference TEXT,
          FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
        );
        ''');

        // seed company row from user details
        await db.insert('company', {
          'name': 'Power Battery House',
          'contact_person': 'Vijay Kumar',
          'address': 'Birsanagar, Jamshedpur',
          'phone': '+91 98765 43210',
          'email': 'billing@tech2box.com',
          'gstin': '27ABCDE1234F1Z5',
        });
      },
    );
  }
}
