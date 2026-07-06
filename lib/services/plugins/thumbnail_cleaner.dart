import 'dart:io';

import '../models/scan_item.dart';
import '../models/scan_item.dart';

class ThumbnailCleaner {
  Future<List<ScanItem>> scan({
    Function(String message)? onProgress,
  }) async {
    final List<ScanItem> results = [];

    final root = Directory('/storage/emulated/0/');

    await _scanDirectory(
      root,
      results,
      onProgress,
    );

    return results;
  }

  Future<void> _scanDirectory(
    Directory directory,
    List<ScanItem> results,
    Function(String message)? onProgress,
  ) async {
    try {
      await for (final entity in directory.list()) {
        if (entity is Directory) {
          onProgress?.call(entity.path);

          if (entity.path.toLowerCase().contains("thumbnails")) {
            int totalFiles = 0;
            int totalBytes = 0;

            await for (final file in entity.list()) {
              if (file is File) {
                try {
                  totalFiles++;
                  totalBytes += await file.length();
                } catch (_) {}
              }
            }

            if (totalFiles > 0) {
              results.add(
                ScanItem(
                  id: entity.path.hashCode.toString(),
                  title: "Thumbnail Cache",
                  path: entity.path,
                  files: totalFiles,
                  bytes: totalBytes,
                ),
              );
            }
          } else {
            await _scanDirectory(
              entity,
              results,
              onProgress,
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<int> clean(
    List<ScanItem> items,
    Function(String message)? onProgress,
  ) async {
    int deleted = 0;

    for (final item in items) {
      final dir = Directory(item.path);

      if (!await dir.exists()) continue;

      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            await entity.delete();

            deleted++;

            onProgress?.call(entity.path);
          } catch (_) {}
        }
      }
    }

    return deleted;
  }
}
