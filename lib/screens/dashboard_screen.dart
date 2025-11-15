
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        children: [
          Card(
            child: ListTile(
              title: const Text('Invoices'),
              subtitle: const Text('Create, view, export PDF'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/invoices'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Clients'),
              subtitle: const Text('Manage customers'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/clients'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/invoice/new'),
        icon: const Icon(Icons.add),
        label: const Text('New invoice'),
      ),
    );
  }
}
