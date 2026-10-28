import 'dart:async';
import 'dart:io';

/// A confirmed set of byte-for-byte identical files.
///
/// This scanner is read-only. It never deletes, renames, or modifies files.
class DuplicateFileGroup {
  final int bytes;
  final List<String> paths;

  const DuplicateFileGroup({
    required this.bytes,
    required this.paths,
  });

  int get duplicateCount => paths.length;
  int get reclaimableBytes => bytes * (paths.length - 1);
}

class DuplicateFileScanner {
  final String _storageRoot;

  DuplicateFileScanner({String storageRoot = '/storage/emulated/0'})
      : _storageRoot = _normalizePath(storageRoot);

  static String _normalizePath(String path) =>
      path.trim().replaceAll(r'\\', '/').replaceAll(RegExp(r'/+'), '/').replaceFirst(RegExp(r'/

  /// Finds exact duplicates among readable files under shared storage.
  ///
  /// Candidates are grouped by size first, then compared byte-for-byte using
  /// bounded buffers. Matching names or matching sizes alone never count as
  /// duplicates. Android/data and Android/obb are excluded.
  Future<List<DuplicateFileGroup>> scan({
    void Function(String message)? onStatus,
    bool Function()? shouldCancel,
  }) async {
    final root = Directory(_storageRoot);
    if (!await root.exists()) return const <DuplicateFileGroup>[];

    final Map<int, List<File>> candidatesBySize = <int, List<File>>{};
    final List<Directory> queue = <Directory>[root];
    var visited = 0;

    onStatus?.call('جارٍ جمع الملفات المتاحة للقراءة...');

    while (queue.isNotEmpty) {
      if (shouldCancel?.call() ?? false) break;
      final directory = queue.removeLast();
      if (!_isAllowedPath(directory.path)) continue;

      try {
        await for (final entity in directory.list(
          recursive: false,
          followLinks: false,
        )) {
          if (shouldCancel?.call() ?? false) break;
          if (entity is Link) continue;
          if (entity is Directory) {
            if (_isAllowedPath(entity.path)) queue.add(entity);
            continue;
          }
          if (entity is! File || !_isAllowedPath(entity.path)) continue;

          try {
            final type = await FileSystemEntity.type(
              entity.path,
              followLinks: false,
            );
            if (type != FileSystemEntityType.file) continue;
            final size = await entity.length();
            candidatesBySize.putIfAbsent(size, () => <File>[]).add(entity);
            visited++;
          } on FileSystemException {
            // The file may be inaccessible or may disappear during scanning.
          }
        }
      } on FileSystemException {
        // Continue with other readable directories.
      }
    }

    final groups = <DuplicateFileGroup>[];
    var compared = 0;
    onStatus?.call('تم جمع $visited ملفًا؛ جارٍ التحقق من التطابق الفعلي...');

    for (final entry in candidatesBySize.entries) {
      if (shouldCancel?.call() ?? false) break;
      final files = entry.value;
      if (files.length < 2) continue;

      // Keep one representative per confirmed content group.
      final representatives = <File>[];
      final members = <File, List<File>>{};

      for (final candidate in files) {
        if (shouldCancel?.call() ?? false) break;
        var matched = false;
        for (final representative in representatives) {
          try {
            compared++;
            if (await _sameContents(candidate, representative)) {
              members[representative]!.add(candidate);
              matched = true;
              break;
            }
          } on FileSystemException {
            // Inaccessible candidates are not reported as duplicates.
          }
        }
        if (!matched) {
          representatives.add(candidate);
          members[candidate] = <File>[candidate];
        }
      }

      for (final groupFiles in members.values) {
        if (groupFiles.length < 2) continue;
        groups.add(DuplicateFileGroup(
          bytes: entry.key,
          paths: List<String>.unmodifiable(
            groupFiles.map((file) => file.path),
          ),
        ));
      }
    }

    groups.sort((a, b) => b.reclaimableBytes.compareTo(a.reclaimableBytes));
    onStatus?.call('اكتمل التحقق من الملفات المتطابقة. تمت مقارنة $compared زوجًا من الملفات.');
    return List<DuplicateFileGroup>.unmodifiable(groups);
  }

  Future<bool> _sameContents(File first, File second) async {
    if (first.path == second.path) return true;
    if (await first.length() != await second.length()) return false;

    final firstType = await FileSystemEntity.type(first.path, followLinks: false);
    final secondType = await FileSystemEntity.type(second.path, followLinks: false);
    if (firstType != FileSystemEntityType.file ||
        secondType != FileSystemEntityType.file) {
      return false;
    }

    final firstIterator = StreamIterator<List<int>>(
      first.openRead().map((chunk) => chunk),
    );
    final secondIterator = StreamIterator<List<int>>(
      second.openRead().map((chunk) => chunk),
    );

    try {
      var firstChunk = <int>[];
      var secondChunk = <int>[];
      var firstOffset = 0;
      var secondOffset = 0;

      while (true) {
        if (firstOffset >= firstChunk.length) {
          if (!await firstIterator.moveNext()) {
            if (secondOffset >= secondChunk.length) {
              final hasMoreSecond = await secondIterator.moveNext();
              return !hasMoreSecond;
            }
            return false;
          }
          firstChunk = firstIterator.current;
          firstOffset = 0;
        }

        if (secondOffset >= secondChunk.length) {
          if (!await secondIterator.moveNext()) return false;
          secondChunk = secondIterator.current;
          secondOffset = 0;
        }

        final availableFirst = firstChunk.length - firstOffset;
        final availableSecond = secondChunk.length - secondOffset;
        final count = availableFirst < availableSecond
            ? availableFirst
            : availableSecond;

        for (var i = 0; i < count; i++) {
          if (firstChunk[firstOffset + i] !=
              secondChunk[secondOffset + i]) {
            return false;
          }
        }
        firstOffset += count;
        secondOffset += count;
      }
    } finally {
      await firstIterator.cancel();
      await secondIterator.cancel();
    }
  }

  bool _isAllowedPath(String rawPath) {
    final path = rawPath.trim().replaceAll(r'\\', '/');
    final normalized = path.replaceAll(RegExp(r'/+'), '/');
    if (normalized != _storageRoot &&
        !normalized.startsWith('$_storageRoot/')) {
      return false;
    }

    final segments = normalized.split('/');
    if (segments.contains('..')) return false;

    final lower = normalized.toLowerCase();
    if (lower == '$_storageRoot/android/data' ||
        lower.startsWith('$_storageRoot/android/data/')) {
      return false;
    }
    if (lower == '$_storageRoot/android/obb' ||
        lower.startsWith('$_storageRoot/android/obb/')) {
      return false;
    }
    return true;
  }
}
), '');

  /// Finds exact duplicates among readable files under shared storage.
  ///
  /// Candidates are grouped by size first, then compared byte-for-byte using
  /// bounded buffers. Matching names or matching sizes alone never count as
  /// duplicates. Android/data and Android/obb are excluded.
  Future<List<DuplicateFileGroup>> scan({
    void Function(String message)? onStatus,
    bool Function()? shouldCancel,
  }) async {
    final root = Directory(_storageRoot);
    if (!await root.exists()) return const <DuplicateFileGroup>[];

    final Map<int, List<File>> candidatesBySize = <int, List<File>>{};
    final List<Directory> queue = <Directory>[root];
    var visited = 0;

    onStatus?.call('جارٍ جمع الملفات المتاحة للقراءة...');

    while (queue.isNotEmpty) {
      if (shouldCancel?.call() ?? false) break;
      final directory = queue.removeLast();
      if (!_isAllowedPath(directory.path)) continue;

      try {
        await for (final entity in directory.list(
          recursive: false,
          followLinks: false,
        )) {
          if (shouldCancel?.call() ?? false) break;
          if (entity is Link) continue;
          if (entity is Directory) {
            if (_isAllowedPath(entity.path)) queue.add(entity);
            continue;
          }
          if (entity is! File || !_isAllowedPath(entity.path)) continue;

          try {
            final type = await FileSystemEntity.type(
              entity.path,
              followLinks: false,
            );
            if (type != FileSystemEntityType.file) continue;
            final size = await entity.length();
            candidatesBySize.putIfAbsent(size, () => <File>[]).add(entity);
            visited++;
          } on FileSystemException {
            // The file may be inaccessible or may disappear during scanning.
          }
        }
      } on FileSystemException {
        // Continue with other readable directories.
      }
    }

    final groups = <DuplicateFileGroup>[];
    var compared = 0;
    onStatus?.call('تم جمع $visited ملفًا؛ جارٍ التحقق من التطابق الفعلي...');

    for (final entry in candidatesBySize.entries) {
      if (shouldCancel?.call() ?? false) break;
      final files = entry.value;
      if (files.length < 2) continue;

      // Keep one representative per confirmed content group.
      final representatives = <File>[];
      final members = <File, List<File>>{};

      for (final candidate in files) {
        if (shouldCancel?.call() ?? false) break;
        var matched = false;
        for (final representative in representatives) {
          try {
            compared++;
            if (await _sameContents(candidate, representative)) {
              members[representative]!.add(candidate);
              matched = true;
              break;
            }
          } on FileSystemException {
            // Inaccessible candidates are not reported as duplicates.
          }
        }
        if (!matched) {
          representatives.add(candidate);
          members[candidate] = <File>[candidate];
        }
      }

      for (final groupFiles in members.values) {
        if (groupFiles.length < 2) continue;
        groups.add(DuplicateFileGroup(
          bytes: entry.key,
          paths: List<String>.unmodifiable(
            groupFiles.map((file) => file.path),
          ),
        ));
      }
    }

    groups.sort((a, b) => b.reclaimableBytes.compareTo(a.reclaimableBytes));
    onStatus?.call('اكتمل التحقق من الملفات المتطابقة. تمت مقارنة $compared زوجًا من الملفات.');
    return List<DuplicateFileGroup>.unmodifiable(groups);
  }

  Future<bool> _sameContents(File first, File second) async {
    if (first.path == second.path) return true;
    if (await first.length() != await second.length()) return false;

    final firstType = await FileSystemEntity.type(first.path, followLinks: false);
    final secondType = await FileSystemEntity.type(second.path, followLinks: false);
    if (firstType != FileSystemEntityType.file ||
        secondType != FileSystemEntityType.file) {
      return false;
    }

    final firstIterator = StreamIterator<List<int>>(
      first.openRead().map((chunk) => chunk),
    );
    final secondIterator = StreamIterator<List<int>>(
      second.openRead().map((chunk) => chunk),
    );

    try {
      var firstChunk = <int>[];
      var secondChunk = <int>[];
      var firstOffset = 0;
      var secondOffset = 0;

      while (true) {
        if (firstOffset >= firstChunk.length) {
          if (!await firstIterator.moveNext()) {
            if (secondOffset >= secondChunk.length) {
              final hasMoreSecond = await secondIterator.moveNext();
              return !hasMoreSecond;
            }
            return false;
          }
          firstChunk = firstIterator.current;
          firstOffset = 0;
        }

        if (secondOffset >= secondChunk.length) {
          if (!await secondIterator.moveNext()) return false;
          secondChunk = secondIterator.current;
          secondOffset = 0;
        }

        final availableFirst = firstChunk.length - firstOffset;
        final availableSecond = secondChunk.length - secondOffset;
        final count = availableFirst < availableSecond
            ? availableFirst
            : availableSecond;

        for (var i = 0; i < count; i++) {
          if (firstChunk[firstOffset + i] !=
              secondChunk[secondOffset + i]) {
            return false;
          }
        }
        firstOffset += count;
        secondOffset += count;
      }
    } finally {
      await firstIterator.cancel();
      await secondIterator.cancel();
    }
  }

  bool _isAllowedPath(String rawPath) {
    final path = rawPath.trim().replaceAll(r'\\', '/');
    final normalized = path.replaceAll(RegExp(r'/+'), '/');
    if (normalized != _storageRoot &&
        !normalized.startsWith('$_storageRoot/')) {
      return false;
    }

    final segments = normalized.split('/');
    if (segments.contains('..')) return false;

    final lower = normalized.toLowerCase();
    if (lower == '$_storageRoot/android/data' ||
        lower.startsWith('$_storageRoot/android/data/')) {
      return false;
    }
    if (lower == '$_storageRoot/android/obb' ||
        lower.startsWith('$_storageRoot/android/obb/')) {
      return false;
    }
    return true;
  }
}
