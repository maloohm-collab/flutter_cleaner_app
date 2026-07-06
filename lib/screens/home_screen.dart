import 'package:flutter/material.dart';

// الاستيرادات القياسية للمحرك والحالة الموحدة
import 'package:flutter_cleaner_app/services/cleaner_engine.dart';
import 'package:flutter_cleaner_app/services/scan_pipeline.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart'; 
import 'package:flutter_cleaner_app/models/dashboard_state.dart';
import 'package:flutter_cleaner_app/widgets/health_score_card.dart';
import 'package:flutter_cleaner_app/widgets/live_scan_card.dart';
import 'package:flutter_cleaner_app/widgets/scan_result_card.dart';

import '../utils/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/progress_ring.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CleanerEngine _engine = CleanerEngine();
  final ScanPipeline _pipeline = ScanPipeline();

  DashboardState state = const DashboardState();

  List<ScanItem> scanItems = [];
  final List<Map<String, String>> logs = [];

  int healthScore = 100;
  String lastOptimization = "Never";

  @override
  void initState() {
    super.initState();

    state = state.copyWith(
      currentTask: "Ready for AI Analysis",
      progress: 0,
      healthScore: 100,
    );
  }

  // دالة التحليل الحقيقي المتصلة بالأنبوب ومحرك الفحص الفعلي
  Future<void> startAnalysis() async {
    if (state.scanning) return;

    setState(() {
      logs.clear();

      state = state.copyWith(
        scanning: true,
        analysisFinished: false,
        progress: 0,
        currentTask: "Initializing AI Engine...",
      );
    });

    await _pipeline.start(
      onStage: (stage, progress, message) async {
        if (!mounted) return;

        setState(() {
          state = state.copyWith(
            progress: progress,
            currentTask: message,
          );
        });

        _addLog(message);
      },
    );

    scanItems = await _engine.scan(
      onStatus: (msg) {
        if (!mounted) return;

        _addLog(msg);

        setState(() {
          state = state.copyWith(
            currentTask: msg,
          );
        });
      },
      onProgress: (p) {
        if (!mounted) return;

        setState(() {
          state = state.copyWith(
            progress: p,
          );
        });
      },
    );

    if (!mounted) return;

    setState(() {
      healthScore = (_engine.totalFiles == 0)
          ? 100
          : (100 - (_engine.totalFiles ~/ 5)).clamp(65, 100);

      state = state.copyWith(
        scanning: false,
        analysisFinished: true,
        progress: 1,
        currentTask: "Analysis Complete",
        totalFiles: _engine.totalFiles,
        totalBytes: _engine.totalBytes,
        healthScore: healthScore.toDouble(),
      );
    });
  }

  // الدالة المحسنة لعملية التنظيف الفعلي مع نافذة التأكيد المنبثقة
  Future<void> performCleaning() async {
    if (state.scanning) return;

    final selectedItems = scanItems.where((item) => item.selected).toList();
    
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one cache category to clean."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    bool? shouldClean = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1326),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD700), size: 26),
              const SizedBox(width: 10),
              const Text(
                "Confirm Deletion",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to permanently delete the selected cache files (${formatBytes(state.totalBytes.toInt())}) from this device?",
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel", style: TextStyle(color: Colors.white38, fontSize: 14)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Clean Now", style: TextStyle(color: Color(0xFF00F2FE), fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (shouldClean != true) {
      _addLog("Optimization canceled by user.");
      return;
    }

    setState(() {
      state = state.copyWith(
        scanning: true,
        currentTask: "Initializing deep clean...",
        progress: 0.15,
      );
      logs.clear();
    });

    _addLog("Executing device file cleanup...");

    await _engine.clean(
      selected: selectedItems,
      onStatus: (msg) {
        if (!mounted) return;
        _addLog(msg);
        setState(() {
          state = state.copyWith(currentTask: msg);
        });
      },
    );

    for (double p = 0.4; p <= 1.0; p += 0.15) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      setState(() {
        state = state.copyWith(progress: p.clamp(0.0, 1.0));
      });
    }

    if (!mounted) return;

    setState(() {
      scanItems.clear();
      state = state.copyWith(
        scanning: false,
        analysisFinished: false,
        progress: 0.0,
        currentTask: "System Fully Optimized!",
        totalFiles: 0,
        totalBytes: 0,
        healthScore: 100,
      );
      _addLog("Optimization Complete. 0B Left.");
    });
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / 1024 / 1024).toStringAsFixed(2)} MB";
    return "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final String timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    logs.insert(0, {
      "time": timeStr,
      "message": message.startsWith("[AI]") ? message : "[AI] $message"
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
        centerTitle: true,
        title: const Text(
          "AI OPTIMIZER",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 26),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        // إلغاء الـ SingleChildScrollView تماماً لضمان قفل وحصر الشاشة بشكل ثابت وملموم
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 5),

              // 1. حلقة التقدم العلوية
              ProgressRing(
                progress: state.progress,
                title: state.currentTask,
                subtitle: state.scanning ? "AI Engine Running..." : "Ready for Analysis",
              ),

              const SizedBox(height: 12),

              // 2. دمج بطاقة الصحة والبطاقة المباشرة أفقياً لتوفير مساحة عمودية ضخمة
              Row(
                children: [
                  Expanded(
                    child: HealthScoreCard(score: state.healthScore),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LiveScanCard(
                      currentTask: state.currentTask,
                      progress: state.progress,
                      scanning: state.scanning,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 3. شريط إحصائيات الأرقام المدمج والمصغر
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn("${state.totalFiles}", "Files Cleaned", const Color(0xFF00F2FE)),
                    Container(width: 1, height: 25, color: Colors.white10),
                    _buildStatColumn(formatBytes(state.totalBytes.toInt()), "Space Freed", const Color(0xFFE040FB)),
                    Container(width: 1, height: 25, color: Colors.white10),
                    _buildStatColumn(state.scanning ? "${(state.progress * 100).toInt()}%" : "100%", "Performance", const Color(0xFF00E676)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 4. الحاوية المرنة والديناميكية (Expanded Switcher) لتبادل المكونات دون دفع الواجهة
              Expanded(
                child: scanItems.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Detected Items",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.builder(
                              itemCount: scanItems.length,
                              itemBuilder: (context, index) {
                                return ScanResultCard(
                                  item: scanItems[index],
                                  onChanged: (value) {
                                    setState(() {
                                      scanItems[index] = scanItems[index].copyWith(
                                        selected: value ?? true,
                                      );
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Scan Log", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero, 
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {},
                                child: const Text("View All >", style: TextStyle(color: Color(0xFF4FACFE), fontSize: 12)),
                              ),
                            ],
                          ),
                          Container(
                            height: 75, // حجم ملموم ومحكم للسجلات
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.03)),
                            ),
                            child: logs.isEmpty
                                ? const Center(child: Text("No activity yet", style: TextStyle(color: Colors.white38, fontSize: 12)))
                                : ListView.builder(
                                    itemCount: logs.length,
                                    itemBuilder: (_, i) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(Icons.check_circle_outline_rounded, color: const Color(0xFF00E676).withOpacity(0.8), size: 14),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      logs[i]["message"]!,
                                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(logs[i]["time"]!, style: const TextStyle(color: Colors.white30, fontSize: 11)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 10),
                          const Text("Smart Tools", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildToolItem(Icons.cleaning_services_rounded, "Deep Clean"),
                              _buildToolItem(Icons.insert_drive_file_rounded, "Large Files"),
                              _buildToolItem(Icons.file_copy_rounded, "Duplicates"),
                              _buildToolItem(Icons.android_rounded, "App Manager"),
                            ],
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 12),

              // 5. زر التفاعل الرئيسي المثبت في الأسفل دائماً
              AnimatedButton(
                title: state.scanning
                    ? "PROCESSING..."
                    : state.analysisFinished
                        ? "START OPTIMIZATION"
                        : "START AI ANALYSIS",
                icon: state.scanning
                    ? Icons.sync
                    : state.analysisFinished
                        ? Icons.cleaning_services
                        : Icons.auto_fix_high,
                onPressed: state.scanning
                    ? null
                    : state.analysisFinished
                        ? performCleaning
                        : startAnalysis,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF090D1A),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00F2FE),
        unselectedItemColor: Colors.white38,
        currentIndex: 0,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.build_rounded), label: "Tools"),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_rounded), label: "Monitor"),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: "Settings"),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String title, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _buildToolItem(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Icon(icon, color: const Color(0xFF00F2FE), size: 20),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}
