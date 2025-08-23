import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_saver/file_saver.dart';

/// Listeleme için hem klasör hem dosyayı temsil eden entry
class StorageEntry {
  final String name;         // görünen ad (dosya adı ya da klasör adı)
  final String path;         // tam storage path'i (private/<uid>/...[/name])
  final bool isFolder;       // klasör mü?
  final int? size;           // dosya ise boyut
  final DateTime? createdAt; // dosya ise tarih

  const StorageEntry({
    required this.name,
    required this.path,
    required this.isFolder,
    this.size,
    this.createdAt,
  });
}

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

  /// Mevcut klasöre göre tam path üretir (relativeDir '' olabilir)
  static String _fullPathFor({String relativeDir = ''}) {
    final base = _ownerPrefix();
    if (relativeDir.trim().isEmpty) return base;
    // gereksiz / temizle
    final r = relativeDir.replaceAll(RegExp(r'^/+|/+$'), '');
    return '$base/$r';
  }

  /// Klasör oluştur (placeholder .keep dosyası ile)
  static Future<void> createFolder({
    required String folderName,
    String relativeDir = '',
  }) async {
    final safe = folderName.trim();
    if (safe.isEmpty) {
      throw Exception('Klasör adı boş olamaz.');
    }
    if (safe.contains('/')) {
      throw Exception('Klasör adında "/" olamaz.');
    }

    final parent = _fullPathFor(relativeDir: relativeDir);
    final keepPath = '$parent/$safe/.keep';

    // boş içerik ile .keep yükle (varsa üzerine yazma)
    await _client.storage.from(_bucket).uploadBinary(
      keepPath,
      Uint8List(0),
      fileOptions: const FileOptions(upsert: false),
    );
  }

  static Future<void> uploadBytes({
    required String fileName,
    required Uint8List bytes,
    String relativeDir = '', // aktif klasör
  }) async {
    final parent = _fullPathFor(relativeDir: relativeDir);
    final path = '$parent/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
  }

  /// Geçerli klasördeki entry’leri döndür (klasörler + dosyalar)
  static Future<List<StorageEntry>> listEntries({
    String relativeDir = '',
  }) async {
    final parent = _fullPathFor(relativeDir: relativeDir);

    final result = await _client.storage.from(_bucket).list(
      path: parent,
      searchOptions: const SearchOptions(limit: 1000),
    );

    // Supabase Storage 'list' bir seviyeyi döndürür:
    // - klasörler için metadata null olur (çoğunlukla)
    // - dosyalar için metadata(size/mimetype) dolar
    // Ayrıca klasör içinde durması için .keep koyduk; onu gizleyeceğiz.

    final entries = <StorageEntry>[];

    for (final f in result) {
      final isHidden = f.name.startsWith('.'); // .keep gibi
      final isFolder = f.metadata == null;     // klasör heuristiği

      if (!isFolder && isHidden) {
        // .keep vb. gizli dosyaları göstermeyelim
        continue;
      }

      int? size;
      final s = f.metadata?['size'];
      if (s is int) {
        size = s;
      } else if (s is String) {
        size = int.tryParse(s);
      }
      final created = DateTime.tryParse(f.createdAt ?? '');

      entries.add(StorageEntry(
        name: f.name,
        path: '$parent/${f.name}',
        isFolder: isFolder,
        size: size,
        createdAt: created,
      ));
    }

    // klasörler üstte, sonra dosyalar; ada göre
    entries.sort((a, b) {
      if (a.isFolder != b.isFolder) {
        return a.isFolder ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return entries;
  }

  static Future<void> deleteFile(String storagePath) async {
    await _client.storage.from(_bucket).remove([storagePath]);
  }

  /// Cihazın geçici klasörüne indir ve aç (Android/iOS/desktop).
  static Future<void> downloadAndOpen(String storagePath) async {
    final bytes = await _client.storage.from(_bucket).download(storagePath);

    final dir = await getTemporaryDirectory();
    final fileName = storagePath.split('/').last;
    final localPath = '${dir.path}/$fileName';
    final file = File(localPath);
    await file.writeAsBytes(bytes);

    final result = await OpenFilex.open(localPath);

    if (result.type != ResultType.done) {
      throw Exception(
        'Dosya indirildi ama açmak için uygun bir uygulama bulunamadı. '
            'Lütfen bu dosya türünü açabilen bir uygulama yükleyin.',
      );
    }
  }

  /// Android: "Downloads" klasörüne kaydeder. iOS: Files/Paylaş sheet.
  static Future<void> saveToDeviceDownloads(String storagePath) async {
    final bytes = await _client.storage.from(_bucket).download(storagePath);
    final fileName = storagePath.split('/').last;

    final ext = _extOf(fileName); // ör. 'pdf', 'png', 'zip'
    final effectiveExt = ext.isEmpty ? 'bin' : ext;
    final mime = _mimeOf(effectiveExt);

    await FileSaver.instance.saveFile(
      name: _baseName(fileName, ext),
      bytes: Uint8List.fromList(bytes),
      ext: effectiveExt,
      mimeType: mime,
    );
  }

  /// Private bucket’ta zaman sınırlı paylaşılabilir link
  static Future<String> createSignedUrl(
      String storagePath, {
        Duration expiresIn = const Duration(hours: 1),
      }) async {
    final url = await _client.storage
        .from(_bucket)
        .createSignedUrl(storagePath, expiresIn.inSeconds);
    return url;
  }

  /// Dosya yeniden adlandır (aynı klasör içinde move)
  static Future<void> rename({
    required String storagePath,
    required String newFileName,
  }) async {
    final parts = storagePath.split('/')..removeLast();
    final parent = parts.join('/');

    String sanitized = newFileName.trim();
    if (sanitized.isEmpty) {
      throw Exception('Yeni isim boş olamaz');
    }

    String targetPath = '$parent/$sanitized';

    if (storagePath == targetPath) return;
    final exists = await _exists(targetPath);
    if (exists) {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final dot = sanitized.lastIndexOf('.');
      if (dot > 0) {
        final base = sanitized.substring(0, dot);
        final ext = sanitized.substring(dot);
        sanitized = '${base}_$ts$ext';
      } else {
        sanitized = '${sanitized}_$ts';
      }
      targetPath = '$parent/$sanitized';
    }

    await _client.storage.from(_bucket).move(storagePath, targetPath);
  }

  static Future<bool> _exists(String storagePath) async {
    final parts = storagePath.split('/');
    final name = parts.removeLast();
    final listPath = parts.join('/');

    final items = await _client.storage
        .from(_bucket)
        .list(path: listPath, searchOptions: const SearchOptions(limit: 1000));
    return items.any((e) => e.name == name);
  }

  static String prettySize(int? bytes) {
    if (bytes == null) return '';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${units[i]}';
  }

  // ---- yardımcılar ----
  static String _extOf(String fileName) {
    final i = fileName.lastIndexOf('.');
    if (i <= 0 || i == fileName.length - 1) return '';
    return fileName.substring(i + 1).toLowerCase();
  }

  static String _baseName(String fileName, String ext) {
    if (ext.isEmpty) return fileName;
    return fileName.substring(0, fileName.length - ext.length - 1);
  }

  static MimeType _mimeOf(String ext) {
    switch (ext) {
      case 'png':
        return MimeType.png;
      case 'jpg':
      case 'jpeg':
        return MimeType.jpeg;
      case 'gif':
        return MimeType.gif;
      case 'pdf':
        return MimeType.pdf;
      case 'txt':
        return MimeType.text;
      case 'csv':
        return MimeType.csv;
      case 'zip':
        return MimeType.zip;
      default:
        return MimeType.other;
    }
  }
}
