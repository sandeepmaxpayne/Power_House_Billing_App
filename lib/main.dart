import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:power_house_billing_app/screens/client_list_screen.dart';
import 'package:power_house_billing_app/screens/dashboard_screen.dart';
import 'package:power_house_billing_app/screens/invoice_edit_screen.dart';
import 'package:power_house_billing_app/screens/invoice_list_screen.dart';
import 'package:power_house_billing_app/screens/record_payment_screen.dart';
import 'package:power_house_billing_app/screens/settings_screen.dart';
import 'package:power_house_billing_app/screens/web_pos_screen.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Use FFI web factory (uses web worker + IndexedDB)
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Desktop – use FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    // Android / iOS – normal sqflite
    databaseFactory = sqflite.databaseFactory;
  }

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
        inputDecorationTheme: const InputDecorationTheme(
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
        // On web (Chrome) route root to POS screen, otherwise dashboard
        '/': (_) => kIsWeb ? const WebPosScreen() : const DashboardScreen(),
        '/invoices': (_) => const InvoiceListScreen(),
        '/invoice/new': (_) => const InvoiceEditScreen(),
        '/clients': (_) => const ClientListScreen(),
        '/record': (_) => const RecordPaymentScreen(),
        '/settings': (_) => const SettingsScreen(),

        // Explicit POS route if you ever want to open it from menus
        '/pos/web': (_) => const WebPosScreen(),
      },
    );
  }
}
