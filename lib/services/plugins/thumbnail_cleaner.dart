import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart';

class ThumbnailCleaner {
  final List<ScanItem> results = [];

  Future<List<ScanItem>> scan({Function(String message)? onProgress}) async {
    results.clear();
    onProgress?.call("Locating cache directories...");
    await Future.delayed(const Duration(milliseconds: 200));

    Future<void> collectDir(Directory dir, String id, String title) async {
      int filesCount = 0;
      int bytesCount = 0;
      if (await dir.exists()) {
        await for (final e in dir.list(recursive: true, followLinks: false)) {
          if (e is File) {
            try {
              filesCount++;
              bytesCount += await e.length();
            } catch (_) {}
          }
        }
      }
      if (filesCount > 0) {
        results.add(ScanItem(
          id: id,
          title: title,
          path: dir.path,
          files: filesCount,
          bytes: bytesCount,
          selected: true,
        ));
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      await collectDir(tempDir, "thumbnail_cache_temp", "Thumbnail Cache (temp)");

      try {
        final external = await getExternalCacheDirectories();
        if (external != null) {
          for (final d in external) {
            // استخدم اسم فريد لكل مجلد خارجي
            final id = "thumbnail_cache_ext_${p.basename(d.path)}";
            await collectDir(d, id, "Thumbnail Cache (external)");
          }
        }
      } catch (_) {
        // بعض المنصات لا تدعم external cache directories
      }

      onProgress?.call("Thumbnail scan complete.");
    } catch (e) {
      onProgress?.call("Thumbnail scan error: $e");
    }

    return results;
  }

  Future<int> clean(List<ScanItem> items, Function(String message)? onStatus) async {
    onStatus?.call("Purging thumbnail files...");
    int deleted = 0;
    final paths = items.map((i) => i.path).toList();

    for (final pth in paths) {
      final dir = Directory(pth);
      if (await dir.exists()) {
        try {
          await for (final e in dir.list(recursive: true, followLinks: false)) {
            if (e is File) {
              try {
                await e.delete();
                deleted++;
                onStatus?.call("Deleted: ${e.path}");
              } catch (e) {
                onStatus?.call("Failed delete: ${e.path}");
              }
            }
          }
        } catch (e) {
          onStatus?.call("Error cleaning $pth: $e");
        }
      }
    }

    onStatus?.call("Purge complete.");
    return deleted;
  }
}
