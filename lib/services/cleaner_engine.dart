import 'dart:io';
import 'package:flutter_cleaner_app/services/scan_item.dart';

class CleanerEngine {
  final List<ScanItem> _results = [];
  final List<File> _discoveredFiles = [];

  List<ScanItem> get results => List.unmodifiable(_results);

  int get totalFiles => _results.fold<int>(0, (sum, item) => sum + item.files);
  int get totalBytes => _results.fold<int>(0, (sum, item) => sum + item.bytes);
  int get totalItems => _results.length;

  /// الحصول على مسارات الفحص المحددة يدوياً
  Future<List<Directory>> getScanDirectories() async {
    return [
      Directory("/storage/emulated/0/Download"),
      Directory("/storage/emulated/0/DCIM/.thumbnails"),
      Directory("/storage/emulated/0/Pictures"),
      Directory("/storage/emulated/0/Movies"),
      Directory("/storage/emulated/0/Android/media"),
      Directory("/storage/emulated/0/Android/data"),
    ];
  }

  Future<List<ScanItem>> scan({
    Function(String message)? onStatus,
    Function(double progress)? onProgress,
  }) async {
    _results.clear();
    _discoveredFiles.clear();

    try {
      onStatus?.call("Initializing Scan...");
      onProgress?.call(0.1);

      final directories = await getScanDirectories();
      
      int processed = 0;
      for (final dir in directories) {
        processed++;
        onStatus?.call("Scanning: ${dir.path.split('/').last}...");
        onProgress?.call(0.1 + (0.8 * (processed / directories.length)));

        if (!await dir.exists()) continue;

        int filesCount = 0;
        int bytesCount = 0;

        // الفحص التكراري للملفات
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              final len = await entity.length();
              filesCount++;
              bytesCount += len;
              _discoveredFiles.add(entity);
            } catch (_) {}
          }
        }

        if (filesCount > 0) {
          _results.add(
            ScanItem(
              id: dir.path.hashCode.toString(),
              title: dir.path.split('/').last,
              path: dir.path,
              files: filesCount,
              bytes: bytesCount,
              selected: true,
            ),
          );
        }
      }

      onProgress?.call(1.0);
      onStatus?.call("Scan Completed Successfully");
    } catch (e) {
      onStatus?.call("Scan interrupted: $e");
      onProgress?.call(1.0);
    }

    return results;
  }

  Future<int> clean({
    required List<ScanItem> selected,
    Function(String message)? onStatus,
  }) async {
    int deletedCount = 0;

    if (selected.isEmpty) return 0;

    onStatus?.call("Cleaning selected directories...");
    final selectedPaths = selected.map((s) => s.path).toList();

    for (File file in List<File>.from(_discoveredFiles)) {
      try {
        final filePath = file.path;
        final shouldDelete = selectedPaths.any((p) => filePath.startsWith(p));
        if (!shouldDelete) continue;

        if (await file.exists()) {
          await file.delete();
          deletedCount++;
        }
      } catch (e) {
        onStatus?.call("Failed to delete: ${file.path}");
      }
    }

    _discoveredFiles.removeWhere((f) => !f.existsSync());
    _results.removeWhere((r) => selectedPaths.any((p) => r.path == p || r.path.startsWith(p)));

    onStatus?.call("Optimization Complete.");
    return deletedCount;
  }
}
