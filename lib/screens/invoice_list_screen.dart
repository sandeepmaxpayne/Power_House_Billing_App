import 'package:flutter/material.dart';

import '../data/dao.dart';
import 'invoice_edit_screen.dart';
import 'invoice_preview_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final dao = Dao();
  List<Map<String, Object?>> rows = [];

  Future<void> _load() async {
    rows = await dao.listInvoicesWithClient();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final r = rows[i];
          final id = r['id'] as int;
          final num = r['number'] as String;
          final client =
              (r['client_name'] ?? 'Client #${r['client_id']}') as String;
          final status = r['status'] as String;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(num.substring(num.length - 2))),
              title: Text(num),
              subtitle: Text(client),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _statusChip(status),
                IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: () async {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  InvoicePreviewScreen(invoiceId: id)));
                    }),
              ]),
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => InvoiceEditScreen(id: id)));
                _load();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InvoiceEditScreen()));
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _statusChip(String s) {
    Color c = Colors.orange;
    if (s == 'paid') c = Colors.green;
    if (s == 'overdue') c = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(.15), borderRadius: BorderRadius.circular(999)),
      child: Text(s, style: TextStyle(color: c, fontWeight: FontWeight.w700)),
    );
  }
}
