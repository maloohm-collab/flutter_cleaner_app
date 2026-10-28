/// Conservative file classification rules for the AI Optimizer scanner.
///
/// These rules only identify candidates. They do not prove that a file is
/// safe to delete; every candidate must be inspected and explicitly approved.
class CleanupRules {
  CleanupRules._();

  static const String defaultStorageRoot = '/storage/emulated/0';

  static const List<String> temporaryExtensions = <String>[
    '.tmp',
    '.temp',
  ];

  static const Set<String> thumbnailImageExtensions = <String>{
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif',
    '.avif', '.tif', '.tiff',
  };

  /// Checks that a path is inside the shared-storage root and excludes
  /// Android private app data and expansion-data folders.
  static bool isAllowedPath(
    String path, {
    String storageRoot = defaultStorageRoot,
  }) {
    final String normalized = _normalize(path);
    final String root = _normalize(storageRoot);
    final String lowerPath = normalized.toLowerCase();
    final String lowerRoot = root.toLowerCase();

    if (normalized.isEmpty ||
        lowerPath.split('/').any((segment) => segment == '..')) {
      return false;
    }

    if (lowerPath != lowerRoot &&
        !lowerPath.startsWith('$lowerRoot/')) {
      return false;
    }

    final List<String> segments = lowerPath.split('/');
    for (int i = 0; i < segments.length - 1; i++) {
      if (segments[i] == 'android' &&
          (segments[i + 1] == 'data' ||
              segments[i + 1] == 'obb')) {
        return false;
      }
    }

    return true;
  }

  /// Returns a category ID only for narrowly defined candidate patterns.
  ///
  /// Thumbnail files are considered only inside an exact ".thumbnails"
  /// directory and only when the file extension is an image format.
  /// Broad filename matching (e.g. any file containing "thumb") is avoided.
  static String? classify(
    String path, {
    String storageRoot = defaultStorageRoot,
  }) {
    final String normalized = _normalize(path);
    if (!isAllowedPath(normalized, storageRoot: storageRoot)) {
      return null;
    }

    final List<String> segments = normalized.toLowerCase().split('/');
    if (segments.isEmpty) return null;

    final String fileName = segments.last;
    final int dot = fileName.lastIndexOf('.');
    final String extension = dot > 0 ? fileName.substring(dot) : '';

    if (segments.take(segments.length - 1).contains('.thumbnails') &&
        thumbnailImageExtensions.contains(extension)) {
      return 'thumbnail_files';
    }

    if (temporaryExtensions.any(fileName.endsWith)) {
      return 'temporary_files';
    }

    return null;
  }

  static String _normalize(String path) {
    String normalized = path.trim().replaceAll(String.fromCharCode(92), '/');
    while (normalized.contains('//')) {
      normalized = normalized.replaceAll('//', '/');
    }
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
