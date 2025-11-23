import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'models.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _loading = false;
  List<UserSummary> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get('/api/admin/users');
      if (res.statusCode != 200) throw Exception('Error: ${res.statusCode} ${res.body}');
      final List<dynamic> list = json.decode(res.body) as List<dynamic>;
      setState(() => _users = list.map((e) => UserSummary.fromJson(e)).toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load users: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteUser(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(title: const Text('Confirm'), content: const Text('Delete this user?'), actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ]),
    );
    if (ok != true) return;

    try {
      final res = await ApiClient.delete('/api/admin/users/$id');
      if (res.statusCode != 204) throw Exception('Delete failed: ${res.statusCode} ${res.body}');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e')));
    }
  }

  Future<void> _createUserDialog() async {
    final nameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final passCtl = TextEditingController();
    String role = 'User';

    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create User'),
        content: SingleChildScrollView(
          child: Column(children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: emailCtl, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passCtl, decoration: const InputDecoration(labelText: 'Password')),
            DropdownButtonFormField<String>(value: role, items: const [DropdownMenuItem(value: 'User', child: Text('User')), DropdownMenuItem(value: 'Admin', child: Text('Admin'))], onChanged: (v) => role = v ?? 'User'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            try {
              final body = {'name': nameCtl.text.trim(), 'email': emailCtl.text.trim(), 'role': role, 'password': passCtl.text.trim()};
              final r = await ApiClient.post('/api/admin/users', body);
              if (r.statusCode != 201) throw Exception('Create failed: ${r.statusCode} ${r.body}');
              Navigator.pop(context, true);
            } catch (e) {
              Navigator.pop(context, false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create error: $e')));
            }
          }, child: const Text('Create')),
        ],
      ),
    );

    if (res == true) _loadUsers();
  }

  Future<void> _editUserDialog(UserSummary user) async {
    final nameCtl = TextEditingController(text: user.name);
    final emailCtl = TextEditingController(text: user.email);
    String role = user.role;
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit User'),
        content: SingleChildScrollView(
          child: Column(children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: emailCtl, decoration: const InputDecoration(labelText: 'Email')),
            DropdownButtonFormField<String>(value: role, items: const [DropdownMenuItem(value: 'User', child: Text('User')), DropdownMenuItem(value: 'Admin', child: Text('Admin'))], onChanged: (v) => role = v ?? user.role),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            try {
              final body = {'name': nameCtl.text.trim(), 'email': emailCtl.text.trim(), 'role': role};
              final r = await ApiClient.put('/api/admin/users/${user.id}', body);
              if (r.statusCode != 200) throw Exception('Update failed: ${r.statusCode} ${r.body}');
              Navigator.pop(context, true);
            } catch (e) {
              Navigator.pop(context, false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update error: $e')));
            }
          }, child: const Text('Save')),
        ],
      ),
    );

    if (res == true) _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin - Users'), backgroundColor: Colors.indigo, actions: [IconButton(onPressed: _createUserDialog, icon: const Icon(Icons.add))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView.builder(
          itemCount: _users.length,
          itemBuilder: (_, i) {
            final u = _users[i];
            return ListTile(
              title: Text(u.name.isEmpty ? '(no name)' : u.name),
              subtitle: Text('${u.email} • ${u.role}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _editUserDialog(u)),
                IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteUser(u.id)),
              ]),
            );
          },
        ),
      ),
    );
  }
}
