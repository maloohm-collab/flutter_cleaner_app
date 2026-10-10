// ============================================================================
// Project      : AI Cleaner
// File         : lib/services/cleaner_engine.dart
// Version      : 1.2.0
// Last Updated : 2026-10-10
// Purpose      : فحص الملفات المؤقتة والمرشحة للتنظيف في وحدة التخزين المشتركة،
//                وتجميع نتائج الفحص حسب الفئة، وتنفيذ الحذف بعد اختيار المستخدم.
// ----------------------------------------------------------------------------
// Changes in v1.2.0:
// - تحسين أمان اكتشاف الملفات المرشحة للحذف.
// - عدم اعتبار كل ملف يحتوي مساره على cache أو temp ملفًا غير ضروري.
// - جعل عناصر نتائج الفحص غير محددة للحذف افتراضيًا.
// - استبدال حساب أحجام الملفات المتزامن بحساب غير متزامن.
// - منع تكرار حذف المسارات والتحقق منها قبل الحذف.
// - تجاهل Android/data و Android/obb.
// - تحسين معالجة أخطاء الفحص والحذف وتحديث رسائل الحالة.
// - الحفاظ على الواجهات العامة الأساسية للتوافق مع أجزاء المشروع.
// ----------------------------------------------------------------------------
// Safety Notes:
// - لا يضمن هذا الفحص أن كل ملف مرشح للحذف غير مهم؛ راجع النتائج قبل الحذف.
// - لا يستطيع التطبيق حذف ذاكرة التخزين الخاصة بالتطبيقات الأخرى بصورة عامة.
// - لا يجري هذا الملف تنظيفًا تلقائيًا أثناء الفحص.
// - صلاحية MANAGE_EXTERNAL_STORAGE لا تضمن تجاوز جميع قيود Android.
// - درجة صحة الجهاز المحسوبة هنا تقديرية وليست قياسًا فعليًا لصحة النظام.
// ----------------------------------------------------------------------------
// Dependencies:
// - dart:io
// - lib/models/scan_item.dart أو المسار الفعلي الذي يعرّف ScanItem.
// ----------------------------------------------------------------------------
// Compatibility:
// - يحافظ على CleanerEngine.scan() و CleanerEngine.clean().
// - يحافظ على النتائج والإحصاءات والدوال المساعدة الأساسية.
// - لم يُنفّذ بناء Flutter أو اختبار على جهاز فعلي ضمن هذه المراجعة.
// ============================================================================

import 'dart:io';

import '../models/scan_item.dart';

/// محرك فحص وتنظيف الملفات المرشحة للحذف.
///
/// ملاحظة مهمة:
/// هذا المحرك لا ينظف ذاكرة التطبيقات الأخرى الخاصة، ولا ينفذ حذفًا
/// أثناء عملية الفحص. يجب أن يختار المستخدم العناصر التي يريد تنظيفها.
class CleanerEngine {
  CleanerEngine();

  // --------------------------------------------------------------------------
  // ثوابت الفئات
  // --------------------------------------------------------------------------

  static const String _temporaryId = 'temporary_files';
  static const String _thumbnailId = 'thumbnail_files';

  /// امتدادات ملفات مؤقتة محتملة.
  ///
  /// وجود أحد هذه الامتدادات لا يثبت وحده أن الملف غير مهم؛ لذلك تُعرض
  /// الملفات ضمن نتائج الفحص ولا تُحذف إلا بعد اختيار المستخدم.
  static const List<String> junkExtensions = <String>[
    '.tmp',
    '.temp',
    '.trash',
  ];

  /// مجلدات تُستخدم عادةً لحفظ ملفات مؤقتة.
  ///
  /// نتجنب اعتبار كل مجلد يحتوي على كلمة cache مرشحًا للحذف؛ فقد يحتوي
  /// على ملفات يحتاجها المستخدم أو تطبيق آخر.
  static const Set<String> _temporaryDirectoryNames = <String>{
    'temp',
    'tmp',
  };

  // --------------------------------------------------------------------------
  // بيانات الفحص
  // --------------------------------------------------------------------------

  final List<ScanItem> _results = <ScanItem>[];

  /// الملفات التي اكتُشفت لكل فئة أثناء آخر عملية فحص.
  ///
  /// لا تُقبل عملية الحذف اعتمادًا على مسار يرسله المستدعي فقط؛
  /// بل يجب أن تكون الفئة قد سُجلت ضمن نتائج الفحص الحالي.
  final Map<String, List<File>> _filesByCategory =
      <String, List<File>>{};

  /// المسار الأساسي الذي يجري فحصه.
  static const String _storageRootPath = '/storage/emulated/0';

  /// نسخة غير قابلة للتعديل من نتائج الفحص.
  List<ScanItem> get results => List<ScanItem>.unmodifiable(_results);

  /// عدد الملفات المكتشفة ضمن الفئات المرشحة.
  int get totalFiles =>
      _results.fold<int>(0, (sum, item) => sum + item.files);

  /// إجمالي أحجام الملفات المرشحة بالبايت.
  int get totalBytes =>
      _results.fold<int>(0, (sum, item) => sum + item.bytes);

  /// عدد الفئات التي ظهرت في نتائج الفحص.
  int get totalItems => _results.length;

  // --------------------------------------------------------------------------
  // مجلدات الفحص
  // --------------------------------------------------------------------------

  /// إرجاع مجلد التخزين المشترك الذي يدعمه هذا المحرك.
  ///
  /// قد لا يكون هذا المسار متاحًا على جميع الأجهزة أو إصدارات Android.
  Future<List<Directory>> getScanDirectories() async {
    final Directory root = Directory(_storageRootPath);

    if (!await root.exists()) {
      return <Directory>[];
    }

    return <Directory>[root];
  }

  // --------------------------------------------------------------------------
  // عملية الفحص
  // --------------------------------------------------------------------------

  /// فحص الملفات وجمعها حسب الفئة.
  ///
  /// [onStatus] لإرسال وصف موجز للحالة.
  /// [onProgress] لتحديث التقدم التقريبي بين 0 و1.
  ///
  /// ملاحظة:
  /// نسبة التقدم تقديرية؛ لأن عدد الملفات الكلي غير معروف قبل الفحص.
  Future<List<ScanItem>> scan({
    Function(String message)? onStatus,
    Function(double progress)? onProgress,
  }) async {
    _results.clear();
    _filesByCategory.clear();

    final Map<String, List<File>> foundFiles =
        <String, List<File>>{
      _temporaryId: <File>[],
      _thumbnailId: <File>[],
    };

    final Map<String, int> categoryBytes = <String, int>{
      _temporaryId: 0,
      _thumbnailId: 0,
    };

    final List<Directory> roots = await getScanDirectories();

    if (roots.isEmpty) {
      onStatus?.call('مجلد التخزين المشترك غير متاح.');
      onProgress?.call(1.0);
      return results;
    }

    final List<Directory> pendingDirectories = <Directory>[...roots];

    int visitedFiles = 0;
    int visitedDirectories = 0;

    onStatus?.call('بدء فحص الملفات المرشحة للتنظيف...');
    onProgress?.call(0.0);

    while (pendingDirectories.isNotEmpty) {
      final Directory currentDirectory = pendingDirectories.removeLast();

      if (!_isAllowedDirectory(currentDirectory.path)) {
        continue;
      }

      try {
        await for (final FileSystemEntity entity
            in currentDirectory.list(
          recursive: false,
          followLinks: false,
        )) {
          // لا نتبع الروابط الرمزية؛ لتجنب الخروج إلى مسارات أخرى.
          if (entity is Link) {
            continue;
          }

          if (entity is Directory) {
            if (_isAllowedDirectory(entity.path)) {
              pendingDirectories.add(entity);
            }

            visitedDirectories++;
            continue;
          }

          if (entity is! File) {
            continue;
          }

          visitedFiles++;

          final String? categoryId = _classifyFile(entity.path);

          if (categoryId == null) {
            continue;
          }

          try {
            final int fileBytes = await entity.length();

            foundFiles[categoryId]!.add(entity);
            categoryBytes[categoryId] =
                categoryBytes[categoryId]! + fileBytes;
          } on FileSystemException {
            // قد يتعذر الوصول إلى بعض الملفات بسبب قيود النظام.
            // نتجاوز الملف المتعذر بدل إيقاف عملية الفحص كاملة.
          } on IOException {
            // تجاوز أخطاء القراءة الخاصة بهذا الملف فقط.
          }

          // تحديث التقدم كل 100 ملف لتقليل تحديثات الواجهة.
          if (visitedFiles % 100 == 0) {
            onStatus?.call('تم فحص $visitedFiles ملف...');
            onProgress?.call(
              _estimateProgress(
                visitedFiles,
                visitedDirectories,
              ),
            );
          }
        }
      } on FileSystemException {
        // بعض المجلدات قد تكون غير قابلة للقراءة.
        // يستمر الفحص في بقية المجلدات المتاحة.
      } on IOException {
        // لا نوقف الفحص بالكامل بسبب مجلد واحد.
      }
    }

    _addCategoryResult(
      id: _temporaryId,
      title: 'الملفات المؤقتة',
      files: foundFiles[_temporaryId]!,
      bytes: categoryBytes[_temporaryId]!,
    );

    _addCategoryResult(
      id: _thumbnailId,
      title: 'ملفات الصور المصغرة',
      files: foundFiles[_thumbnailId]!,
      bytes: categoryBytes[_thumbnailId]!,
    );

    onStatus?.call(
      'اكتمل الفحص: '
      '${_results.fold<int>(0, (sum, item) => sum + item.files)} '
      'ملف مرشح.',
    );
    onProgress?.call(1.0);

    return results;
  }

  /// إضافة نتيجة فئة إذا كانت تحتوي على ملفات.
  ///
  /// selected=false يمنع تحديد الفئة تلقائيًا للحذف.
  void _addCategoryResult({
    required String id,
    required String title,
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
        path: 'category://$id',
        files: files.length,
        bytes: bytes,
        safeToDelete: true,
        selected: false,
      ),
    );
  }

  /// تقدير تقريبي للتقدم دون الادعاء بمعرفة العدد الكلي للملفات.
  double _estimateProgress(int files, int directories) {
    final int workUnits = files + (directories * 5);

    // تظل النسبة أقل من 100% إلى أن ينتهي الفحص فعليًا.
    final double progress = workUnits / (workUnits + 500.0);

    return progress.clamp(0.0, 0.95).toDouble();
  }

  // --------------------------------------------------------------------------
  // تصنيف الملفات
  // --------------------------------------------------------------------------

  /// إرجاع معرّف الفئة للملف المرشح، أو null إذا لم يطابق القواعد.
  String? _classifyFile(String filePath) {
    final String normalizedPath = _normalizePath(filePath);

    if (!_isInsideRoot(normalizedPath)) {
      return null;
    }

    if (!_isAllowedDirectory(normalizedPath)) {
      return null;
    }

    if (_isThumbnailPath(normalizedPath)) {
      return _thumbnailId;
    }

    if (_hasTemporaryExtension(normalizedPath) ||
        _isInsideTemporaryDirectory(normalizedPath)) {
      return _temporaryId;
    }

    return null;
  }

  /// اكتشاف مجلد الصور المصغرة المخفي تحديدًا.
  ///
  /// نتجنب تصنيف كل مجلد يحمل كلمة thumbnails؛ لأن بعض هذه المجلدات
  /// قد يحتوي على صور أصلية أو ملفات أنشأها المستخدم.
  bool _isThumbnailPath(String normalizedPath) {
    final List<String> segments = normalizedPath.split('/');

    return segments.any((segment) => segment == '.thumbnails');
  }

  bool _hasTemporaryExtension(String normalizedPath) {
    return junkExtensions.any(normalizedPath.endsWith);
  }

  bool _isInsideTemporaryDirectory(String normalizedPath) {
    final List<String> segments = normalizedPath.split('/');

    return segments.any(_temporaryDirectoryNames.contains);
  }

  // --------------------------------------------------------------------------
  // التحقق من المسارات
  // --------------------------------------------------------------------------

  /// توحيد فواصل المسارات للمقارنة فقط.
  ///
  /// لا نستخدم المسار الموحّد بدل المسار الأصلي عند الحذف.
  String _normalizePath(String path) {
    return path.replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');
  }

  /// التأكد من أن المسار داخل التخزين المشترك المحدد.
  bool _isInsideRoot(String path) {
    final String normalized = _normalizePath(path).toLowerCase();
    const String root = _storageRootPath;

    return normalized == root ||
        normalized.startsWith('$root/');
  }

  /// استبعاد المسارات التي لا ينبغي للمحرك التعامل معها.
  ///
  /// المقارنة تراعي حدود المجلد حتى لا تُستبعد أسماء مشابهة بالخطأ.
  bool _isAllowedDirectory(String path) {
    final String normalized = _normalizePath(path).toLowerCase();

    if (!_isInsideRoot(normalized)) {
      return false;
    }

    const String root = _storageRootPath;
    final String relativePath = normalized == root
        ? ''
        : normalized.substring(root.length + 1);

    final List<String> segments = relativePath.split('/');

    if (segments.isEmpty) {
      return true;
    }

    // استبعاد مجلدات بيانات التطبيقات وملفات توسعتها.
    if (segments.length >= 2 &&
        segments[0] == 'android' &&
        (segments[1] == 'data' || segments[1] == 'obb')) {
      return false;
    }

    return true;
  }

  // --------------------------------------------------------------------------
  // عملية التنظيف
  // --------------------------------------------------------------------------

  /// حذف الملفات التابعة للفئات التي اختارها المستخدم.
  ///
  /// [selected] عناصر ScanItem التي أعادت عملية scan().
  /// [onStatus] لاستقبال رسائل الحالة.
  ///
  /// تعيد الدالة عدد الملفات التي حُذفت بنجاح.
  ///
  /// تنبيه:
  /// يجب تمرير نتائج الفحص الحالي بعد تحديث selected في الواجهة.
  /// لا تُحذف أي فئة غير مسجلة في نتائج الفحص الحالي.
  Future<int> clean({
    required List<ScanItem> selected,
    Function(String message)? onStatus,
  }) async {
    if (_filesByCategory.isEmpty) {
      onStatus?.call('لا توجد نتائج فحص صالحة للتنظيف.');
      return 0;
    }

    int deletedFiles = 0;
    int failedFiles = 0;
    int processedFiles = 0;

    final Set<String> deletedPaths = <String>{};

    final Map<String, ScanItem> currentResults =
        <String, ScanItem>{
      for (final ScanItem item in _results) item.id: item,
    };

    final Set<String> selectedCategoryIds = <String>{};

    for (final ScanItem item in selected) {
      final ScanItem? currentItem = currentResults[item.id];

      if (currentItem == null ||
          !item.selected ||
          !item.safeToDelete ||
          !_filesByCategory.containsKey(item.id)) {
        continue;
      }

      selectedCategoryIds.add(item.id);
    }

    if (selectedCategoryIds.isEmpty) {
      onStatus?.call('لم يتم تحديد أي فئة للتنظيف.');
      return 0;
    }

    onStatus?.call('بدء تنظيف الملفات المحددة...');

    for (final String categoryId in selectedCategoryIds) {
      final List<File> files =
          _filesByCategory[categoryId] ?? <File>[];

      for (final File file in files) {
        final String originalPath = file.path;
        final String normalizedPath = _normalizePath(originalPath);
        final String comparisonPath = normalizedPath.toLowerCase();

        // تحقق جديد قبل كل عملية حذف.
        if (!_isInsideRoot(comparisonPath) ||
            !_isAllowedDirectory(comparisonPath)) {
          failedFiles++;
          continue;
        }

        if (!deletedPaths.add(comparisonPath)) {
          continue;
        }

        try {
          if (!await file.exists()) {
            // الملف اختفى بعد الفحص؛ لا نعدّه ملفًا محذوفًا بنجاح.
            continue;
          }

          final int fileBytes = await file.length();

          await file.delete();

          deletedFiles++;

          onStatus?.call(
            'تم حذف ملف: ${_basename(originalPath)} '
            '(${formatBytes(fileBytes)}).',
          );
        } on FileSystemException {
          failedFiles++;
        } on IOException {
          failedFiles++;
        }

        processedFiles++;
      }
    }

    // نتائج الفحص أصبحت قديمة بعد عملية التنظيف.
    // يُطلب فحص جديد لتحديث الأحجام وعدد الملفات.
    _results.clear();
    _filesByCategory.clear();

    onStatus?.call(
      'انتهى التنظيف. '
      'تم حذف $deletedFiles ملف، '
      'وتعذر حذف $failedFiles ملف.',
    );

    return deletedFiles;
  }

  String _basename(String path) {
    final String normalized = _normalizePath(path);
    final List<String> segments = normalized.split('/');

    return segments.isEmpty ? path : segments.last;
  }

  // --------------------------------------------------------------------------
  // الإحصاءات والمساعدة
  // --------------------------------------------------------------------------

  /// حساب درجة تقديرية بناءً على حجم الملفات المكتشفة.
  ///
  /// هذه القيمة مؤشر توضيحي داخل الواجهة فقط، وليست فحصًا لصحة الجهاز.
  int calculateHealthScore() {
    if (_results.isEmpty) {
      return 100;
    }

    final double sizeInMb = totalBytes / (1024 * 1024);

    // تخفيض محدود وتدريجي بحسب حجم الملفات المرشحة.
    final int penalty = (sizeInMb / 100).floor();

    return (100 - penalty).clamp(0, 100).toInt();
  }

  /// تحويل عدد البايتات إلى صيغة مقروءة.
  static String formatBytes(int bytes) {
    if (bytes < 0) {
      return 'غير معروف';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
