import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';

class StoredFile {
  final String name;
  final String path;       // storage path (private/<uid>/...)
  final int? size;
  final DateTime? createdAt;

  const StoredFile({
    required this.name,
    required this.path,
    this.size,
    this.createdAt,
  });
}

class StorageService {
  static final _client = Supabase.instance.client;
  static const _bucket = 'files';

  static String? get _uid => _client.auth.currentUser?.id;

  static String _ownerPrefix() {
    final id = _uid;
    if (id == null) throw Exception('Oturum yok');
    return 'private/$id';
  }

  static Future<void> uploadBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final prefix = _ownerPrefix();
    final path =
        '$prefix/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
  }

  static Future<List<StoredFile>> listMyFiles() async {
    final prefix = _ownerPrefix();

    final result = await _client.storage.from(_bucket).list(
      path: prefix,
      searchOptions: const SearchOptions(limit: 1000),
    );

    // createdAt bazı sürümlerde String olabiliyor; güvenli parse
    result.sort((a, b) {
      final ad = DateTime.tryParse(a.createdAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b.createdAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    return result.map((f) {
      final meta = f.metadata;
      int? size;
      final s = meta?['size'];
      if (s is int) {
        size = s;
      } else if (s is String) {
        size = int.tryParse(s);
      }
      final created =
      DateTime.tryParse(f.createdAt ?? ''); // String? -> DateTime?

      return StoredFile(
        name: f.name,
        path: '$prefix/${f.name}',
        size: size,
        createdAt: created,
      );
    }).toList();
  }

  static Future<void> deleteFile(String storagePath) async {
    await _client.storage.from(_bucket).remove([storagePath]);
  }

  static Future<void> downloadAndOpen(String storagePath) async {
    final bytes =
    await _client.storage.from(_bucket).download(storagePath);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${storagePath.split('/').last}');
    await file.writeAsBytes(bytes);
    await OpenFilex.open(file.path);
  }
}
