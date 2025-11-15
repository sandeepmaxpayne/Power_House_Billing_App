import 'package:flutter/material.dart';

import '../data/dao.dart';
import '../models/client.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final dao = Dao();
  String q = '';
  List<Client> clients = [];

  final nameCtrl = TextEditingController();

  Future<void> _load() async {
    clients = await dao.getClients(q);
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
      appBar: AppBar(title: const Text('Clients')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Search'),
              onChanged: (v) {
                q = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: clients.length,
              itemBuilder: (_, i) {
                final c = clients[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                    title: Text(c.name),
                    subtitle: Text((c.company ?? '')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await dao.deleteClient(c.id!);
                        _load();
                      },
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    nameCtrl.clear();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('New client'),
            content: TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save')),
            ],
          );
        });
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await dao.upsertClient(Client(name: nameCtrl.text.trim()));
      _load();
    }
  }
}
