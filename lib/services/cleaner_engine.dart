import 'dart:io';
import 'package:flutter_cleaner_app/services/scan_item.dart';

class CleanerEngine {
  final List<ScanItem> _results = [];
  final List<File> _discoveredFiles = [];

  // قائمة امتدادات الملفات التي نعتبرها نفايات (يمكنك إضافة المزيد)
  final List<String> junkExtensions = [
    '.tmp', '.log', '.cache', '.bak', '.temp', '.trash'
  ];

  List<ScanItem> get results => List.unmodifiable(_results);

  int get totalFiles => _results.fold<int>(0, (sum, item) => sum + item.files);
  int get totalBytes => _results.fold<int>(0, (sum, item) => sum + item.bytes);
  int get totalItems => _results.length;

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
      onStatus?.call("Initializing Smart Scan...");
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

        // الفحص التكراري مع الفلترة الآمنة
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              final fileSize = await entity.length();
              final fileName = entity.path.toLowerCase();
              
              // الشروط التي تجعل الملف "نفايات" (Junk)
              final bool isThumbnail = entity.path.contains('/.thumbnails/');
              final bool isEmpty = fileSize == 0;
              final bool isJunkExt = junkExtensions.any((ext) => fileName.endsWith(ext));

              // الإضافة للقائمة تتم فقط إذا كان الملف ضمن شروط المهملات
              if (isThumbnail || isEmpty || isJunkExt) {
                filesCount++;
                bytesCount += fileSize;
                _discoveredFiles.add(entity);
              }
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

    onStatus?.call("Cleaning selected files...");
    final selectedPaths = selected.map((s) => s.path).toList();

    // نقوم بالحذف فقط للملفات التي تم التأكد أنها Junk
    for (File file in List<File>.from(_discoveredFiles)) {
      try {
        final filePath = file.path;
        
        // التحقق من أن هذا الملف يقع ضمن المجلد المختار للحذف
        final shouldDelete = selectedPaths.any((p) => filePath.startsWith(p));
        
        if (shouldDelete) {
          if (await file.exists()) {
            await file.delete();
            deletedCount++;
          }
        }
      } catch (e) {
        onStatus?.call("Failed to delete: ${file.path}");
      }
    }

    // تنظيف القوائم بعد الحذف
    _discoveredFiles.removeWhere((f) => !f.existsSync());
    _results.removeWhere((r) => selectedPaths.any((p) => r.path == p));

    onStatus?.call("Optimization Complete.");
    return deletedCount;
  }
}
