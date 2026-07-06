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

    // تصفية العناصر التي حددها المستخدم فقط للتنظيف
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

    // 1️⃣ إظهار نافذة التأكيد المنبثقة المتناسقة مع ثيم التطبيق الداكن والنيون
    bool? shouldClean = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // منع الإغلاق عند الضغط خارج النافذة بالخطأ
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1326), // لون داكن فخم يناسب الهوية البصرية لشاشاتك
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: Border.all(color: Colors.white.withOpacity(0.08)),
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
            // زر إلغاء عملية الحذف والتراجع
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
            // زر التأكيد والمضي قدماً في التنظيف الفعلي
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                "Clean Now",
                style: TextStyle(color: Color(0xFF00F2FE), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    // إذا اختار المستخدم إلغاء الأمر، نوقف تنفيذ الدالة فوراً ولا نغير شيئاً
    if (shouldClean != true) {
      _addLog("Optimization canceled by user.");
      return;
    }

    // 2️⃣ بدء التنظيف الفعلي عبر المحرك بعد الحصول على الموافقة
    setState(() {
      state = state.copyWith(
        scanning: true,
        currentTask: "Initializing deep clean...",
        progress: 0.15,
      );
      logs.clear();
    });

    _addLog("Executing device file cleanup...");

    // استدعاء دالة الحذف للملفات الفعلية المجمعة في الذاكرة
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

    // محاكاة حركية بصرية لتحديث شريط التقدم بسلاسة فنية حتى النهاية
    for (double p = 0.4; p <= 1.0; p += 0.15) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      setState(() {
        state = state.copyWith(progress: p.clamp(0.0, 1.0));
      });
    }

    if (!mounted) return;

    setState(() {
      scanItems.clear(); // تفريغ القائمة من الواجهة تماماً لأن الملفات حُذفت فعلياً
      state = state.copyWith(
        scanning: false,
        analysisFinished: false, // العودة للوضع الافتراضي ليكون مستعداً لفحص حقيقي جديد لاحقاً
        progress: 0.0,
        currentTask: "System Fully Optimized!",
        totalFiles: 0,
        totalBytes: 0,
        healthScore: 100, // إعادة مؤشر صحة الجهاز إلى الدرجة الكاملة 100%
      );
      _addLog("Optimization Complete. 0B Left.");
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
        child: SingleChildScrollView(
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

                HealthScoreCard(
                  score: state.healthScore,
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
                        formatBytes(state.totalBytes.toInt()),
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

                SizedBox(
                  height: 150,
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

                if (scanItems.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Detected Items",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

