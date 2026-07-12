import 'dart:io';
import 'package:flutter_cleaner_app/services/scan_item.dart';

class CleanerEngine {
  final List<ScanItem> _results = [];
  final List<File> _discoveredFiles = [];

  static const List<String> junkExtensions = [
    '.tmp',
    '.temp',
    '.log',
    '.cache',
    '.bak',
    '.old',
    '.trash',
    '.dmp',
  ];

  List<ScanItem> get results => List.unmodifiable(_results);

  int get totalFiles =>
      _results.fold(0, (sum, item) => sum + item.files);

  int get totalBytes =>
      _results.fold(0, (sum, item) => sum + item.bytes);

  int get totalItems => _results.length;

  Future<List<Directory>> getScanDirectories() async {
    return [
      Directory("/storage/emulated/0"),
    ];
  }

  Future<List<ScanItem>> scan({
    Function(String message)? onStatus,
    Function(double progress)? onProgress,
  }) async {
    _results.clear();
    _discoveredFiles.clear();

    onStatus?.call("Initializing Smart Scan...");
    onProgress?.call(0.05);

    final roots = await getScanDirectories();

    int processed = 0;

    for (final root in roots) {
      if (!await root.exists()) continue;

      int files = 0;
      int bytes = 0;

      await for (final entity
          in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;

        try {
          final path = entity.path.toLowerCase();
          final size = await entity.length();

          final bool isThumbnail =
              path.contains("/.thumbnails/") ||
              path.contains("/thumbnails/") ||
              path.contains("/thumbnail/") ||
              path.endsWith(".thumb") ||
              path.endsWith(".thumbnail");

          final bool isEmpty = size == 0;

          final bool isJunk =
              junkExtensions.any((e) => path.endsWith(e));

          if (!(isThumbnail || isEmpty || isJunk)) {
            continue;
          }

          _discoveredFiles.add(entity);

          files++;
          bytes += size;
        } catch (_) {}

        processed++;

        if (processed % 250 == 0) {
          onProgress?.call(0.05 + (processed % 9000) / 9000);
        }
      }

      if (files > 0) {
        _results.add(
          ScanItem(
            id: root.path.hashCode.toString(),
            title: "Junk Files",
            path: root.path,
            files: files,
            bytes: bytes,
            selected: true,
          ),
        );
      }
    }

    onProgress?.call(1);
    onStatus?.call("Scan Completed");

    return results;
  }

  Future<int> clean({
    required List<ScanItem> selected,
    Function(String message)? onStatus,
  }) async {
    int deleted = 0;

    if (selected.isEmpty) {
      return 0;
    }

    onStatus?.call("Deleting junk files...");
        final selectedPaths = selected
        .map((e) => e.path)
        .toList();

    for (final file in List<File>.from(_discoveredFiles)) {
      try {
        final path = file.path;

        final shouldDelete = selectedPaths.any(
          (p) => path.startsWith(p),
        );

        if (!shouldDelete) {
          continue;
        }

        if (await file.exists()) {
          await file.delete();

          deleted++;

          if (deleted % 100 == 0) {
            onStatus?.call(
              "Deleted $deleted files...",
            );
          }
        }
      } catch (_) {}
    }

    _discoveredFiles.removeWhere(
      (f) => !f.existsSync(),
    );

    _results.clear();

    onStatus?.call(
      "Optimization Complete",
    );

    return deleted;
  }

  int calculateHealthScore() {
    if (_results.isEmpty) {
      return 100;
    }

    final score =
        100 - (totalFiles ~/ 20);

    if (score < 60) {
      return 60;
    }

    return score;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) {
      return "$bytes B";
    }

    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }

    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / 1024 / 1024).toStringAsFixed(2)} MB";
    }

    return "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }
}
