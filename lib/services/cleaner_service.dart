// ============================================================================
// Project      : AI Cleaner
// File         : lib/services/cleaner_service.dart
// Version      : 1.1.0
// Last Updated : 2026-10-10
// Purpose      : توفير واجهة متوافقة لطلب صلاحية التخزين ومتابعة إحصاءات
//                الفحص، دون حذف الملفات تلقائيًا أثناء استعراض المجلدات.
// ----------------------------------------------------------------------------
// Changes in v1.1.0:
// - منع حذف الملفات تلقائيًا أثناء الفحص.
// - إزالة التعامل مع كل مجلد يحتوي اسمه على thumbnails باعتباره آمنًا للحذف.
// - تحسين التعامل مع أخطاء الوصول إلى المجلدات والملفات.
// - المحافظة على requestPermission وstartCleaning وformattedSize.
// - توضيح أن هذه الخدمة لا تستبدل CleanerEngine في عملية التنظيف.
// ----------------------------------------------------------------------------
// Safety Notes:
// - startCleaning في هذه النسخة تفحص الملفات وتحسب إحصاءاتها فقط.
// - لا تحذف هذه الخدمة الملفات ولا تدّعي تحرير مساحة فعلية.
// - صلاحية MANAGE_EXTERNAL_STORAGE صلاحية واسعة ويجب استخدامها عند الحاجة
//   وبما يتوافق مع سياسات Android وGoogle Play.
// - لا يضمن منح الصلاحية إمكانية الوصول إلى جميع المسارات على كل جهاز.
// ----------------------------------------------------------------------------
// Dependencies:
// - dart:io
// - permission_handler
// ----------------------------------------------------------------------------
// Compatibility:
// - يحافظ على CleanerService وحقول الإحصاءات الأساسية.
// - يحافظ على requestPermission وstartCleaning وformattedSize.
// - قد تختلف دلالة startCleaning عن النسخة القديمة؛ أصبحت عملية فحص آمنة فقط.
// - لم يُنفّذ بناء Flutter أو اختبار على جهاز فعلي ضمن هذه المراجعة.
// ============================================================================

import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;

import 'package:permission_handler/permission_handler.dart';

/// خدمة مساعدة لفحص ملفات التخزين المشتركة.
///
/// لا تنفذ هذه الخدمة حذفًا للملفات.
/// استخدم CleanerEngine لتنفيذ عملية تنظيف مبنية على نتائج فحص واختيار المستخدم.
class CleanerService {
  /// عدد الملفات التي حُذفت خلال هذه الخدمة.
  ///
  /// يبقى صفرًا لأن هذه الخدمة لا تنفذ الحذف.
  int deletedFiles = 0;

  /// عدد المجلدات التي تمت محاولة فحصها.
  int scannedFolders = 0;

  /// عدد الملفات التي تمت مواجهتها أثناء الفحص.
  int scannedFiles = 0;

  /// عدد البايتات التي تم تحريرها فعليًا.
  ///
  /// يبقى صفرًا لأن الخدمة لا تحذف الملفات.
  int freedBytes = 0;

  static const String _storageRootPath = '/storage/emulated/0';

  /// طلب صلاحية إدارة التخزين الخارجي على Android.
  ///
  /// قد لا تكون هذه الصلاحية مطلوبة لكل وظائف التطبيق.
  /// يجب شرح سبب الحاجة إليها للمستخدم قبل الطلب.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final PermissionStatus status =
          await Permission.manageExternalStorage.request();

      return status.isGranted;
    } on PlatformException {
      return false;
    }
  }

  /// فحص إحصاءات التخزين دون حذف الملفات.
  ///
  /// [onLog] يستقبل رسائل الحالة.
  /// [onUpdate] يُستدعى عند تحديث الإحصاءات.
  ///
  /// ملاحظة مهمة:
  /// احتُفظ باسم الدالة لتقليل تغييرات الاستدعاءات الحالية، لكن هذه النسخة
  /// لا تنظف الملفات. لا تعتبر انتهاء الدالة دليلًا على تحرير مساحة.
  Future<void> startCleaning({
    required Function(String message) onLog,
    required Function() onUpdate,
  }) async {
    deletedFiles = 0;
    scannedFolders = 0;
    scannedFiles = 0;
    freedBytes = 0;

    onUpdate();

    if (!Platform.isAndroid) {
      onLog('هذه الخدمة مخصصة لفحص التخزين على Android.');
      return;
    }

    final Directory root = Directory(_storageRootPath);

    try {
      if (!await root.exists()) {
        onLog('مجلد التخزين المشترك غير متاح.');
        return;
      }

      onLog('بدء فحص الملفات دون حذفها.');
      await _scanDirectory(root, onLog, onUpdate);

      onLog(
        'اكتمل الفحص: '
        '$scannedFiles ملف، '
        '$scannedFolders مجلد. '
        'لم يتم حذف أي ملف.',
      );
    } on FileSystemException {
      onLog('تعذر الوصول إلى التخزين المشترك.');
    } finally {
      onUpdate();
    }
  }

  /// استعراض المجلدات بطريقة تكرارية دون حذف أي ملف.
  Future<void> _scanDirectory(
    Directory directory,
    Function(String) onLog,
    Function() onUpdate,
  ) async {
    final List<Directory> pendingDirectories = <Directory>[directory];

    while (pendingDirectories.isNotEmpty) {
      final Directory current = pendingDirectories.removeLast();

      if (!_isAllowedPath(current.path)) {
        continue;
      }

      try {
        scannedFolders++;
        onUpdate();

        await for (final FileSystemEntity entity in current.list(
          recursive: false,
          followLinks: false,
        )) {
          if (entity is Link) {
            continue;
          }

          if (entity is Directory) {
            if (_isAllowedPath(entity.path)) {
              pendingDirectories.add(entity);
            }
            continue;
          }

          if (entity is File) {
            scannedFiles++;
          }

          // لا توجد أي عملية delete هنا عمدًا.
        }
      } on FileSystemException {
        // تجاوز المجلدات التي لا يمكن الوصول إليها.
        onLog('تم تجاوز مجلد يتعذر الوصول إليه.');
      }

      // تحديث الواجهة بعد كل مجلد بدل تحديثها مع كل ملف.
      onUpdate();
    }
  }

  /// التأكد من أن المسار يقع داخل التخزين المشترك،
  /// مع استبعاد Android/data وAndroid/obb.
  bool _isAllowedPath(String path) {
    final String normalized =
        path.replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');

    final String lowerPath = normalized.toLowerCase();
    const String root = _storageRootPath;

    if (lowerPath != root && !lowerPath.startsWith('$root/')) {
      return false;
    }

    final String relativePath =
        lowerPath == root ? '' : lowerPath.substring(root.length + 1);

    final List<String> segments = relativePath.split('/');

    if (segments.length >= 2 &&
        segments[0] == 'android' &&
        (segments[1] == 'data' || segments[1] == 'obb')) {
      return false;
    }

    return true;
  }

  /// الحجم الذي تم تحريره فعليًا بصيغة مقروءة.
  ///
  /// في هذه الخدمة سيظهر صفرًا لأنها لا تحذف الملفات.
  String get formattedSize {
    if (freedBytes < 1024) {
      return '$freedBytes B';
    }

    if (freedBytes < 1024 * 1024) {
      return '${(freedBytes / 1024).toStringAsFixed(1)} KB';
    }

    if (freedBytes < 1024 * 1024 * 1024) {
      return '${(freedBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    return '${(freedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
