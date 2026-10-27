
/// ===============================================================
/// Project      : AI Cleaner
/// File         : lib/services/cleaner_engine.dart
/// Version      : 1.2.1
/// Last Updated : 2026-10-10
///
/// Purpose:
/// محرك فحص التخزين وتصنيف الملفات المرشحة للتنظيف،
/// مع التحقق من المسارات والعناصر قبل الحذف.
///
/// Changelog:
/// - تصحيح استيراد ScanItem إلى المسار الصحيح.
/// - منع معالجة العناصر غير الموجودة في نتائج الفحص الحالي.
/// - التحقق من اختيار العنصر وصلاحيته قبل الحذف.
/// - استبعاد Android/data و Android/obb.
/// - جعل العناصر غير محددة افتراضيًا.
/// - تحسين التعامل مع أخطاء الوصول إلى الملفات.
///
/// Safety Notes:
/// - نتائج الفحص مرشحات وليست ضمانًا بأن الملفات غير مهمة.
/// - لا يتم حذف الملفات إلا بعد اختيار فئتها صراحةً.
/// - لا يحاول هذا المحرك مسح البيانات الخاصة بالتطبيقات الأخرى.
/// - يتطلب الوصول إلى التخزين الأذونات المناسبة على Android.
///
/// Compatibility:
/// - يعتمد على lib/services/scan_item.dart.
/// - يحافظ على واجهتي scan() و clean() المستخدمتين في HomeScreen.
/// - لم يُجرَ بناء Flutter أو flutter analyze لهذا الملف.
///
/// Dependencies:
/// - dart:io
/// - scan_item.dart
/// ===============================================================

import 'dart:io';

import 'scan_item.dart';

class CleanerEngine {
  CleanerEngine();

  /// امتدادات الملفات المؤقتة التي يبحث عنها المحرك.
  static const List<String> junkExtensions = <String>[
    '.tmp',
    '.temp',
    '.trash',
  ];

  /// جذر التخزين المشترك على أجهزة Android.
  static const String _storageRoot = '/storage/emulated/0';

  /// نتائج آخر عملية فحص.
  List<ScanItem> _results = <ScanItem>[];

  /// الملفات المكتشفة لكل فئة في آخر عملية فحص.
  ///
  /// المفاتيح هي معرفات الفئات، والقيم هي الملفات الفعلية
  /// التي اكتشفها الفحص، وليست المسارات المعروضة في الواجهة.
  final Map<String, List<File>> _filesByCategory =
      <String, List<File>>{};

  /// الملفات التي جرى فحصها في آخر عملية فحص.
  int _totalFiles = 0;

  /// الحجم الإجمالي للملفات المرشحة، بالبايت.
  int _totalBytes = 0;

  // Read-only inventory of media files reachable in shared storage.
  int _imageFiles = 0;
  int _imageBytes = 0;
  int _videoFiles = 0;
  int _videoBytes = 0;
  int _otherFiles = 0;
  int _otherBytes = 0;
  final Map<String, int> _accessibleFileSizes = <String, int>{};

  /// Largest readable files from the most recent scan, for inspection only.
  List<MapEntry<String, int>> get largestAccessibleFiles {
    final entries = _accessibleFileSizes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return List<MapEntry<String, int>>.unmodifiable(entries.take(50));
  }

  static const Set<String> _imageExtensions = <String>{
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif',
    '.avif', '.tif', '.tiff',
  };
  static const Set<String> _videoExtensions = <String>{
    '.mp4', '.m4v', '.mov', '.3gp', '.mkv', '.webm', '.avi', '.mpeg', '.mpg',
  };

  List<ScanItem> get results => List<ScanItem>.unmodifiable(_results);

  int get totalFiles => _totalFiles;

  int get totalBytes => _totalBytes;

  int get totalItems => _results.length;

  int get imageFiles => _imageFiles;
  int get imageBytes => _imageBytes;
  int get videoFiles => _videoFiles;
  int get videoBytes => _videoBytes;
  int get otherFiles => _otherFiles;
  int get otherBytes => _otherBytes;

  /// Returns the real files discovered for a category, without exposing the internal map.
  List<File> filesForCategory(String categoryId) =>
      List<File>.unmodifiable(_filesByCategory[categoryId] ?? const <File>[]);

  /// يعيد مجلد التخزين الذي سيبدأ منه الفحص.
  List<Directory> getScanDirectories() {
    return <Directory>[Directory(_storageRoot)];
  }

  /// يفحص التخزين ويصنف الملفات المرشحة للتنظيف.
  ///
  /// onStatus: رسالة توضح المرحلة الحالية.
  /// onProgress: نسبة تقدم تقريبية بين 0.0 و 1.0.
  ///
  /// ملاحظة:
  /// النسبة تقريبية؛ عدد الملفات النهائي غير معروف قبل اكتمال الفحص.
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
    _accessibleFileSizes.clear();

    final Map<String, List<File>> groupedFiles =
        <String, List<File>>{
      'temporary_files': <File>[],
      'thumbnail_files': <File>[],
    };

    final Map<String, int> groupedBytes = <String, int>{
      'temporary_files': 0,
      'thumbnail_files': 0,
    };

    final Directory root = Directory(_storageRoot);

    if (!await root.exists()) {
      onStatus?.call('مجلد التخزين غير متاح.');
      onProgress?.call(1.0);
      return _results;
    }

    final List<Directory> queue = <Directory>[root];
    int visitedDirectories = 0;
    int visitedFiles = 0;

    onStatus?.call('جارٍ فحص الملفات...');

    while (queue.isNotEmpty) {
      final Directory currentDirectory = queue.removeLast();

      if (!_isAllowedPath(currentDirectory.path)) {
        continue;
      }

      try {
        await for (final FileSystemEntity entity
            in currentDirectory.list(
          recursive: false,
          followLinks: false,
        )) {
          // نتجاهل الروابط الرمزية لتجنب تتبع مسارات غير متوقعة.
          if (entity is Link) {
            continue;
          }

          if (entity is Directory) {
            if (_isAllowedPath(entity.path)) {
              queue.add(entity);
            }
            continue;
          }

          if (entity is! File || !_isAllowedPath(entity.path)) {
            continue;
          }

          visitedFiles++;

          int fileBytes;
          try {
            fileBytes = await entity.length();
          } on FileSystemException {
            // قد يتعذر الوصول إلى الملف أو يكون قد اختفى.
            continue;
          }

          // Inventory is informational only; personal files are never selected for deletion here.
          _accessibleFileSizes[entity.path] = fileBytes;
          final String lowerPath = entity.path.toLowerCase();
          final String fileName = lowerPath.split('/').last;
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
          if (categoryId == null) {
            continue;
          }

          groupedFiles[categoryId]!.add(entity);
          groupedBytes[categoryId] =
              groupedBytes[categoryId]! + fileBytes;

          _totalFiles++;
          _totalBytes += fileBytes;
        }
      } on FileSystemException {
        // نتجاوز المجلدات التي لا تسمح المنصة بقراءتها.
        // لا يعني ذلك أن الفحص شمل كل ملفات الجهاز.
      }

      visitedDirectories++;

      // تقدم تقريبي يمنع إظهار 100% قبل انتهاء الفحص.
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

    onProgress?.call(1.0);
    onStatus?.call('اكتمل الفحص.');

    return List<ScanItem>.unmodifiable(_results);
  }

  /// يحذف الملفات التابعة للفئات المختارة فقط.
  ///
  /// يعيد عدد الملفات التي حُذفت بنجاح.
  ///
  /// يجب أن تكون العناصر المرسلة من نتائج الفحص الحالي،
  /// وأن تكون محددة وقابلة للمعالجة.
  Future<int> clean({
    required List<ScanItem> selected,
    Function(String)? onStatus,
  }) async {
    if (selected.isEmpty) {
      onStatus?.call('لم يتم اختيار أي فئة للتنظيف.');
      return 0;
    }

    int deletedFiles = 0;
    final Set<String> processedPaths = <String>{};

    // نتحقق من النتائج الحالية بدل الاعتماد على بيانات الواجهة وحدها.
    final Map<String, ScanItem> currentItems =
        <String, ScanItem>{
      for (final ScanItem item in _results) item.id: item,
    };

    onStatus?.call('جارٍ التحقق من الملفات المحددة...');

    for (final ScanItem requestedItem in selected) {
      final ScanItem? currentItem = currentItems[requestedItem.id];

      if (currentItem == null) {
        continue;
      }

      // اختيار المستخدم محفوظ في نسخة الواجهة؛ نتحقق هنا من أن
      // الفئة ما زالت ضمن نتائج الفحص الحالي ومسموح بمعالجتها.
      if (!requestedItem.selected ||
          !requestedItem.safeToDelete ||
          !currentItem.safeToDelete) {
        continue;
      }

      final List<File>? categoryFiles =
          _filesByCategory[currentItem.id];

      if (categoryFiles == null) {
        continue;
      }

      for (final File file in categoryFiles) {
        final String normalizedPath = _normalizePath(file.path);

        if (!_isAllowedPath(normalizedPath)) {
          continue;
        }

        // يمنع تكرار معالجة المسار نفسه دون تغيير حالة الأحرف
        // في المسار الفعلي الذي سيُستخدم للحذف.
        if (!processedPaths.add(normalizedPath)) {
          continue;
        }

        try {
          if (!await file.exists()) {
            continue;
          }

          // إعادة التحقق مباشرة قبل الحذف.
          if (!_isAllowedPath(file.path)) {
            continue;
          }

          await file.delete();
          deletedFiles++;
        } on FileSystemException {
          // نتجاوز الملف الذي تعذر حذفه ونواصل بقية الملفات.
        }
      }
    }

    // تُمسح نتائج الفحص السابقة بعد انتهاء عملية التنظيف؛
    // يجب إجراء فحص جديد لتحديث القائمة والأحجام.
    _results = <ScanItem>[];
    _filesByCategory.clear();

    onStatus?.call('انتهت عملية التنظيف.');
    return deletedFiles;
  }

  /// يصنف الملف ضمن الفئات المدعومة فقط.
  String? _classifyFile(String filePath) {
    final String normalized = _normalizePath(filePath);
    final String lowerPath = normalized.toLowerCase();

    if (_isThumbnailPath(lowerPath)) {
      return 'thumbnail_files';
    }

    final String fileName =
        lowerPath.split('/').isEmpty ? lowerPath : lowerPath.split('/').last;

    if (junkExtensions.any(fileName.endsWith)) {
      return 'temporary_files';
    }

    final List<String> segments = lowerPath.split('/');

    if (segments.any(
      (String segment) => segment == 'temp' || segment == 'tmp',
    )) {
      return 'temporary_files';
    }

    return null;
  }

  /// ينشئ نتيجة الفئة بعد تجميع الملفات المكتشفة.
  void _addCategory({
    required String id,
    required String title,
    required String descriptionPath,
    required List<File> files,
    required int bytes,
  }) {
    if (files.isEmpty) {
      return;
    }

    _filesByCategory[id] = List<File>.unmodifiable(files);

    _results.add(
      ScanItem(
        id: id,
        title: title,
        path: descriptionPath,
        files: files.length,
        bytes: bytes,
        // تعني أن الفئة مسموح بعرضها للاختيار،
        // ولا تعني أن كل ملف فيها مضمون الأمان للحذف.
        safeToDelete: true,
        selected: false,
      ),
    );
  }

  /// يتحقق من أن المسار يقع داخل جذر التخزين المسموح.
  ///
  /// ويستبعد Android/data و Android/obb صراحةً.
  bool _isAllowedPath(String path) {
    final String normalized = _normalizePath(path);
    final String lowerPath = normalized.toLowerCase();
    final String lowerRoot = _storageRoot.toLowerCase();

    if (lowerPath != lowerRoot &&
        !lowerPath.startsWith('$lowerRoot/')) {
      return false;
    }

    final List<String> segments = lowerPath.split('/');

    for (int i = 0; i < segments.length - 1; i++) {
      if (segments[i] == 'android' &&
          (segments[i + 1] == 'data' ||
              segments[i + 1] == 'obb')) {
        return false;
      }
    }

    return true;
  }

  /// يتحقق من وجود مجلد صور مصغرة في المسار.
  bool _isThumbnailPath(String lowerPath) {
    final List<String> segments = lowerPath.split('/');

    return segments.any(
      (String segment) => segment == '.thumbnails',
    );
  }

  /// يوحد فواصل المسارات ويزيل الفواصل المكررة.
  String _normalizePath(String path) {
    String normalized = path.replaceAll(r'\', '/');

    while (normalized.contains('//')) {
      normalized = normalized.replaceAll('//', '/');
    }

    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }

  /// يحسب مؤشرًا تقريبيًا بناءً على عدد الملفات المرشحة.
  ///
  /// هذا المؤشر ليس قياسًا حقيقيًا لصحة الجهاز أو أدائه.
  int calculateHealthScore() {
    if (_totalFiles == 0) {
      return 100;
    }

    // مؤشر توضيحي فقط؛ لا يُستخدم لتشخيص حالة الجهاز.
    final int score = 100 - (_totalFiles ~/ 100);
    return score.clamp(0, 100);
  }

  /// يحول عدد البايتات إلى صيغة مقروءة.
  static String formatBytes(int bytes) {
    if (bytes < 0) {
      return 'غير معروف';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
