/// ===============================================================
/// Project      : AI Cleaner
/// File         : lib/services/cleaner_engine.dart
/// Version      : 1.2.2
/// Last Updated : 2026-10-29
///
/// Purpose:
/// محرك فحص التخزين وتصنيف الملفات المرشحة للتنظيف،
/// مع التحقق من المسارات والعناصر قبل الحذف.
///
/// Safety Notes:
/// - نتائج الفحص مرشحات وليست ضمانًا بأن الملفات غير مهمة.
/// - لا يتم حذف الملفات إلا بعد اختيار مساراتها صراحةً.
/// - لا يحاول هذا المحرك مسح Android/data أو Android/obb.
/// - لم يُجرَ بناء Flutter أو flutter analyze لهذا الملف.
///
/// Dependencies:
/// - dart:io
/// - scan_item.dart
/// - cleanup_rules.dart
/// ===============================================================

import 'dart:io';

import 'cleanup_rules.dart';
import 'scan_item.dart';

class CleanerEngine {
  CleanerEngine({String storageRoot = CleanupRules.defaultStorageRoot})
      : _storageRoot = storageRoot;

  static const List<String> junkExtensions = CleanupRules.temporaryExtensions;

  final String _storageRoot;
  List<ScanItem> _results = <ScanItem>[];
  final Map<String, List<File>> _filesByCategory = <String, List<File>>{};

  int _totalFiles = 0;
  int _totalBytes = 0;
  int _lastDeletedBytes = 0;

  int get lastDeletedBytes => _lastDeletedBytes;
  int get totalFiles => _totalFiles;
  int get totalBytes => _totalBytes;
  int get totalItems => _results.length;

  int _imageFiles = 0;
  int _imageBytes = 0;
  int _videoFiles = 0;
  int _videoBytes = 0;
  int _otherFiles = 0;
  int _otherBytes = 0;
  static const int _largestFilesLimit = 50;

  /// أكبر الملفات التي أمكن قراءتها، مرتبة تنازليًا بالحجم.
  /// نحتفظ بأكبر [_largestFilesLimit] ملفًا فقط بدل تخزين كل مسار في الذاكرة.
  final List<MapEntry<String, int>> _largestFiles = <MapEntry<String, int>>[];

  List<MapEntry<String, int>> get largestAccessibleFiles =>
      List<MapEntry<String, int>>.unmodifiable(_largestFiles);

  void _trackLargestFile(String path, int bytes) {
    if (_largestFiles.length >= _largestFilesLimit &&
        bytes <= _largestFiles.last.value) {
      return;
    }

    int index = _largestFiles.length;
    while (index > 0 && _largestFiles[index - 1].value < bytes) {
      index--;
    }
    _largestFiles.insert(index, MapEntry<String, int>(path, bytes));

    if (_largestFiles.length > _largestFilesLimit) {
      _largestFiles.removeLast();
    }
  }

  static const Set<String> _imageExtensions = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
    '.heif',
    '.avif',
    '.tif',
    '.tiff',
  };

  static const Set<String> _videoExtensions = <String>{
    '.mp4',
    '.m4v',
    '.mov',
    '.3gp',
    '.mkv',
    '.webm',
    '.avi',
    '.mpeg',
    '.mpg',
  };

  List<ScanItem> get results => List<ScanItem>.unmodifiable(_results);
  int get imageFiles => _imageFiles;
  int get imageBytes => _imageBytes;
  int get videoFiles => _videoFiles;
  int get videoBytes => _videoBytes;
  int get otherFiles => _otherFiles;
  int get otherBytes => _otherBytes;

  List<File> filesForCategory(String categoryId) =>
      List<File>.unmodifiable(_filesByCategory[categoryId] ?? const <File>[]);

  List<Directory> getScanDirectories() => <Directory>[Directory(_storageRoot)];

  Future<List<ScanItem>> scan({
    Function(String)? onStatus,
    Function(double)? onProgress,
  }) async {
    _results = <ScanItem>[];
    _filesByCategory.clear();
    _totalFiles = 0;
    _totalBytes = 0;
    _imageFiles = 0;
    _imageBytes = 0;
    _videoFiles = 0;
    _videoBytes = 0;
    _otherFiles = 0;
    _otherBytes = 0;
    _largestFiles.clear();

    final Map<String, List<File>> groupedFiles = <String, List<File>>{
      'temporary_files': <File>[],
      'thumbnail_files': <File>[],
      'apk_files': <File>[],
    };
    final Map<String, int> groupedBytes = <String, int>{
      'temporary_files': 0,
      'thumbnail_files': 0,
      'apk_files': 0,
    };

    final Directory root = Directory(_storageRoot);
    if (!await root.exists()) {
      onStatus?.call('مجلد التخزين غير متاح.');
      onProgress?.call(1.0);
      return _results;
    }

    final List<Directory> queue = <Directory>[root];
    int visitedDirectories = 0;
    onStatus?.call('جارٍ فحص الملفات...');

    while (queue.isNotEmpty) {
      final Directory currentDirectory = queue.removeLast();
      if (!_isAllowedPath(currentDirectory.path)) continue;

      try {
        await for (final FileSystemEntity entity in currentDirectory.list(
          recursive: false,
          followLinks: false,
        )) {
          if (entity is Link) continue;

          if (entity is Directory) {
            if (_isAllowedPath(entity.path)) queue.add(entity);
            continue;
          }

          if (entity is! File || !_isAllowedPath(entity.path)) continue;

          int fileBytes;
          try {
            fileBytes = await entity.length();
          } on FileSystemException {
            continue;
          }

          _trackLargestFile(entity.path, fileBytes);
          final String fileName = entity.path.toLowerCase().split('/').last;
          final int dot = fileName.lastIndexOf('.');
          final String extension = dot >= 0 ? fileName.substring(dot) : '';

          if (_imageExtensions.contains(extension)) {
            _imageFiles++;
            _imageBytes += fileBytes;
          } else if (_videoExtensions.contains(extension)) {
            _videoFiles++;
            _videoBytes += fileBytes;
          } else {
            _otherFiles++;
            _otherBytes += fileBytes;
          }

          final String? categoryId = _classifyFile(entity.path);
          if (categoryId == null) continue;

          groupedFiles[categoryId]!.add(entity);
          groupedBytes[categoryId] = groupedBytes[categoryId]! + fileBytes;
          _totalFiles++;
          _totalBytes += fileBytes;
        }
      } on FileSystemException {
        // بعض المجلدات قد لا تكون قابلة للقراءة؛ لا ندعي اكتمال الفحص.
      }

      visitedDirectories++;
      final double progress =
          1.0 - (1.0 / (visitedDirectories + queue.length + 1));
      onProgress?.call(progress.clamp(0.0, 0.95));
    }

    onStatus?.call('جارٍ تجهيز نتائج الفحص...');
    _addCategory(
      id: 'temporary_files',
      title: 'الملفات المؤقتة',
      descriptionPath: 'category://temporary_files',
      files: groupedFiles['temporary_files']!,
      bytes: groupedBytes['temporary_files']!,
    );
    _addCategory(
      id: 'thumbnail_files',
      title: 'ملفات الصور المصغرة',
      descriptionPath: 'category://thumbnail_files',
      files: groupedFiles['thumbnail_files']!,
      bytes: groupedBytes['thumbnail_files']!,
    );
    _addCategory(
      id: 'apk_files',
      title: 'ملفات تثبيت التطبيقات (APK)',
      descriptionPath: 'category://apk_files',
      files: groupedFiles['apk_files']!,
      bytes: groupedBytes['apk_files']!,
      safeToDelete: false,
    );

    onProgress?.call(1.0);
    onStatus?.call('اكتمل الفحص.');
    return List<ScanItem>.unmodifiable(_results);
  }

  Future<int> clean({
    required List<ScanItem> selected,
    Function(String)? onStatus,
  }) async {
    _lastDeletedBytes = 0;
    if (selected.isEmpty) {
      onStatus?.call('لم يتم اختيار أي فئة للتنظيف.');
      return 0;
    }

    int deletedFiles = 0;
    final Set<String> processedPaths = <String>{};
    final Map<String, ScanItem> currentItems = <String, ScanItem>{
      for (final ScanItem item in _results) item.id: item,
    };

    onStatus?.call('جارٍ التحقق من الملفات المحددة...');
    for (final ScanItem requestedItem in selected) {
      final ScanItem? currentItem = currentItems[requestedItem.id];
      if (currentItem == null ||
          !requestedItem.selected ||
          requestedItem.selectedPaths.isEmpty ||
          !requestedItem.safeToDelete ||
          !currentItem.safeToDelete ||
          requestedItem.path != currentItem.path ||
          requestedItem.files != currentItem.files ||
          requestedItem.bytes != currentItem.bytes) {
        continue;
      }

      final List<File>? categoryFiles = _filesByCategory[currentItem.id];
      if (categoryFiles == null) continue;

      final Set<String> selectedPaths =
          requestedItem.selectedPaths.map(_normalizePath).toSet();

      for (final File file in categoryFiles) {
        final String normalizedPath = _normalizePath(file.path);
        if (!selectedPaths.contains(normalizedPath) ||
            !_isAllowedPath(normalizedPath) ||
            !processedPaths.add(normalizedPath)) {
          continue;
        }

        try {
          if (!await file.exists()) continue;
          final FileSystemEntityType entityType =
              await FileSystemEntity.type(file.path, followLinks: false);
          if (entityType != FileSystemEntityType.file) continue;

          // Use the same injected root as scanning and test environments.
          if (!_isAllowedPath(file.path) ||
              CleanupRules.classify(
                    file.path,
                    storageRoot: _storageRoot,
                  ) !=
                  currentItem.id) {
            continue;
          }

          final int bytesBeforeDelete = await file.length();
          await file.delete();
          deletedFiles++;
          _lastDeletedBytes += bytesBeforeDelete;
        } on FileSystemException {
          // تجاوز الملف المتعذر ومتابعة بقية الملفات.
        }
      }
    }

    // Results are stale after cleanup; the next operation must scan again.
    _results = <ScanItem>[];
    _filesByCategory.clear();
    onStatus?.call('انتهت عملية التنظيف.');
    return deletedFiles;
  }

  String? _classifyFile(String filePath) => CleanupRules.classify(
        _normalizePath(filePath),
        storageRoot: _storageRoot,
      );

  void _addCategory({
    required String id,
    required String title,
    required String descriptionPath,
    required List<File> files,
    required int bytes,
    bool safeToDelete = true,
  }) {
    if (files.isEmpty) return;
    _filesByCategory[id] = List<File>.unmodifiable(files);
    _results.add(
      ScanItem(
        id: id,
        title: title,
        path: descriptionPath,
        files: files.length,
        bytes: bytes,
        safeToDelete: safeToDelete,
        selected: false,
      ),
    );
  }

  bool _isAllowedPath(String path) => CleanupRules.isAllowedPath(
        _normalizePath(path),
        storageRoot: _storageRoot,
      );

  String _normalizePath(String path) {
    String normalized = path.replaceAll(String.fromCharCode(92), '/');
    while (normalized.contains('//')) {
      normalized = normalized.replaceAll('//', '/');
    }
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  int calculateHealthScore() {
    if (_totalFiles == 0) return 100;
    final int score = 100 - (_totalFiles ~/ 100);
    return score.clamp(0, 100);
  }

  static String formatBytes(int bytes) {
    if (bytes < 0) return 'غير معروف';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}