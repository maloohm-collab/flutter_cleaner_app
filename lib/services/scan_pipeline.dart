enum ScanStage {
  initializing,
  analyzingStorage,
  scanningThumbnails,
  scanningTempFiles,
  scanningLogs,
  scanningEmptyFolders,
  buildingPlan,
  ready,
}

class ScanPipeline {
  final List<ScanStage> _stages = [
    ScanStage.initializing,
    ScanStage.analyzingStorage,
    ScanStage.scanningThumbnails,
    ScanStage.scanningTempFiles,
    ScanStage.scanningLogs,
    ScanStage.scanningEmptyFolders,
    ScanStage.buildingPlan,
    ScanStage.ready,
  ];

  Future<void> start({
    required Future<void> Function(
      ScanStage stage,
      double progress,
      String message,
    ) onStage,
  }) async {
    for (int i = 0; i < _stages.length; i++) {
      final stage = _stages[i];

      await onStage(
        stage,
        (i + 1) / _stages.length,
        _message(stage),
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );
    }
  }

  String _message(ScanStage stage) {
    switch (stage) {
      case ScanStage.initializing:
        return "Initializing AI Engine...";

      case ScanStage.analyzingStorage:
        return "Analyzing Device Storage...";

      case ScanStage.scanningThumbnails:
        return "Scanning Thumbnail Cache...";

      case ScanStage.scanningTempFiles:
        return "Scanning Temporary Files...";

      case ScanStage.scanningLogs:
        return "Scanning Log Files...";

      case ScanStage.scanningEmptyFolders:
        return "Scanning Empty Folders...";

      case ScanStage.buildingPlan:
        return "Building Safe Cleaning Plan...";

      case ScanStage.ready:
        return "Analysis Complete";
    }
  }
}
