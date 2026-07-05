import 'models/scan_item.dart';
import 'plugins/thumbnail_cleaner.dart';

class CleanerEngine {
  final ThumbnailCleaner _thumbnailCleaner = ThumbnailCleaner();

  /// جميع النتائج
  final List<ScanItem> _results = [];

  List<ScanItem> get results => List.unmodifiable(_results);

  /// إجمالي الملفات
  int get totalFiles =>
      _results.fold(0, (sum, item) => sum + item.files);

  /// إجمالي الحجم
  int get totalBytes =>
      _results.fold(0, (sum, item) => sum + item.bytes);

  /// عدد العناصر المكتشفة
  int get totalItems => _results.length;

  /// بدء الفحص
  Future<List<ScanItem>> scan({

    Function(String message)? onStatus,

    Function(double progress)? onProgress,

  }) async {

    _results.clear();

    onStatus?.call("Scanning Thumbnail Cache...");
    onProgress?.call(0.10);

    final thumbnails = await _thumbnailCleaner.scan(
      onProgress: onStatus,
    );

    _results.addAll(thumbnails);

    onProgress?.call(1.0);

    return results;
  }

  /// بدء التنظيف
  Future<int> clean({

    required List<ScanItem> selected,

    Function(String message)? onStatus,

  }) async {

    int deleted = 0;

    final thumbnails = selected
        .where((e) => e.title == "Thumbnail Cache")
        .toList();

    if (thumbnails.isNotEmpty) {

      onStatus?.call("Cleaning Thumbnail Cache...");

      deleted += await _thumbnailCleaner.clean(
        thumbnails,
        onStatus,
      );
    }

    return deleted;
  }
}
