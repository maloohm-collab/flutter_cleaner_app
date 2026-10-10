/// ===============================================================
/// المشروع: AI Cleaner
/// الملف: lib/services/cleaner_engine.dart
/// الإصدار: 1.1.0
/// التاريخ: 2026-10-10
///
/// المسؤوليات الرئيسية:
/// 1. فحص الملفات التي يمكن للتطبيق الوصول إليها.
/// 2. تصنيف الملفات المرشحة للتنظيف.
/// 3. عرض عدد الملفات وأحجامها حسب الفئة.
/// 4. حذف الملفات التابعة للفئات المحددة فقط.
/// 5. تسجيل نتائج الحذف الفعلية.
///
/// ملاحظات أمان مهمة:
/// - امتداد الملف وحده لا يثبت أنه غير مهم.
/// - لا نحذف مجلد التخزين الرئيسي.
/// - لا نحذف محتويات مجلد كامل اعتمادًا على اسمه.
/// - لا نعتبر ملفات التطبيقات الأخرى الخاصة متاحة للحذف.
/// - صلاحيات أندرويد ونسخة النظام تحددان الملفات القابلة للوصول.
/// ===============================================================

import 'dart:io';

import 'package:flutter_cleaner_app/services/scan_item.dart';

/// محرك الفحص والتنظيف.
///
/// يحتفظ هذا الكلاس بنتائج الفحص الحالي وبقائمة الملفات التي
/// اكتشفها في كل فئة؛ حتى تكون عملية الحذف مرتبطة بنتائج الفحص
/// الفعلية، لا بمسار عام مثل مجلد التخزين الرئيسي.
class CleanerEngine {
  // -------------------------------------------------------------
  // 1. البيانات الداخلية للمحرك
  // -------------------------------------------------------------

  /// نتائج الفحص التي ستُعرض في واجهة المستخدم.
  ///
  /// كل عنصر يمثل فئة من الملفات، وليس ملفًا منفردًا.
  final List<ScanItem> _results = [];

  /// الملفات المكتشفة في كل فئة.
  ///
  /// المفتاح هو معرّف الفئة.
  /// القيمة هي قائمة الملفات التي اكتُشفت أثناء الفحص.
  ///
  /// مثال:
  /// {
  ///   'temporary_files': [File(...), File(...)],
  ///   'thumbnail_files': [File(...)]
  /// }
  ///
  /// الفائدة الأمنية:
  /// لا نستخدم مسار الفئة لحذف كل الملفات الموجودة تحته،
  /// بل نستخدم الملفات التي سجّلها الفحص نفسه.
  final Map<String, List<File>> _filesByCategory = {};

  /// معرّفات داخلية ثابتة للفئات.
  ///
  /// لا تعتمد هذه المعرفات على أسماء العرض المترجمة.
  static const String _temporaryId = 'temporary_files';
  static const String _thumbnailId = 'thumbnail_files';

  /// امتدادات ملفات مرشحة للفحص.
  ///
  /// تنبيه:
  /// وجود هذه الامتدادات لا يعني أن الملف مهمل بالتأكيد.
  /// لذلك سنجعل هذه الفئة غير محددة افتراضيًا، ليختار المستخدم
  /// حذفها بعد مراجعة نتائج الفحص.
  static const List<String> junkExtensions = [
    '.tmp',
    '.temp',
    '.cache',
    '.trash',
  ];

  // -------------------------------------------------------------
  // 2. واجهة قراءة النتائج
  // -------------------------------------------------------------

  /// إرجاع نسخة غير قابلة للتعديل من النتائج.
  ///
  /// يمنع هذا الكود أجزاء أخرى من التطبيق من تعديل القائمة
  /// الداخلية مباشرة دون المرور بمنطق المحرك.
  List<ScanItem> get results => List.unmodifiable(_results);

  /// مجموع عدد الملفات في الفئات المكتشفة.
  int get totalFiles =>
      _results.fold(0, (sum, item) => sum + item.files);

  /// مجموع أحجام الملفات المكتشفة بالبايت.
  int get totalBytes =>
      _results.fold(0, (sum, item) => sum + item.bytes);

  /// عدد الفئات المكتشفة.
  ///
  /// هذا ليس عدد الملفات، بل عدد عناصر النتائج المعروضة.
  int get totalItems => _results.length;

  // -------------------------------------------------------------
  // 3. تحديد مجلدات الفحص
  // -------------------------------------------------------------

  /// تحديد نقطة بداية الفحص في مساحة التخزين المشتركة.
  ///
  /// هذه الدالة لا تمنح الصلاحيات بنفسها.
  /// يجب على واجهة التطبيق التعامل مع صلاحيات أندرويد أولًا.
  ///
  /// على بعض الأجهزة قد يتعذر الوصول إلى بعض المجلدات،
  /// حتى لو كان المسار موجودًا.
  Future<List<Directory>> getScanDirectories() async {
    return [
      Directory('/storage/emulated/0'),
    ];
  }

  // -------------------------------------------------------------
  // 4. تنفيذ الفحص
  // -------------------------------------------------------------

  /// فحص الملفات المتاحة وتصنيف الملفات المرشحة للتنظيف.
  ///
  /// onStatus:
  /// لإرسال رسالة الحالة إلى واجهة المستخدم.
  ///
  /// onProgress:
  /// لإرسال قيمة تقدم بين 0.0 و1.0.
  ///
  /// ملاحظة:
  /// التقدم هنا تقديري؛ لأن عدد الملفات التي يمكن الوصول إليها
  /// غير معروف قبل انتهاء الفحص.
  Future<List<ScanItem>> scan({
    Function(String message)? onStatus,
    Function(double progress)? onProgress,
  }) async {
    // أ. التخلص من نتائج الفحص السابق.
    _results.clear();
    _filesByCategory.clear();

    onStatus?.call('تهيئة الفحص...');
    onProgress?.call(0.02);

    // ب. الحصول على المجلدات الأساسية.
    final roots = await getScanDirectories();

    // ج. إنشاء قوائم مستقلة لكل فئة.
    final found = <String, List<File>>{
      _temporaryId: <File>[],
      _thumbnailId: <File>[],
    };

    // نستخدم قائمة عمل بدل الاستدعاء التكراري للدوال.
    // هذا الأسلوب يقلل الاعتماد على عمق استدعاءات الدوال.
    final queue = <Directory>[];

    // منع تكرار زيارة المسار نفسه.
    final visitedDirectories = <String>{};

    // إضافة المجلدات الموجودة والقابلة للفحص.
    for (final root in roots) {
      try {
        if (await root.exists()) {
          queue.add(root);
        }
      } catch (_) {
        // إذا تعذر الوصول إلى أحد المجلدات، نتابع غيره.
      }
    }

    int processedFiles = 0;

    // د. المرور على المجلدات واحدًا تلو الآخر.
    while (queue.isNotEmpty) {
      final directory = queue.removeLast();

      final directoryPath = _normalizePath(directory.path);

      // حماية المسارات المحظورة، مثل Android/data.
      if (!_isAllowedDirectory(directoryPath)) {
        continue;
      }

      // لا نعيد زيارة المجلد نفسه.
      if (!visitedDirectories.add(directoryPath)) {
        continue;
      }

      try {
        // recursive:false يعني أننا نقرأ محتويات هذا المجلد
        // فقط، ثم نضيف المجلدات الفرعية إلى قائمة العمل.
        //
        // followLinks:false يمنع اتباع الروابط الرمزية.
        await for (final entity in directory.list(
          recursive: false,
          followLinks: false,
        )) {
          // إذا كان العنصر مجلدًا، نقرر لاحقًا هل نسمح بفحصه.
          if (entity is Directory) {
            final childPath = _normalizePath(entity.path);

            if (_isAllowedDirectory(childPath)) {
              queue.add(entity);
            }

            continue;
          }

          // نتعامل مع الملفات العادية فقط.
          if (entity is! File) {
            continue;
          }

          processedFiles++;

          try {
            // تصنيف الملف دون حذفه.
            final categoryId = _classifyFile(entity.path);

            if (categoryId == null) {
              continue;
            }

            // الاحتفاظ بالملف ضمن فئته الصحيحة.
            found[categoryId]!.add(entity);
          } catch (_) {
            // قد يتعذر الوصول إلى ملف معين.
            // فشل قراءة ملف واحد لا يوقف الفحص بالكامل.
          }

          // تحديث الواجهة كل 100 ملف لتقليل التحديثات المتكررة.
          if (processedFiles % 100 == 0) {
            final progress =
                0.05 +
                0.85 *
                    (processedFiles / (processedFiles + 5000));

            onProgress?.call(
              progress.clamp(0.0, 0.90).toDouble(),
            );

            onStatus?.call(
              'تم فحص $processedFiles ملفًا...',
            );
          }
        }
      } catch (_) {
        // قد يرفض النظام الوصول إلى بعض المجلدات.
        // نتجاوز المجلد المتعذر ونواصل الفحص.
      }
    }

    // هـ. تحويل الملفات المجمعة إلى عناصر تعرضها الواجهة.
    _addCategory(
      id: _thumbnailId,
      title: 'Thumbnail Cache',
      files: found[_thumbnailId]!,
      selectedByDefault: false,
    );

    _addCategory(
      id: _temporaryId,
      title: 'Temporary and Cache Candidates',
      files: found[_temporaryId]!,
      selectedByDefault: false,
    );

    onProgress?.call(1.0);
    onStatus?.call('اكتمل الفحص');

    return results;
  }

  // -------------------------------------------------------------
  // 5. تصنيف الملفات
  // -------------------------------------------------------------

  /// تحديد الفئة التي ينتمي إليها الملف.
  ///
  /// القيمة null تعني أن الملف لا يطابق قواعد الفحص الحالية.
  ///
  /// مهم:
  /// التصنيف ليس حكمًا نهائيًا بأن الملف آمن للحذف.
  String? _classifyFile(String filePath) {
    final path = _normalizePath(filePath);

    // أ. البحث عن ملفات تبدو مرتبطة بالصور المصغرة.
    //
    // لا نحذف مجلد thumbnails كاملًا.
    // نصنف الملفات التي تتطابق مساراتها أو امتداداتها فقط.
    final isThumbnail =
        path.contains('/.thumbnails/') ||
        path.contains('/thumbnails/') ||
        path.contains('/thumbnail/') ||
        path.endsWith('.thumb') ||
        path.endsWith('.thumbnail');

    if (isThumbnail) {
      return _thumbnailId;
    }

    // ب. استخراج الامتداد بطريقة مبسطة.
    final lastSlash = path.lastIndexOf('/');
    final lastDot = path.lastIndexOf('.');

    final extension =
        lastDot > lastSlash ? path.substring(lastDot) : '';

    final hasTemporaryExtension =
        junkExtensions.contains(extension);

    // ج. معرفة ما إذا كان اسم أحد أجزاء المسار يدل على
    // مجلد مؤقت أو مجلد ذاكرة مؤقتة.
    //
    // هذا معيار للترشيح فقط، وليس دليلًا قاطعًا على أن الملف
    // يمكن حذفه دون أي أثر.
    final segments = path.split('/');

    final insideTemporaryDirectory = segments.any(
      (segment) =>
          segment == 'temp' ||
          segment == 'tmp' ||
          segment == 'cache',
    );

    if (hasTemporaryExtension || insideTemporaryDirectory) {
      return _temporaryId;
    }

    return null;
  }

  // -------------------------------------------------------------
  // 6. تجهيز الفئات لعرضها في الواجهة
  // -------------------------------------------------------------

  /// تجميع ملفات الفئة وحساب عددها وحجمها.
  void _addCategory({
    required String id,
    required String title,
    required List<File> files,
    required bool selectedByDefault,
  }) {
    // لا نعرض فئة فارغة.
    if (files.isEmpty) {
      return;
    }

    int bytes = 0;

    // حساب الحجم الحالي لكل ملف.
    // قد يتعذر الوصول إلى بعض الملفات أثناء حساب الحجم.
    for (final file in files) {
      try {
        bytes += file.lengthSync();
      } catch (_) {
        // نتجاوز الحجم غير المتاح.
      }
    }

    // حفظ قائمة الملفات الخاصة بهذه الفئة.
    _filesByCategory[id] = List<File>.from(files);

    // إنشاء عنصر متوافق مع ScanItem الحالي.
    _results.add(
      ScanItem(
        id: id,
        title: title,

        // ليس مسارًا حقيقيًا؛ بل معرّف توضيحي للفئة.
        // لا تستخدم هذا الحقل لحذف مجلد.
        path: 'category://$id',

        files: files.length,
        bytes: bytes,

        // هذا الحقل يسمح بظهور الفئة ضمن خيارات التنظيف.
        // لا يعني أن كل ملف داخلها مضمون السلامة.
        safeToDelete: true,

        // الملفات المرشحة لا تُحدد تلقائيًا.
        selected: selectedByDefault,
      ),
    );
  }

  // -------------------------------------------------------------
  // 7. حذف الملفات التي اختارها المستخدم
  // -------------------------------------------------------------

  /// حذف الملفات المسجلة في الفئات المحددة فقط.
  ///
  /// selected:
  /// عناصر النتائج التي مررتها الواجهة بعد اختيار المستخدم.
  ///
  /// القيمة المعادة:
  /// عدد الملفات التي نجح حذفها بالفعل.
  ///
  /// ملاحظة مهمة:
  /// يجب أن تعرض الواجهة رسالة النجاح اعتمادًا على هذه القيمة،
  /// لا اعتمادًا على اكتمال حركة التحميل أو انتهاء المؤقت.
  Future<int> clean({
    required List<ScanItem> selected,
    Function(String message)? onStatus,
  }) async {
    if (selected.isEmpty) {
      onStatus?.call('لم يتم تحديد أي فئة');
      return 0;
    }

    int deleted = 0;
    int failed = 0;

    final rootPath = _normalizePath(
      Directory('/storage/emulated/0').absolute.path,
    );

    // استخدام خريطة لمنع معالجة المسار نفسه أكثر من مرة.
    final filesToDelete = <String, File>{};

    // أ. قبول الملفات التي تنتمي إلى فئة مسجلة في الفحص الحالي.
    for (final item in selected) {
      // تجاهل العناصر غير المحددة أو غير المسموح بها.
      if (!item.selected || !item.safeToDelete) {
        continue;
      }

      // إذا لم يكن معرّف الفئة موجودًا في نتائج الفحص الحالية،
      // فلن نعتمد عليه في الحذف.
      final categoryFiles = _filesByCategory[item.id];

      if (categoryFiles == null) {
        continue;
      }

      for (final file in categoryFiles) {
        final path = _normalizePath(file.absolute.path);

        // ب. التأكد من أن الملف يقع داخل جذر التخزين المتوقع.
        if (!_isInsideRoot(path, rootPath)) {
          continue;
        }

        filesToDelete[path] = file;
      }
    }

    if (filesToDelete.isEmpty) {
      onStatus?.call(
        'لا توجد ملفات صالحة للحذف ضمن الاختيار',
      );
      return 0;
    }

    onStatus?.call('بدء حذف الملفات المحددة...');

    // ج. محاولة حذف كل ملف بصورة مستقلة.
    for (final entry in filesToDelete.entries) {
      final file = entry.value;

      try {
        if (await file.exists()) {
          await file.delete();
          deleted++;

          if (deleted % 50 == 0) {
            onStatus?.call(
              'تم حذف $deleted ملفًا...',
            );
          }
        }
      } catch (_) {
        // لا نوقف العملية كلها بسبب فشل ملف واحد.
        failed++;
      }
    }

    // د. إزالة نتائج الفحص القديم حتى لا تبقى الأرقام السابقة
    // معروضة وكأنها نتائج جديدة.
    _results.clear();
    _filesByCategory.clear();

    if (failed == 0) {
      onStatus?.call(
        'اكتمل الحذف: $deleted ملفًا',
      );
    } else {
      onStatus?.call(
        'حُذف $deleted ملفًا، وتعذر حذف $failed ملف',
      );
    }

    return deleted;
  }

  // -------------------------------------------------------------
  // 8. قواعد حماية المجلدات
  // -------------------------------------------------------------

  /// تحديد المجلدات التي لا ينبغي فحصها بهذا المحرك.
  bool _isAllowedDirectory(String path) {
    final normalized = _normalizePath(path);

    // لا ندخل إلى مجلدات بيانات التطبيقات أو ملفات التوسعة.
    //
    // هذه الحماية تقلل مخاطر العبث ببيانات التطبيقات،
    // لكنها ليست بديلًا عن صلاحيات أندرويد أو اختبار النظام.
    if (normalized.contains('/android/data/') ||
        normalized.endsWith('/android/data') ||
        normalized.contains('/android/obb/') ||
        normalized.endsWith('/android/obb')) {
      return false;
    }

    return true;
  }

  /// التحقق من أن مسار الملف يقع تحت جذر التخزين المحدد.
  bool _isInsideRoot(String filePath, String rootPath) {
    final normalizedFile = _normalizePath(filePath);
    final normalizedRoot = _normalizePath(rootPath);

    // اشتراط وجود الفاصل بعد جذر التخزين يمنع مطابقة مسارات
    // مشابهة في بدايتها لكنها ليست داخل المجلد المطلوب.
    return normalizedFile.startsWith(
      normalizedRoot.endsWith('/')
          ? normalizedRoot
          : '$normalizedRoot/',
    );
  }

  /// توحيد شكل المسار لتسهيل المقارنة.
  String _normalizePath(String path) {
    return path.replaceAll(r'\', '/').toLowerCase();
  }

  // -------------------------------------------------------------
  // 9. حساب مؤشر الصحة
  // -------------------------------------------------------------

  /// حساب مؤشر تقديري مبني على عدد الملفات المكتشفة.
  ///
  /// هذا ليس قياسًا حقيقيًا لصحة الهاتف أو سرعة المعالج.
  /// ينبغي ألا يُعرض للمستخدم على أنه قياس للنظام.
  int calculateHealthScore() {
    if (_results.isEmpty) {
      return 100;
    }

    final score = 100 - (totalFiles ~/ 20);

    if (score < 60) {
      return 60;
    }

    return score > 100 ? 100 : score;
  }

  // -------------------------------------------------------------
  // 10. تحويل الأحجام إلى وحدات مقروءة
  // -------------------------------------------------------------

  /// تحويل الحجم من بايت إلى B أو KB أو MB أو GB.
  String formatBytes(int bytes) {
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
