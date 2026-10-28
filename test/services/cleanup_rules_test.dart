import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleaner_app/services/cleanup_rules.dart';

void main() {
  group('CleanupRules.isAllowedPath', () {
    test('allows files within shared storage', () {
      expect(
        CleanupRules.isAllowedPath('/storage/emulated/0/Download/sample.tmp'),
        isTrue,
      );
    });

    test('rejects paths outside shared storage', () {
      expect(CleanupRules.isAllowedPath('/data/user/0/app/cache.tmp'), isFalse);
      expect(CleanupRules.isAllowedPath('/storage/emulated/00/file.tmp'), isFalse);
    });

    test('rejects Android data and obb directories case-insensitively', () {
      expect(
        CleanupRules.isAllowedPath('/storage/emulated/0/Android/data/app/cache.tmp'),
        isFalse,
      );
      expect(
        CleanupRules.isAllowedPath('/storage/emulated/0/Android/OBB/app/file.tmp'),
        isFalse,
      );
    });

    test('rejects traversal segments', () {
      expect(
        CleanupRules.isAllowedPath('/storage/emulated/0/Download/../DCIM/file.tmp'),
        isFalse,
      );
    });
  });

  group('CleanupRules.classify', () {
    test('classifies only configured temporary extensions', () {
      expect(
        CleanupRules.classify('/storage/emulated/0/Download/SESSION.TMP'),
        'temporary_files',
      );
      expect(
        CleanupRules.classify('/storage/emulated/0/Download/cache.temp'),
        'temporary_files',
      );
      expect(
        CleanupRules.classify('/storage/emulated/0/Download/notes.txt'),
        isNull,
      );
    });

    test('classifies image files only inside an exact .thumbnails folder', () {
      expect(
        CleanupRules.classify('/storage/emulated/0/DCIM/.thumbnails/image.jpg'),
        'thumbnail_files',
      );
      expect(
        CleanupRules.classify('/storage/emulated/0/DCIM/.thumbnails/index.db'),
        isNull,
      );
      expect(
        CleanupRules.classify('/storage/emulated/0/Pictures/my_thumbnail.jpg'),
        isNull,
      );
      expect(
        CleanupRules.classify('/storage/emulated/0/Pictures/thumb_family.jpg'),
        isNull,
      );
    });

    test('never classifies candidates inside Android private folders', () {
      expect(
        CleanupRules.classify('/storage/emulated/0/Android/data/app/cache.tmp'),
        isNull,
      );
      expect(
        CleanupRules.classify('/storage/emulated/0/Android/obb/app/image.jpg'),
        isNull,
      );
    });

    test('does not classify protected metadata or database files', () {
      expect(
        CleanupRules.classify('/storage/emulated/0/WhatsApp/.nomedia'),
        isNull,
      );
      expect(
        CleanupRules.classify('/storage/emulated/0/Download/data.sqlite'),
        isNull,
      );
    });
  });
}
