//
// ============================================================================
// Project: AI Cleaner
// File: lib/services/plugins/thumbnail_cleaner.dart
// Version: 1.1.0
// Last Updated: 2026-10-10
// Language: Dart
//
// ----------------------------------------------------------------------------
// Purpose | الغرض من الملف
// ----------------------------------------------------------------------------
// إدارة فحص وتنظيف مجلدات التخزين المؤقت التابعة للتطبيق نفسه.
//
// تنبيه:
// هذا الملف لا ينظف ذاكرة التطبيقات الأخرى الخاصة، ولا يضمن تنظيف جميع
// الصور المصغرة الموجودة في الهاتف.
// يعتمد على المسارات التي يوفرها path_provider.
//
// ----------------------------------------------------------------------------
// Changes in Version 1.1.0 | سجل التعديلات
// ----------------------------------------------------------------------------
// 1. فصل عملية الفحص عن عملية الحذف؛ الفحص لا يحذف الملفات.
// 2. جعل العناصر المكتشفة غير محددة افتراضيًا.
// 3. قصر الحذف على مجلدات التخزين المؤقت التي اكتُشفت أثناء الفحص.
// 4. رفض العناصر التي لم يسجلها هذا المنظف خلال آخر عملية فحص.
// 5. احتساب الملفات والمساحة بعد نجاح الحذف فقط.
// 6. تحسين رسائل الأخطاء بدل تجاهل جميع الأخطاء بصمت.
// 7. استخدام عمليات غير متزامنة لتقليل احتمال تجميد الواجهة.
//
// ----------------------------------------------------------------------------
// Safety Notes | ملاحظات الأمان
// ----------------------------------------------------------------------------
// 1. يجب أن يختار المستخدم العناصر قبل حذفها.
// 2. safeToDelete تعني أن العنصر مؤهل للعرض ضمن خيارات التنظيف، ولا تعني
//    ضمان أن كل ملف داخله غير مهم.
// 3. لا يُسمح لهذا الملف بحذف محتويات مسارات عشوائية.
// 4. يجب ألا تعتبر الواجهة انتهاء الدالة دليلًا على حذف جميع الملفات.
// 5. يجب التحقق من توافق هذا الملف مع CleanerEngine قبل اعتماد المسار النهائي.
// 6. لا يغني هذا الملف عن اختبارات فعلية على أجهزة Android.
//
// ----------------------------------------------------------------------------
// Dependencies | الاعتماديات
// ----------------------------------------------------------------------------
// - dart:io
// - path
// - path_provider
// - ScanItem
//
// ----------------------------------------------------------------------------
// Compatibility | التوافق
// ----------------------------------------------------------------------------
// يستخدم نموذج ScanItem الحقول التالية:
// id, title, path, files, bytes, safeToDelete, selected
//
// لا يتطلب الملف تغييرًا في منشئ ScanItem أو دالة copyWith.
//
// ============================================================================

import 'dart:io';

import 'package:flutter_cleaner_app/services/scan_item.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// منظف مجلدات التخزين المؤقت الخاصة بالتطبيق.
///
/// هذا المنظف لا ينظف ذاكرة التطبيقات الأخرى.
/// كما أن الفحص لا يحذف أي ملف؛ الحذف عملية منفصلة تتطلب اختيار العناصر.
class ThumbnailCleaner {
  /// نتائج آخر عملية فحص.
  final List<ScanItem> results = <ScanItem>[];

  /// المسارات التي اكتشفها المنظف في آخر عملية فحص.
  ///
  /// المفتاح هو معرّف الفئة، والقيمة هي المسار المسجل لها.
  final Map<String, String> _scannedRoots = <String, String>{};

  /// إجمالي حجم الملفات التي حُذفت بنجاح في آخر عملية تنظيف.
  int freedBytes = 0;

  /// توحيد المسار قبل المقارنة.
  ///
  /// لا يعني توحيد المسار أن الصلاحيات متاحة؛ نظام الملفات هو المرجع
  /// النهائي في تحديد إمكانية الوصول إلى الملف.
  String _normalizePath(String path) {
    return p.normalize(p.absolute(path));
  }

  /// جلب مجلدات التخزين المؤقت التي يوفرها النظام للتطبيق الحالي.
  Future<List<Directory>> _getCacheDirectories() async {
    final directories = <Directory>[];

    try {
      directories.add(await getTemporaryDirectory());
    } catch (_) {
      // قد يتعذر الحصول على مجلد الملفات المؤقتة.
    }

    try {
      final externalDirectories = await getExternalCacheDirectories();

      if (externalDirectories != null) {
        directories.addAll(externalDirectories);
      }
    } catch (_) {
      // قد لا تكون مجلدات التخزين المؤقت الخارجية متاحة على بعض الأجهزة.
    }

    // إزالة المسارات المكررة بعد توحيدها.
    final uniqueDirectories = <String, Directory>{};

    for (final directory in directories) {
      final normalizedPath = _normalizePath(directory.path);

      uniqueDirectories.putIfAbsent(
        normalizedPath,
        () => Directory(normalizedPath),
      );
    }

    return uniqueDirectories.values.toList(growable: false);
  }

  /// فحص مجلد دون حذف أي محتوى منه.
  Future<ScanItem?> _scanDirectory({
    required Directory directory,
    required String id,
    required String title,
    required Function(String message)? onProgress,
  }) async {
    if (!await directory.exists()) {
      return null;
    }

    int filesCount = 0;
    int bytesCount = 0;

    try {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        try {
          final size = await entity.length();

          filesCount++;
          bytesCount += size;
        } on FileSystemException catch (error) {
          // نتجاوز الملفات التي تعذر الوصول إليها، مع تسجيل السبب.
          onProgress?.call(
            'تعذر قراءة حجم أحد الملفات: ${error.message}',
          );
        } catch (error) {
          onProgress?.call(
            'تعذر حساب حجم أحد الملفات: $error',
          );
        }
      }
    } on FileSystemException catch (error) {
      onProgress?.call(
        'تعذر إكمال فحص المجلد: ${error.message}',
      );
    } catch (error) {
      onProgress?.call(
        'حدث خطأ أثناء الفحص: $error',
      );
    }

    // لا نضيف الفئة إذا لم نجد ملفات يمكن احتسابها.
    if (filesCount == 0) {
      return null;
    }

    return ScanItem(
      id: id,
      title: title,
      path: _normalizePath(directory.path),
      files: filesCount,
      bytes: bytesCount,

      // هذه القيمة لا تعني ضمان سلامة حذف كل ملف.
      // إنها تعني أن الفئة يمكن عرضها للمستخدم لاتخاذ قرار التنظيف.
      safeToDelete: true,

      // لا نحدد أي عنصر تلقائيًا للحذف.
      selected: false,
    );
  }

  /// فحص مجلدات التخزين المؤقت التابعة للتطبيق.
  ///
  /// مهم:
  /// هذه الدالة لا تحذف أي ملف، وتعيد قائمة بالنتائج المكتشفة.
  Future<List<ScanItem>> scan({
    Function(String message)? onProgress,
  }) async {
    results.clear();
    _scannedRoots.clear();
    freedBytes = 0;

    onProgress?.call(
      'جارٍ تحديد مجلدات التخزين المؤقت الخاصة بالتطبيق...',
    );

    try {
      final directories = await _getCacheDirectories();

      for (int index = 0; index < directories.length; index++) {
        final directory = directories[index];
        final rootPath = _normalizePath(directory.path);

        // إنشاء معرّف داخلي لكل مجلد مكتشف.
        final id = 'app_cache_${index}_${p.basename(rootPath)}';

        onProgress?.call(
          'جارٍ فحص مجلد التخزين المؤقت ${index + 1}...',
        );

        final item = await _scanDirectory(
          directory: directory,
          id: id,
          title: 'App Cache ${index + 1}',
          onProgress: onProgress,
        );

        if (item == null) {
          continue;
        }

        results.add(item);

        // تسجيل المسار حتى لا نقبل مسارًا غير مكتشف أثناء الفحص.
        _scannedRoots[id] = rootPath;
      }

      onProgress?.call(
        'اكتمل الفحص. عدد الفئات المكتشفة: ${results.length}',
      );
    } catch (error) {
      onProgress?.call(
        'تعذر إكمال فحص التخزين المؤقت: $error',
      );
    }

    // إعادة نسخة غير قابلة للتعديل من القائمة المعادة.
    return List<ScanItem>.unmodifiable(results);
  }

  /// تنظيف العناصر التي اختارها المستخدم فقط.
  ///
  /// تعيد عدد الملفات التي حُذفت بنجاح.
  ///
  /// لا تضمن هذه الدالة حذف جميع الملفات؛ فقد تمنع صلاحيات النظام
  /// أو تغييرات الملفات أثناء العملية من إكمال بعض عمليات الحذف.
  Future<int> clean(
    List<ScanItem> items,
    Function(String message)? onStatus,
  ) async {
    int deletedFiles = 0;
    freedBytes = 0;

    onStatus?.call('بدء تنظيف العناصر المحددة...');

    // لا نعالج العناصر غير المحددة أو غير المؤهلة للتنظيف.
    final selectedItems = items
        .where((item) => item.selected && item.safeToDelete)
        .toList(growable: false);

    if (selectedItems.isEmpty) {
      onStatus?.call('لم يتم تحديد أي عناصر للتنظيف.');
      return 0;
    }

    // إعادة جلب المسارات المسموح بها حاليًا.
    final currentDirectories = await _getCacheDirectories();

    final allowedRoots = currentDirectories
        .map((directory) => _normalizePath(directory.path))
        .toSet();

    // منع معالجة المسار نفسه أكثر من مرة خلال هذه العملية.
    final processedRoots = <String>{};

    for (final item in selectedItems) {
      final scannedRoot = _scannedRoots[item.id];

      // يجب أن يكون العنصر قد اكتُشف في آخر عملية فحص.
      if (scannedRoot == null) {
        onStatus?.call(
          'تم تجاهل عنصر لم يسجله المنظف أثناء الفحص.',
        );
        continue;
      }

      final itemPath = _normalizePath(item.path);
      final normalizedRoot = _normalizePath(scannedRoot);

      // يجب أن يتطابق المسار مع المسار المسجل.
      if (itemPath != normalizedRoot) {
        onStatus?.call(
          'تم رفض عنصر بسبب عدم تطابق مساره مع المسار المسجل.',
        );
        continue;
      }

      // يجب أن يظل المجلد ضمن مجلدات التخزين المؤقت المعروفة.
      if (!allowedRoots.contains(normalizedRoot)) {
        onStatus?.call(
          'تم رفض المسار لأنه لم يعد ضمن مجلدات التخزين المؤقت المعروفة.',
        );
        continue;
      }

      // منع تكرار معالجة الجذر نفسه.
      if (!processedRoots.add(normalizedRoot)) {
        onStatus?.call(
          'تم تجاهل مجلد مكرر لتجنب تكرار عملية التنظيف.',
        );
        continue;
      }

      final directory = Directory(normalizedRoot);

      if (!await directory.exists()) {
        onStatus?.call(
          'المجلد المحدد لم يعد موجودًا.',
        );
        continue;
      }

      onStatus?.call(
        'جارٍ تنظيف مجلد التخزين المؤقت: ${p.basename(normalizedRoot)}',
      );

      try {
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) {
            continue;
          }

          final filePath = _normalizePath(entity.path);

          // لا نسمح بمعالجة ملف خارج الجذر المحدد.
          if (!p.isWithin(normalizedRoot, filePath)) {
            continue;
          }

          try {
            // نقرأ الحجم قبل الحذف، لكن لا نحتسبه إلا بعد نجاح الحذف.
            final size = await entity.length();

            await entity.delete();

            deletedFiles++;
            freedBytes += size;

            onStatus?.call(
              'تم حذف ملف بنجاح.',
            );
          } on FileSystemException catch (error) {
            onStatus?.call(
              'تعذر حذف أحد الملفات: ${error.message}',
            );
          } catch (error) {
            onStatus?.call(
              'حدث خطأ أثناء حذف أحد الملفات: $error',
            );
          }
        }
      } on FileSystemException catch (error) {
        onStatus?.call(
          'تعذر استعراض المجلد أثناء التنظيف: ${error.message}',
        );
      } catch (error) {
        onStatus?.call(
          'حدث خطأ أثناء تنظيف المجلد: $error',
        );
      }
    }

    onStatus?.call(
      'انتهى التنظيف. عدد الملفات المحذوفة بنجاح: $deletedFiles',
    );

    // نعيد العدد الفعلي للملفات التي نجح حذفها.
    return deletedFiles;
  }
}

// ============================================================================
// End of File
// Last Updated: 2026-10-10
// Version: 1.1.0
// ============================================================================
