import 'package:flutter/material.dart';

// الاستيرادات الجديدة للمحرك والحالة الموحدة
import '../services/cleaner_engine.dart';
import '../services/scan_pipeline.dart';
import '../services/models/scan_item.dart';
import '../models/dashboard_state.dart';
import '../widgets/health_score_card.dart';
import '../widgets/live_scan_card.dart';
import '../widgets/scan_result_card.dart';

import '../utils/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/progress_ring.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // المتغيرات المركزية للمحرك والحالة الموحدة
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
      onStage: (stage, progress, message) {
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
      // احتساب النتيجة ديناميكياً بناءً على عدد الملفات المكتشفة
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

  // الدالة القديمة بعد تغيير اسمها تمهيداً لربطها بالكامل لاحقاً
  Future<void> performCleaning() async {
    if (state.scanning) return;

    setState(() {
      state = state.copyWith(
        scanning: true,
        currentTask: "Scanning...",
        progress: 0.05,
      );
      logs.clear();
    });

    _addLog("Scanning directories...");

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      state = state.copyWith(
        scanning: false,
        progress: 1.0,
        currentTask: "Optimization Complete",
      );
      _addLog("Optimization Complete");
    });
  }

  // دالة تحويل وتنسيق حجم الملفات والمساحة المستهلكة رقمياً
  String formatBytes(int bytes) {
    if (bytes < 1024) {
      return "$bytes B";
    }
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / 1024 / 1024).toStringAsFixed(2)} MB";
    }
    return "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB";
  }

  // استخدام معالج وقت نقي من لغة Dart دون استدعاء أي حزم خارجية
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              const SizedBox(height: 10),

              ProgressRing(
                progress: state.progress,
                title: state.currentTask,
                subtitle: state.scanning
                    ? "AI Engine Running..."
                    : "Ready for Analysis",
              ),

              const SizedBox(height: 25),

              // 1) إضافة بطاقة نتيجة صحة الجهاز وبطاقة الفحص الحي أسفل حلقة التقدم
              HealthScoreCard(
                score: state.healthScore,
                status: state.healthScore >= 90
                    ? "Excellent"
                    : state.healthScore >= 75
                        ? "Good"
                        : "Needs Optimization",
              ),

              const SizedBox(height: 18),

              LiveScanCard(
                currentTask: state.currentTask,
                progress: state.progress,
                scanning: state.scanning,
              ),

              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      "${state.totalFiles}",
                      "Files Cleaned",
                      const Color(0xFF00F2FE),
                    ),
                    Container(width: 1, height: 35, color: Colors.white10),
                    _buildStatColumn(
                      formatBytes(state.totalBytes),
                      "Space Freed",
                      const Color(0xFFE040FB),
                    ),
                    Container(width: 1, height: 35, color: Colors.white10),
                    _buildStatColumn(
                      state.scanning ? "${(state.progress * 100).toInt()}%" : "100%",
                      "Performance",
                      const Color(0xFF00E676),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Scan Log",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text("View All >", style: TextStyle(color: Color(0xFF4FACFE), fontSize: 13)),
                  ),
                ],
              ),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.03)),
                  ),
                  child: logs.isEmpty
                      ? const Center(
                          child: Text(
                            "No activity yet",
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (_, i) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: const Color(0xFF00E676).withOpacity(0.8),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        logs[i]["message"]!,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    logs[i]["time"]!,
                                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // 2) إضافة قسم عرض العناصر المكتشفة حركياً عند وجود ملفات
              if (scanItems.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Detected Items",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
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
                const SizedBox(height: 20),
              ],

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Smart Tools",
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
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

              const SizedBox(height: 25),

              // 3) تعديل الزر السفلي ليتغير ديناميكياً حسب مراحل الفحص والتنظيف
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
              const SizedBox(height: 15),
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
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildToolItem(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Icon(icon, color: const Color(0xFF00F2FE), size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

