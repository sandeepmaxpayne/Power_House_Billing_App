import '../models/client.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import 'app_db.dart';

class Dao {
  final dbFuture = AppDb.instance.database;

  // CLIENTS
  Future<List<Client>> getClients([String q = '']) async {
    final db = await dbFuture;
    final res = await db.query('clients',
        where: q.isEmpty ? null : 'name LIKE ? OR company LIKE ?',
        whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
        orderBy: 'name COLLATE NOCASE ASC');
    return res.map(Client.fromMap).toList();
  }

  Future<int> upsertClient(Client c) async {
    final db = await dbFuture;
    if (c.id == null) {
      return await db.insert('clients', c.toMap());
    } else {
      await db.update('clients', c.toMap(), where: 'id=?', whereArgs: [c.id]);
      return c.id!;
    }
  }

  Future<void> deleteClient(int id) async {
    final db = await dbFuture;
    await db.delete('clients', where: 'id=?', whereArgs: [id]);
  }

  // INVOICES
  Future<List<Map<String, Object?>>> listInvoicesWithClient() async {
    final db = await dbFuture;
    final res = await db.rawQuery('''
      SELECT invoices.*, clients.name AS client_name
      FROM invoices
      JOIN clients ON clients.id = invoices.client_id
      ORDER BY invoices.id DESC
    ''');
    return res;
  }

  Future<int> createInvoice(Invoice inv) async {
    final db = await dbFuture;
    final id = await db.insert('invoices', inv.toMap());
    for (final item in inv.items) {
      await db.insert('invoice_items', item.toMap(id));
    }
    return id;
  }

  Future<void> updateInvoice(Invoice inv) async {
    final db = await dbFuture;
    await db
        .update('invoices', inv.toMap(), where: 'id=?', whereArgs: [inv.id]);
    await db
        .delete('invoice_items', where: 'invoice_id=?', whereArgs: [inv.id]);
    for (final item in inv.items) {
      await db.insert('invoice_items', item.toMap(inv.id!));
    }
  }

  Future<void> deleteInvoice(int id) async {
    final db = await dbFuture;
    await db.delete('invoices', where: 'id=?', whereArgs: [id]);
  }

  Future<Invoice> loadInvoice(int id) async {
    final db = await dbFuture;
    final invMap =
        (await db.query('invoices', where: 'id=?', whereArgs: [id])).first;
    final items =
        await db.query('invoice_items', where: 'invoice_id=?', whereArgs: [id]);
    final inv = Invoice.fromMap(invMap);
    inv.items = items.map(InvoiceItem.fromMap).toList();
    return inv;
  }

  // PAYMENTS
  Future<void> addPayment(Payment p) async {
    final db = await dbFuture;
    await db.insert('payments', p.toMap());
  }

  Future<double> totalPaidForInvoice(int invoiceId) async {
    final db = await dbFuture;
    final res = await db.rawQuery(
        'SELECT SUM(amount) as s FROM payments WHERE invoice_id=?',
        [invoiceId]);
    final v = res.first['s'] as num?;
    return (v ?? 0).toDouble();
  }
}
