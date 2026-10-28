import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleaner_app/services/duplicate_file_scanner.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ai_optimizer_duplicates_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Future<File> writeFile(String relativePath, List<int> bytes) async {
    final file = File('${tempRoot.path}/$relativePath');
    await file.parent.create(recursive: true);
    return file..writeAsBytesSync(bytes);
  }

  test('reports only byte-for-byte identical files', () async {
    await writeFile('photos/a.bin', <int>[1, 2, 3, 4]);
    await writeFile('backup/copy.bin', <int>[1, 2, 3, 4]);
    await writeFile('other/same_size.bin', <int>[1, 2, 3, 5]);

    final groups = await DuplicateFileScanner(storageRoot: tempRoot.path).scan();

    expect(groups, hasLength(1));
    expect(groups.single.paths, hasLength(2));
    expect(groups.single.bytes, 4);
    expect(groups.single.reclaimableBytes, 4);
  });

  test('reports empty files as duplicates when contents match', () async {
    await writeFile('empty/a.tmp', <int>[]);
    await writeFile('empty/b.tmp', <int>[]);

    final groups = await DuplicateFileScanner(storageRoot: tempRoot.path).scan();

    expect(groups, hasLength(1));
    expect(groups.single.bytes, 0);
    expect(groups.single.paths, hasLength(2));
  });

  test('excludes Android data and obb folders', () async {
    await writeFile('visible/a.bin', <int>[7, 8]);
    await writeFile('visible/b.bin', <int>[7, 8]);
    await writeFile('Android/data/app/a.bin', <int>[7, 8]);
    await writeFile('Android/obb/app/b.bin', <int>[7, 8]);

    final groups = await DuplicateFileScanner(storageRoot: tempRoot.path).scan();

    expect(groups, hasLength(1));
    expect(groups.single.paths, everyElement(contains('/visible/')));
  });

  test('does not classify same-size files with different content as duplicates', () async {
    await writeFile('one.bin', <int>[10, 11, 12]);
    await writeFile('two.bin', <int>[10, 11, 13]);

    final groups = await DuplicateFileScanner(storageRoot: tempRoot.path).scan();

    expect(groups, isEmpty);
  });
}
