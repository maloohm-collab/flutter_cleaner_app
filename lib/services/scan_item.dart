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

  ScanItem copyWith({
    bool? selected,
  }) {
    return ScanItem(
      id: id,
      title: title,
      path: path,
      files: files,
      bytes: bytes,
      safeToDelete: safeToDelete,
      selected: selected ?? this.selected,
    );
  }
}
