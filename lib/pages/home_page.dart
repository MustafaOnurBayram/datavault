import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<List<StoredFile>>? _loader;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _loader = StorageService.listMyFiles();
    });
  }

  Future<void> _pickAndUpload() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;

    final f = res.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dosya okunamadı')),
      );
      return;
    }

    await StorageService.uploadBytes(
      fileName: f.name,
      bytes: Uint8List.fromList(bytes),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yüklendi: ${f.name}')),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DataVault'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.signOut();
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndUpload,
        label: const Text('Upload'),
        icon: const Icon(Icons.upload),
      ),
      body: FutureBuilder<List<StoredFile>>(
        future: _loader,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Hata: ${snap.error}'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('Hiç dosya yok. Upload ile ekle.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96, top: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final f = items[i];
              return ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(f.name),
                subtitle: Text(f.createdAt?.toLocal().toString() ?? ''),
                onTap: () => StorageService.downloadAndOpen(f.path),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await StorageService.deleteFile(f.path);
                    _refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
