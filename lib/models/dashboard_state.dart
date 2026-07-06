class DashboardState {
  final bool scanning;
  final bool analysisFinished;

  final double progress;
  final double healthScore;

  final int totalFiles;
  final int totalBytes;

  final String currentTask;

  const DashboardState({
    this.scanning = false,
    this.analysisFinished = false,
    this.progress = 0,
    this.healthScore = 100,
    this.totalFiles = 0,
    this.totalBytes = 0,
    this.currentTask = "Ready",
  });

  DashboardState copyWith({
    bool? scanning,
    bool? analysisFinished,
    double? progress,
    double? healthScore,
    int? totalFiles,
    int? totalBytes,
    String? currentTask,
  }) {
    return DashboardState(
      scanning: scanning ?? this.scanning,
      analysisFinished:
          analysisFinished ?? this.analysisFinished,
      progress: progress ?? this.progress,
      healthScore: healthScore ?? this.healthScore,
      totalFiles: totalFiles ?? this.totalFiles,
      totalBytes: totalBytes ?? this.totalBytes,
      currentTask: currentTask ?? this.currentTask,
    );
  }
}
