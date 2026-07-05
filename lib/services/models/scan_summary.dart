import 'scan_item.dart';

class ScanSummary {
  final List<ScanItem> items;

  final Duration duration;

  final int deletedFiles;

  final int totalFiles;

  final int totalBytes;

  const ScanSummary({
    required this.items,
    required this.duration,
    required this.deletedFiles,
    required this.totalFiles,
    required this.totalBytes,
  });

  String get readableSize {
    if (totalBytes < 1024) {
      return "$totalBytes B";
    }

    if (totalBytes < 1024 * 1024) {
      return "${(totalBytes / 1024).toStringAsFixed(1)} KB";
    }

    if (totalBytes < 1024 * 1024 * 1024) {
      return "${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB";
    }

    return "${(totalBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }

  double get healthScore {
    if (totalBytes == 0) {
      return 100;
    }

    if (totalBytes < 50 * 1024 * 1024) {
      return 98;
    }

    if (totalBytes < 200 * 1024 * 1024) {
      return 94;
    }

    if (totalBytes < 500 * 1024 * 1024) {
      return 88;
    }

    if (totalBytes < 1024 * 1024 * 1024) {
      return 80;
    }

    return 70;
  }

  String get healthText {
    if (healthScore >= 95) {
      return "Excellent";
    }

    if (healthScore >= 90) {
      return "Very Good";
    }

    if (healthScore >= 80) {
      return "Good";
    }

    if (healthScore >= 70) {
      return "Needs Optimization";
    }

    return "Poor";
  }
}
