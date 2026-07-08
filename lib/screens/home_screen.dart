import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/cleaner_engine.dart';
import '../services/scan_pipeline.dart';
import '../services/plugins/thumbnail_cleaner.dart';
import '../services/scan_item.dart';
import '../widgets/scan_result_card.dart';
import '../utils/colors.dart';

/// HomeScreen - نسخة احترافية ومُحسّنة
/// - يربط Pipeline بمهمات فحص فعلية (thumbnail plugin + engine)
/// - لا يعرض أي بيانات ثابتة أو وهمية
/// - يتعامل مع صلاحيات المنصات بشكل مرن
/// - يسجل كل خطوة لتسهيل التتبع والاختبار
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CleanerEngine _engine = CleanerEngine();
  final ScanPipeline _pipeline = ScanPipeline();
  final ThumbnailCleaner _thumbnailCleaner = ThumbnailCleaner();

  final List<ScanItem> _scanItems = [];
  final List<String> _logs = [];

  double _progress = 0.0;
  String _currentTask = "";
  bool _isScanning = false;
  bool _isCleaning = false;

  // ----- حسابات عرضية -----
  int get totalFiles => _scanItems.fold<int>(0, (s, i) => s + i.files);
  int get totalBytes => _scanItems.fold<int>(0, (s, i) => s + i.bytes);

  double get healthScore {
    if (totalBytes == 0) return 100.0;
    final score = (1 - (totalBytes / (1024 * 1024 * 500))) * 100;
    return score.clamp(0.0, 100.0).toDouble();
  }

  @override
  void initState() {
    super.initState();
  }

  // ----- سجلات داخلية مع حد أقصى لحجم السجل -----
  void _addLog(String message) {
    final ts = DateTime.now().toIso8601String();
    final line = "[$ts] $message";
    _logs.insert(0, line);
    if (_logs.length > 300) _logs.removeLast();
    if (!mounted) return;
    setState(() {});
  }

  // ----- مساعدة لعرض SnackBar من أي مكان -----
  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ----- طلب الصلاحيات بطريقة مرنة حسب المنصة -----
  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // طلب صلاحية التخزين التقليدية (ستُغطي حالات أندرويد القديمة)
        final storage = await Permission.storage.request();
        if (!storage.isGranted) {
          _addLog("Storage permission denied.");
          _showSnack("Storage permission is required to scan device files.");
          return false;
        }

        // Android 13+ قد يحتاج صلاحيات وسائط منفصلة؛ نطلبها إن كانت متاحة لكن لا نفشل إن لم تكن
        try {
          final photos = await Permission.photos.request();
          final videos = await Permission.videos.request();
          final audio = await Permission.audio.request();
          if (!storage.isGranted && !photos.isGranted && !videos.isGranted && !audio.isGranted) {
            _addLog("Media permissions denied.");
            return false;
          }
        } catch (_) {
          // بعض أنواع الصلاحيات قد لا تكون متاحة على SDK قديم؛ تجاهل الخطأ
        }
      } else if (Platform.isIOS) {
        final photos = await Permission.photos.request();
        if (!photos.isGranted) {
          _addLog("Photos permission denied.");
          _showSnack("Photos permission is required to scan media files.");
          return false;
        }
      } else {
        // منصات أخرى: لا صلاحيات إضافية مطلوبة عادة
      }

      _addLog("Permissions granted.");
      return true;
    } catch (e) {
      _addLog("Permission request error: $e");
      return false;
    }
  }

  // ----- بدء التحليل المتكامل -----
  Future<void> startAnalysis() async {
    if (_isScanning) return;
    _isScanning = true;
    _progress = 0.0;
    _currentTask = "Preparing scan...";
    _scanItems.clear();
    _addLog("Starting analysis...");

    final ok = await _requestPermissions();
    if (!ok) {
      _isScanning = false;
      _currentTask = "Permissions required";
      if (mounted) setState(() {});
      return;
    }

    try {
      // Pipeline start: onStage لتحديث الواجهة، onStageStart لتنفيذ فحوص فعلية
      await _pipeline.start(
        onStage: (stage, progress, message) async {
          if (!mounted) return;
          _progress = progress;
          _currentTask = message;
          _addLog("Stage: $message (${(progress * 100).toStringAsFixed(0)}%)");
          setState(() {});
        },
        onStageStart: (stage) async {
          if (!mounted) return;
          switch (stage) {
            case ScanStage.scanningThumbnails:
              _addLog("Scanning thumbnails (plugin)...");
              try {
                final thumbs = await _thumbnailCleaner.scan(onProgress: (m) => _addLog(m));
                for (final t in thumbs) {
                  if (t.files > 0 && !_scanItems.any((s) => s.path == t.path && s.id == t.id)) {
                    _scanItems.add(t);
                  }
                }
                if (mounted) setState(() {});
              } catch (e) {
                _addLog("Thumbnail scan error: $e");
              }
              break;

            case ScanStage.analyzingStorage:
              _addLog("Scanning storage (engine)...");
              try {
                final engineResults = await _engine.scan(
                  onStatus: (m) => _addLog(m),
                  onProgress: (p) => _addLog("Engine progress: ${(p * 100).toStringAsFixed(0)}%"),
                );
                for (final r in engineResults) {
                  if (r.files > 0 && !_scanItems.any((s) => s.path == r.path && s.id == r.id)) {
                    _scanItems.add(r);
                  }
                }
                if (mounted) setState(() {});
              } catch (e) {
                _addLog("Engine scan error: $e");
              }
              break;

            case ScanStage.scanningTempFiles:
              // تم التعامل مع ملفات temp ضمن analyzingStorage لتجنّب المسح المكرر
              _addLog("Scanning temp files handled by analyzingStorage stage.");
              break;

            case ScanStage.scanningLogs:
              _addLog("Scanning logs stage (no-op if not implemented).");
              break;

            case ScanStage.scanningEmptyFolders:
              _addLog("Scanning empty folders (no-op if not implemented).");
              break;

            case ScanStage.buildingPlan:
              _addLog("Building cleaning plan...");
              break;

            case ScanStage.initializing:
            case ScanStage.ready:
              // لا عمل إضافي هنا
              break;
          }
        },
      );
    } catch (e) {
      _addLog("Pipeline error: $e");
    } finally {
      _isScanning = false;
      _progress = 1.0;
      _currentTask = "Analysis finished";
      if (mounted) setState(() {});
      _addLog("Analysis completed. Items found: ${_scanItems.length}, files: $totalFiles, size: ${_readableTotalSize()}");
    }
  }

  // ----- تنسيق الحجم الإجمالي للعرض -----
  String _readableTotalSize() {
    if (totalBytes < 1024) return "$totalBytes B";
    if (totalBytes < 1024 * 1024) return "${(totalBytes / 1024).toStringAsFixed(1)} KB";
    if (totalBytes < 1024 * 1024 * 1024) return "${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    return "${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  // ----- تنفيذ التنظيف الفعلي -----
  Future<void> performCleaning() async {
    if (_isCleaning) return;
    _isCleaning = true;
    _addLog("Starting cleaning...");

    final selected = _scanItems.where((i) => i.selected).toList();
    if (selected.isEmpty) {
      _addLog("No items selected for cleaning.");
      _isCleaning = false;
      if (mounted) setState(() {});
      return;
    }

    // فصل العناصر الخاصة بالثُمبنايل عن بقية العناصر
    final thumbnailItems = selected.where((i) => i.id.toLowerCase().contains("thumbnail")).toList();
    final engineItems = selected.where((i) => !i.id.toLowerCase().contains("thumbnail")).toList();

    int deletedTotal = 0;

    if (engineItems.isNotEmpty) {
      try {
        _addLog("Cleaning engine-detected items...");
        final deleted = await _engine.clean(
          selected: engineItems,
          onStatus: (m) => _addLog(m),
        );
        deletedTotal += deleted;
        _addLog("Engine deleted $deleted files.");
      } catch (e) {
        _addLog("Engine cleaning error: $e");
      }
    }

    if (thumbnailItems.isNotEmpty) {
      try {
        _addLog("Cleaning thumbnail items...");
        final deleted = await _thumbnailCleaner.clean(
          thumbnailItems,
          (m) => _addLog(m),
        );
        deletedTotal += deleted;
        _addLog("ThumbnailCleaner deleted $deleted files.");
      } catch (e) {
        _addLog("Thumbnail cleaning error: $e");
      }
    }

    _addLog("Cleaning finished. Total deleted files: $deletedTotal");

    // بعد التنظيف، أعد الفحص لتحديث الواجهة (لا تُعيد قيم وهمية)
    await startAnalysis();

    _isCleaning = false;
    if (mounted) setState(() {});
  }

  // ----- تبديل اختيار عنصر -----
  void _toggleSelection(int index, bool? value) {
    final item = _scanItems[index];
    final updated = item.copyWith(selected: value ?? false);
    _scanItems[index] = updated;
    if (mounted) setState(() {});
  }

  // ----- واجهة المستخدم -----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : startAnalysis,
            tooltip: "Start Analysis",
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // بطاقة الملخص السريع
              Card(
                color: AppColors.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Health Score: ${healthScore.toStringAsFixed(0)}%",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text("Files: $totalFiles"),
                            Text("Size: ${_readableTotalSize()}"),
                            const SizedBox(height: 6),
                            Text("Task: $_currentTask"),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: (_progress).clamp(0.0, 1.0),
                              color: AppColors.primary,
                              strokeWidth: 8,
                            ),
                            Text("${(_progress * 100).toStringAsFixed(0)}%"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // قائمة النتائج أو رسالة لا توجد مهملات
              Expanded(
                child: _scanItems.isEmpty
                    ? Center(
                        child: Text(
                          _isScanning ? "Scanning..." : "No junk files found.",
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _scanItems.length,
                        itemBuilder: (context, index) {
                          final item = _scanItems[index];
                          return ScanResultCard(
                            item: item,
                            onChanged: (v) => _toggleSelection(index, v),
                          );
                        },
                      ),
              ),

              // أزرار الإجراءات
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isScanning || _isCleaning ? null : startAnalysis,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: Text(_isScanning ? "Scanning..." : "Start Scan"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCleaning || _isScanning ? null : performCleaning,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      child: Text(_isCleaning ? "Cleaning..." : "Clean Selected"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // سجل مبسط للعمليات
              SizedBox(
                height: 120,
                child: Card(
                  color: AppColors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, i) => Text(
                        _logs[i],
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
