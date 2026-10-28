// ============================================================================
// Project      : AI Cleaner
// File         : lib/services/scan_item.dart
// Version      : 1.1.0
// Last Updated : 2026-10-10
// Purpose      : تعريف نموذج بيانات موحد لنتائج فحص الملفات، بما يشمل بيانات
//                الفئة والمسار وعدد الملفات والحجم وحالة الأمان والتحديد.
// ----------------------------------------------------------------------------
// Changes in v1.1.0:
// - إضافة ترويسة موحدة وتوثيق عربي.
// - تحسين توثيق الحقول والدوال.
// - جعل التحديد الافتراضي false لتجنب تحديد الملفات للحذف تلقائيًا.
// - الحفاظ على أسماء الحقول والخصائص ودالة copyWith للتوافق مع المشروع.
// ----------------------------------------------------------------------------
// Safety Notes:
// - safeToDelete مؤشر يحدده المستدعي، وليس ضمانًا بأن الملف غير مهم.
// - يجب التحقق من المسار والصلاحيات قبل تنفيذ الحذف الفعلي.
// - يجب أن تعرض الواجهة الملفات المحددة بوضوح قبل تأكيد التنظيف.
// ----------------------------------------------------------------------------
// Dependencies:
// - لا توجد مكتبات خارجية؛ يعتمد على Dart الأساسي فقط.
// ----------------------------------------------------------------------------
// Compatibility:
// - يحافظ على الحقول: id, title, path, files, bytes,
//   safeToDelete, selected.
// - يحافظ على sizeKB وsizeMB وsizeGB وreadableSize وcopyWith.
// - لم يُنفّذ بناء Flutter أو اختبار آلي ضمن هذه المراجعة.
// ============================================================================

/// نموذج بيانات يمثل فئة أو عنصرًا ضمن نتائج فحص الملفات.
class ScanItem {
  /// معرّف ثابت للفئة داخل عملية الفحص.
  final String id;

  /// الاسم المعروض للمستخدم في الواجهة.
  final String title;

  /// مسار العنصر أو معرّف فئته، بحسب مصدر نتيجة الفحص.
  final String path;

  /// عدد الملفات المكتشفة ضمن العنصر.
  final int files;

  /// إجمالي أحجام الملفات بالبايت.
  final int bytes;

  /// يحدد ما إذا كان المستدعي يعتبر العنصر مرشحًا للحذف.
  ///
  /// هذه القيمة وحدها لا تضمن سلامة الحذف؛ يجب التحقق من الملفات
  /// والمسارات الفعلية داخل خدمة التنظيف.
  final bool safeToDelete;

  /// يحدد ما إذا اختار المستخدم فئة تحتوي على ملفات محددة يدويًا.
  final bool selected;

  /// المسارات الفردية التي اختارها المستخدم صراحةً داخل هذه الفئة.
  /// لا يُسمح بحذف الفئة كاملة عند ترك هذه القائمة فارغة.
  final List<String> selectedPaths;

  /// إنشاء عنصر جديد ضمن نتائج الفحص.
  const ScanItem({
    required this.id,
    required this.title,
    required this.path,
    required this.files,
    required this.bytes,
    this.safeToDelete = true,
    this.selected = false,
    this.selectedPaths = const <String>[],
  });

  /// الحجم بالكيلوبايت.
  double get sizeKB => bytes / 1024;

  /// الحجم بالميغابايت.
  double get sizeMB => bytes / (1024 * 1024);

  /// الحجم بالغيغابايت.
  double get sizeGB => bytes / (1024 * 1024 * 1024);

  /// إرجاع الحجم بصيغة مقروءة.
  ///
  /// أمثلة: 500 B، و1.5 KB، و2.25 MB، و1.20 GB.
  String get readableSize {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${sizeKB.toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${sizeMB.toStringAsFixed(2)} MB';
    }

    return '${sizeGB.toStringAsFixed(2)} GB';
  }

  /// إنشاء نسخة جديدة مع إمكانية تعديل الحقول المطلوبة فقط.
  ///
  /// الحقول التي لا تُمرر تحتفظ بقيم النسخة الحالية.
  ScanItem copyWith({
    String? id,
    String? title,
    String? path,
    int? files,
    int? bytes,
    bool? safeToDelete,
    bool? selected,
    List<String>? selectedPaths,
  }) {
    return ScanItem(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      files: files ?? this.files,
      bytes: bytes ?? this.bytes,
      safeToDelete: safeToDelete ?? this.safeToDelete,
      selected: selected ?? this.selected,
      selectedPaths: selectedPaths ?? this.selectedPaths,
    );
  }
}
