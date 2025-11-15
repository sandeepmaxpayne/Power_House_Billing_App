
import 'package:flutter/material.dart';

class RecordPaymentScreen extends StatelessWidget {
  const RecordPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: const Center(child: Text('Record payment UI (wire-up to Dao.addPayment)')),
    );
  }
}
