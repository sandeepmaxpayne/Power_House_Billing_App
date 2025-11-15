import 'package:flutter/material.dart';
import 'package:power_house_billing_app/screens/client_list_screen.dart';
import 'package:power_house_billing_app/screens/dashboard_screen.dart';
import 'package:power_house_billing_app/screens/invoice_edit_screen.dart';
import 'package:power_house_billing_app/screens/invoice_list_screen.dart';
import 'package:power_house_billing_app/screens/record_payment_screen.dart';
import 'package:power_house_billing_app/screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InvoiceApp());
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF8EA394);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Invoico',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF4F6F4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFE1E6E2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFE1E6E2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: seed, width: 1.2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        listTileTheme: const ListTileThemeData(iconColor: Colors.black87),
      ),
      routes: {
        '/': (_) => const DashboardScreen(),
        '/invoices': (_) => const InvoiceListScreen(),
        '/invoice/new': (_) => const InvoiceEditScreen(),
        '/clients': (_) => const ClientListScreen(),
        '/record': (_) => const RecordPaymentScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
