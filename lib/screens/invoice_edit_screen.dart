import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/dao.dart';
import '../models/invoice.dart';

class InvoiceEditScreen extends StatefulWidget {
  final int? id;
  const InvoiceEditScreen({super.key, this.id});

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  final dao = Dao();
  final form = GlobalKey<FormState>();
  final numberCtrl = TextEditingController();
  final issueCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final dueCtrl = TextEditingController();
  final discountCtrl = TextEditingController(text: '0');
  final taxCtrl = TextEditingController(text: '18');
  int? clientId;
  List<InvoiceItem> items = [InvoiceItem(name: 'Service', qty: 1, rate: 1000)];

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load();
  }

  Future<void> _load() async {
    final inv = await dao.loadInvoice(widget.id!);
    setState(() {
      numberCtrl.text = inv.number;
      clientId = inv.clientId;
      issueCtrl.text = inv.issueDate;
      dueCtrl.text = inv.dueDate ?? '';
      discountCtrl.text = inv.discount.toString();
      taxCtrl.text = inv.taxPercent.toString();
      items = inv.items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.id == null ? 'New Invoice' : 'Edit Invoice')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _section('Details'),
            _inline([
              _text(numberCtrl, 'Invoice No', 'INV-2025-001',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null),
              _dateField(issueCtrl, 'Issue Date'),
              _dateField(dueCtrl, 'Due Date'),
            ]),
            _section('Client'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<int>(
                value: clientId,
                items: const [
                  DropdownMenuItem(
                      value: 1,
                      child: Text('Client #1 (add real list in Clients)')),
                ],
                onChanged: (v) => setState(() => clientId = v),
                decoration: const InputDecoration(labelText: 'Client'),
                validator: (v) => v == null ? 'Select client' : null,
              ),
            ),
            _section('Items'),
            Card(
                child: Column(children: [
              for (int i = 0; i < items.length; i++) _itemRow(i),
              TextButton.icon(
                  onPressed: () => setState(() => items
                      .add(InvoiceItem(name: 'New item', qty: 1, rate: 0))),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add item')),
            ])),
            _section('Summary'),
            Card(
                child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _kv('Subtotal', _subtotal().toStringAsFixed(2)),
                Row(children: [
                  Expanded(
                      child: _text(discountCtrl, 'Discount', '0',
                          keyboard: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _text(taxCtrl, 'Tax %', '18',
                          keyboard: TextInputType.number)),
                ]),
                const Divider(height: 24),
                _kv('Total', _total().toStringAsFixed(2), bold: true),
              ]),
            )),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'))),
          const SizedBox(width: 12),
          Expanded(
              child: FilledButton(onPressed: _save, child: const Text('Save'))),
        ]),
      ),
    );
  }

  double _subtotal() => items.fold(0, (s, e) => s + e.lineTotal);
  double _total() {
    final sub = _subtotal();
    final disc = double.tryParse(discountCtrl.text) ?? 0;
    final tax = double.tryParse(taxCtrl.text) ?? 0;
    return (sub - disc) * (1 + tax / 100);
  }

  Widget _itemRow(int i) {
    final it = items[i];
    return ListTile(
      title: TextFormField(
          initialValue: it.name,
          decoration: const InputDecoration(labelText: 'Item name'),
          onChanged: (v) => setState(() => it.name = v)),
      subtitle: Row(children: [
        Expanded(
            child: TextFormField(
                initialValue: it.qty.toString(),
                decoration: const InputDecoration(labelText: 'Qty'),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => it.qty = double.tryParse(v) ?? 1))),
        const SizedBox(width: 12),
        Expanded(
            child: TextFormField(
                initialValue: it.rate.toString(),
                decoration: const InputDecoration(labelText: 'Rate'),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => it.rate = double.tryParse(v) ?? 0))),
      ]),
      trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => setState(() => items.removeAt(i))),
    );
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    final inv = Invoice(
      id: widget.id,
      number: numberCtrl.text.trim(),
      clientId: clientId!,
      issueDate: issueCtrl.text.trim(),
      dueDate: dueCtrl.text.trim().isEmpty ? null : dueCtrl.text.trim(),
      discount: double.tryParse(discountCtrl.text) ?? 0,
      taxPercent: double.tryParse(taxCtrl.text) ?? 18,
      items: items,
    );
    if (inv.id == null) {
      await dao.createInvoice(inv);
    } else {
      await dao.updateInvoice(inv);
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _text(TextEditingController c, String label, String hint,
      {String? Function(String?)? validator, TextInputType? keyboard}) {
    return SizedBox(
      width: 360,
      child: TextFormField(
          controller: c,
          decoration: InputDecoration(labelText: label, hintText: hint),
          validator: validator,
          keyboardType: keyboard),
    );
  }

  Widget _dateField(TextEditingController c, String label) {
    return SizedBox(
      width: 220,
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        readOnly: true,
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
              initialDate: now);
          if (picked != null) c.text = DateFormat('yyyy-MM-dd').format(picked);
          setState(() {});
        },
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(t,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _inline(List<Widget> children) => Card(
      child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(spacing: 12, runSpacing: 8, children: children)));

  Widget _kv(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              )),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              ))
        ],
      ),
    );
  }
}
