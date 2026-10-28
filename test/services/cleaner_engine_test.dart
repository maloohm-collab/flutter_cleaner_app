import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleaner_app/services/cleaner_engine.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart';

void main() {
  late Directory storageRoot;
  late CleanerEngine engine;

  setUp(() async {
    storageRoot = await Directory.systemTemp.createTemp('ai_optimizer_cleaner_test_');
    engine = CleanerEngine(storageRoot: storageRoot.path);
  });

  tearDown(() async {
    if (await storageRoot.exists()) {
      await storageRoot.delete(recursive: true);
    }
  });

  test('deletes only the individually selected temporary file', () async {
    final File selectedFile = File('${storageRoot.path}/selected.tmp');
    final File untouchedFile = File('${storageRoot.path}/keep.tmp');
    await selectedFile.writeAsString('selected bytes');
    await untouchedFile.writeAsString('keep these bytes');

    final List<ScanItem> results = await engine.scan();
    final ScanItem temporary = results.singleWhere(
      (item) => item.id == 'temporary_files',
    );
    final ScanItem request = temporary.copyWith(
      selected: true,
      selectedPaths: <String>[selectedFile.path],
    );

    final int deleted = await engine.clean(selected: <ScanItem>[request]);

    expect(deleted, 1);
    expect(await selectedFile.exists(), isFalse);
    expect(await untouchedFile.exists(), isTrue);
    expect(engine.lastDeletedBytes, 'selected bytes'.length);
  });

  test('APK files are review-only and cannot be deleted by clean()', () async {
    final File apkFile = File('${storageRoot.path}/installer.apk');
    await apkFile.writeAsBytes(<int>[1, 2, 3, 4]);

    final List<ScanItem> results = await engine.scan();
    final ScanItem apk = results.singleWhere((item) => item.id == 'apk_files');

    expect(apk.safeToDelete, isFalse);

    final int deleted = await engine.clean(
      selected: <ScanItem>[
        apk.copyWith(
          selected: true,
          selectedPaths: <String>[apkFile.path],
        ),
      ],
    );

    expect(deleted, 0);
    expect(await apkFile.exists(), isTrue);
    expect(engine.lastDeletedBytes, 0);
  });

  test('an empty individual selection never deletes the whole category', () async {
    final File tempFile = File('${storageRoot.path}/leave.tmp');
    await tempFile.writeAsString('leave me');

    final List<ScanItem> results = await engine.scan();
    final ScanItem temporary = results.singleWhere(
      (item) => item.id == 'temporary_files',
    );

    final int deleted = await engine.clean(
      selected: <ScanItem>[temporary.copyWith(selected: true)],
    );

    expect(deleted, 0);
    expect(await tempFile.exists(), isTrue);
  });
}
