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

  Future<void> _scanDirectory(
    Directory directory,
    Function(String) onLog,
    Function() onUpdate,
  ) async {
    try {
      scannedFolders++;
      onUpdate();

      final entities = directory.listSync();

      for (final entity in entities) {
        if (entity is Directory) {
          if (entity.path.toLowerCase().contains("thumbnails")) {
            onLog("Cleaning ${entity.path.split('/').last}");

            final files = entity.listSync();

            for (final file in files) {
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
            await _scanDirectory(
              entity,
              onLog,
              onUpdate,
            );
          }
        } else if (entity is File) {
          scannedFiles++;
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
