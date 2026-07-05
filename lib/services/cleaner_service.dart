import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class CleanerService {
  int deletedFiles = 0;
  int scannedFolders = 0;
  int scannedFiles = 0;
  int freedBytes = 0;

  Future<bool> requestPermission() async {
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  Future<void> startCleaning({
    required Function(String message) onLog,
    required Function() onUpdate,
  }) async {
    deletedFiles = 0;
    scannedFolders = 0;
    scannedFiles = 0;
    freedBytes = 0;

    final root = Directory('/storage/emulated/0/');

    await _scanDirectory(
      root,
      onLog,
      onUpdate,
    );
  }

  // ✅ تم تحويل الدالة لتعمل بشكل تدفقي غير متزامن لحماية الواجهة من التجمد
  Future<void> _scanDirectory(
    Directory directory,
    Function(String) onLog,
    Function() onUpdate,
  ) async {
    try {
      scannedFolders++;
      onUpdate();

      // استخدام list() بدلاً من listSync() لعدم حظر الـ UI Thread
      await for (final entity in directory.list(recursive: false, followLinks: false)) {
        if (entity is Directory) {
          if (entity.path.toLowerCase().contains("thumbnails")) {
            onLog("Cleaning ${entity.path.split('/').last}");

            // جرد الملفات داخل مجلد الـ thumbnails بشكل غير متزامن أيضاً
            await for (final file in entity.list(recursive: false, followLinks: false)) {
              if (file is File) {
                try {
                  final size = await file.length();

                  await file.delete();

                  deletedFiles++;
                  scannedFiles++;
                  freedBytes += size;

                  onUpdate();
                } catch (_) {}
              }
            }
          } else {
            // استدعاء عودي آمن وغير متزامن
            await _scanDirectory(
              entity,
              onLog,
              onUpdate,
            );
          }
        } else if (entity is File) {
          scannedFiles++;
          // تحديث العداد دورياً أثناء جرد الملفات العادية ليعطي شعوراً بالسرعة والتحديث اللحظي
          onUpdate();
        }
      }
    } catch (_) {}
  }

  String get formattedSize {
    if (freedBytes < 1024) {
      return "$freedBytes B";
    }

    if (freedBytes < 1024 * 1024) {
      return "${(freedBytes / 1024).toStringAsFixed(1)} KB";
        }

    if (freedBytes < 1024 * 1024 * 1024) {
      return "${(freedBytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    }

    return "${(freedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }
}
