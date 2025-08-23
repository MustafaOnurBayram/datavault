import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // '' = kök (private/<uid>)
  String _currentDir = '';
  Future<List<StorageEntry>>? _loader;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _loader = StorageService.listEntries(relativeDir: _currentDir);
    });
  }

  String _uiPath() => _currentDir.isEmpty ? '/' : '/$_currentDir';

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni klasör'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Klasör adı',
            hintText: 'ör. Projeler',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oluştur')),
        ],
      ),
    );

    if (ok != true) return;

    final name = controller.text.trim();
    if (name.isEmpty) return;

    try {
      await StorageService.createFolder(folderName: name, relativeDir: _currentDir);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Klasör oluşturuldu: $name')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Klasör oluşturma hatası: $e' : msg)),
      );
    }
  }

  Future<void> _pickAndUpload() async {
    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;

    final f = res.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dosya okunamadı')),
      );
      return;
    }

    await StorageService.uploadBytes(
      fileName: f.name,
      bytes: Uint8List.fromList(bytes),
      relativeDir: _currentDir, // aktif klasöre yükle
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Yüklendi: ${f.name}')),
    );
    _refresh();
  }

  Future<void> _download(StorageEntry e) async {
    try {
      await StorageService.downloadAndOpen(e.path);
    } catch (err) {
      if (!mounted) return;
      final msg = err.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'İndirme hatası: $err' : msg)),
      );
    }
  }

  Future<void> _saveToDevice(StorageEntry e) async {
    try {
      await StorageService.saveToDeviceDownloads(e.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dosyalarıma kaydedildi')),
      );
    } catch (err) {
      if (!mounted) return;
      final msg = err.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Kaydetme hatası: $err' : msg)),
      );
    }
  }

  Future<void> _share(StorageEntry e) async {
    try {
      final url = await StorageService.createSignedUrl(
        e.path,
        expiresIn: const Duration(hours: 1),
      );
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link kopyalandı (1 saat geçerli)')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link oluşturma hatası: $err')),
      );
    }
  }

  Future<void> _rename(StorageEntry e) async {
    final controller = TextEditingController(text: e.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeniden adlandır'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Yeni dosya adı',
            hintText: 'ör. rapor.pdf',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );

    if (ok != true) return;

    final newName = controller.text.trim();
    if (newName.isEmpty || newName == e.name) return;

    try {
      await StorageService.rename(storagePath: e.path, newFileName: newName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İsim güncellendi')));
      _refresh();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yeniden adlandırma hatası: $err')),
      );
    }
  }

  Future<void> _delete(StorageEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: Text('“${e.name}” kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;

    await StorageService.deleteFile(e.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silindi')));
    _refresh();
  }

  void _openFolder(StorageEntry folder) {
    final name = folder.name;
    setState(() {
      _currentDir = _currentDir.isEmpty ? name : '$_currentDir/$name';
    });
    _refresh();
  }

  bool get _canGoUp => _currentDir.isNotEmpty;

  void _goUp() {
    if (!_canGoUp) return;
    final parts = _currentDir.split('/')..removeLast();
    _currentDir = parts.join('/');
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: _canGoUp
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Üst klasöre çık',
          onPressed: _goUp,
        )
            : null,
        title: const Text('DataVault'),
        actions: [
          IconButton(
            tooltip: 'Yeni klasör',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _createFolder,
          ),
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.signOut();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndUpload,
        label: const Text('Yükle'),
        icon: const Icon(Icons.upload),
      ),
      body: Column(
        children: [
          // küçük breadcrumb
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant),
              ),
            ),
            child: Text(
              'Klasör: ${_uiPath()}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<StorageEntry>>(
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
                  return const Center(
                    child: Text('Bu klasörde içerik yok. “Yükle” veya “Yeni klasör” oluştur.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96, top: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = items[i];

                    // klasör görünümü
                    if (e.isFolder) {
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(e.name),
                        onTap: () => _openFolder(e),
                      );
                    }

                    // dosya görünümü
                    final date = e.createdAt?.toLocal();
                    final subtitleParts = <String>[
                      if (date != null)
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
                            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      StorageService.prettySize(e.size),
                    ].where((s) => s.isNotEmpty).toList();

                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(subtitleParts.join(' • ')),
                      onTap: () => _download(e),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'İşlemler',
                        onSelected: (value) {
                          switch (value) {
                            case 'download':
                              _download(e);
                              break;
                            case 'save':
                              _saveToDevice(e);
                              break;
                            case 'share':
                              _share(e);
                              break;
                            case 'rename':
                              _rename(e);
                              break;
                            case 'delete':
                              _delete(e);
                              break;
                          }
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(
                            value: 'download',
                            child: ListTile(
                              leading: Icon(Icons.download),
                              title: Text('İndir & Aç'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'save',
                            child: ListTile(
                              leading: Icon(Icons.save_alt),
                              title: Text('Dosyalarıma Kaydet'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: ListTile(
                              leading: Icon(Icons.link),
                              title: Text('Paylaş (link kopyala)'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'rename',
                            child: ListTile(
                              leading: Icon(Icons.drive_file_rename_outline),
                              title: Text('Yeniden adlandır'),
                            ),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Sil'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
