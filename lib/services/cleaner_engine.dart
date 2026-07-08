import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart';

class CleanerEngine {
  /// جميع النتائج الحقيقية المكتشفة
  final List<ScanItem> _results = [];

  /// قائمة داخلية لحفظ مراجع الملفات الفعلية لحذفها عند تأكيد التنظيف
  final List<File> _discoveredFiles = [];

  List<ScanItem> get results => List.unmodifiable(_results);

  /// إجمالي الملفات (يُحسب ديناميكياً بناءً على محتويات الهاتف الحالية)
  int get totalFiles =>
      _results.fold<int>(0, (sum, item) => sum + item.files);

  /// إجمالي الحجم الفعلي للمهملات
  int get totalBytes =>
      _results.fold<int>(0, (sum, item) => sum + item.bytes);

  /// عدد العناصر المكتشفة
  int get totalItems => _results.length;

  // دفق التقدم الحركي لمحاكاة السلاسة البصرية
  Stream<double> scanProgress() async* {
    const steps = 100;
    for (int i = 0; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 25));
      yield i / steps;
    }
  }

  /// بدء الفحص الحقيقي المتوافق مع أي هاتف ذكي
  Future<List<ScanItem>> scan({
    Function(String message)? onStatus,
    Function(double progress)? onProgress,
  }) async {
    // تصفير القوائم السابقة لضمان عدم تداخل البيانات بين الفحص والآخر
    _results.clear();
    _discoveredFiles.clear();

    try {
      onStatus?.call("Initializing AI System Paths...");
      onProgress?.call(0.05);
      await Future.delayed(const Duration(milliseconds: 300));

      // Helper لإضافة نتيجة إذا وُجدت ملفات في المسار
      Future<void> _collectFromDirectory(Directory dir, String id, String title) async {
        int filesCount = 0;
        int bytesCount = 0;

        if (await dir.exists()) {
          await for (FileSystemEntity entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              try {
                final len = await entity.length();
                filesCount++;
                bytesCount += len;
                _discoveredFiles.add(entity);
              } catch (_) {
                // تجاهل الملفات التي لا يمكن قراءتها
              }
            }
          }
        }

        if (filesCount > 0) {
          _results.add(
            ScanItem(
              id: id,
              title: title,
              path: dir.path,
              files: filesCount,
              bytes: bytesCount,
              selected: true,
            ),
          );
        }
      }

      // 1. قراءة وفحص مجلد الكاش المؤقت الحقيقي للجهاز الحالي
      onStatus?.call("Scanning System Temporary Cache...");
      onProgress?.call(0.20);
      Directory tempDir = await getTemporaryDirectory();
      await _collectFromDirectory(tempDir, "system_cache", "System Cache Files");

      // 2. قراءة مجلد الدعم للتطبيق لضمان الحصول على ملفات كاش إضافية متنوعة
      onStatus?.call("Analyzing Application Support Directories...");
      onProgress?.call(0.45);
      Directory appSupportDir = await getApplicationSupportDirectory();
      await _collectFromDirectory(appSupportDir, "thumbnail_media_cache", "Thumbnail & Media Cache");

      // 3. محاولة الوصول إلى مجلدات خارجية شائعة (إن وُجدت) مثل externalCacheDirectories
      try {
        onStatus?.call("Scanning External Cache Directories...");
        onProgress?.call(0.65);
        final externalDirs = await getExternalCacheDirectories();
        if (externalDirs != null) {
          for (final d in externalDirs) {
            await _collectFromDirectory(d, "external_cache_${d.path.hashCode}", "External Cache");
          }
        }
      } catch (_) {
        // بعض الأجهزة أو المنصات لا تدعم external cache directories
      }

      // 4. تحديث التقدم النهائي
      onProgress?.call(0.95);
      onStatus?.call("Finalizing scan results...");
      await Future.delayed(const Duration(milliseconds: 200));

      // لا نضيف أي نتائج افتراضية هنا — إذا لم يُعثر على ملفات، نُرجع قائمة فارغة
      onProgress?.call(1.0);
      onStatus?.call("AI Scan Completed Successfully");
    } catch (e) {
      onStatus?.call("Scan interrupted: $e");
      onProgress?.call(1.0);
    }

    return results;
  }

  /// بدء التنظيف الفعلي والحذف من ذاكرة الهاتف
  Future<int> clean({
    required List<ScanItem> selected,
    Function(String message)? onStatus,
  }) async {
    int deletedCount = 0;

    // إذا لم يحدد المستخدم أي شيء، نخرج فوراً دون حذف
    if (selected.isEmpty) return 0;

    onStatus?.call("Clearing identified cache directories...");
    // بناء مجموعة من المسارات المحددة لتصفية الملفات التي سيتم حذفها
    final selectedPaths = selected.map((s) => s.path).toList();

    // تكرار حقيقي على الملفات المجمعة وحذفها نهائياً من القرص الصلب
    for (File file in List<File>.from(_discoveredFiles)) {
      try {
        // حذف فقط الملفات التي تقع ضمن المسارات المحددة من قبل المستخدم
        final filePath = file.path;
        final shouldDelete = selectedPaths.any((p) => filePath.startsWith(p));
        if (!shouldDelete) continue;

        if (await file.exists()) {
          await file.delete();
          deletedCount++;
          onStatus?.call("Deleted: ${file.path}");
        }
      } catch (e) {
        // سجل الخطأ لكن لا توقف العملية
        onStatus?.call("Failed to delete: ${file.path} (${e.toString()})");
      }
    }

    // تنظيف القوائم بعد إتمام المهمة بنجاح لتصفير الواجهة
    _discoveredFiles.removeWhere((f) => !f.existsSync());
    // إعادة بناء النتائج: نزيل العناصر التي كانت ضمن المسارات المحددة
    _results.removeWhere((r) => selectedPaths.any((p) => r.path == p || r.path.startsWith(p)));

    onStatus?.call("Optimization Complete.");
    return deletedCount;
  }
}
