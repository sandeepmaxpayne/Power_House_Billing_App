import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../data/dao.dart';
import '../models/invoice.dart';
import '../services/pdf_service.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final int invoiceId;
  const InvoicePreviewScreen({super.key, required this.invoiceId});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  final dao = Dao();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Invoice>(
      future: dao.loadInvoice(widget.invoiceId),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        final inv = snap.data!;
        return Scaffold(
          appBar: AppBar(title: Text('Invoice ${inv.number}')),
          body: PdfPreview(
            canChangePageFormat: false,
            canChangeOrientation: false,
            build: (format) => PdfService().build(
              inv,
              companyName: 'Power Battery House',
              contact: 'Vijay Kumar',
              companyAddress: 'Birsanagar, Jamshedpur',
              phone: '+91 98765 43210',
              email: 'billing@tech2box.com',
              gstin: '27ABCDE1234F1Z5',
            ),
          ),
        );
      },
    );
  }
}
