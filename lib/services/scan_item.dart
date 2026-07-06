// ✅ تم تعديل الكلمة المفتاحية إلى حروف صغيرة (class) ليتعرف عليها الـ Compiler بنجاح
class ScanItem {
  final String id;
  final String title;
  final String path;
  final int files;
  final int bytes;
  final bool safeToDelete;
  final bool selected;

  const ScanItem({
    required this.id,
    required this.title,
    required this.path,
    required this.files,
    required this.bytes,
    this.safeToDelete = true,
    this.selected = true,
  });

  double get sizeKB => bytes / 1024;

  double get sizeMB => bytes / (1024 * 1024);

  double get sizeGB => bytes / (1024 * 1024 * 1024);

  String get readableSize {
    if (bytes < 1024) {
      return "$bytes B";
    }

    if (bytes < 1024 * 1024) {
      return "${sizeKB.toStringAsFixed(1)} KB";
    }

    if (bytes < 1024 * 1024 * 1024) {
      return "${sizeMB.toStringAsFixed(2)} MB";
    }

    return "${sizeGB.toStringAsFixed(2)} GB";
  }

  // تحديث الدالة لتصبح مرنة وتدعم تعديل أي حقل عند الحاجة
  ScanItem copyWith({
    String? id,
    String? title,
    String? path,
    int? files,
    int? bytes,
    bool? safeToDelete,
    bool? selected,
  }) {
    return ScanItem(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      files: files ?? this.files,
      bytes: bytes ?? this.bytes,
      safeToDelete: safeToDelete ?? this.safeToDelete,
      selected: selected ?? this.selected,
    );
  }
}
