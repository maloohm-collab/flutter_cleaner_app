import 'package:flutter/material.dart';

import '../utils/colors.dart';
import '../widgets/health_score_card.dart';
import '../widgets/live_scan_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/info_tile.dart';

// الاستيرادات الجديدة الخاصة بمحرك الفحص
import '../services/cleaner_engine.dart';
import '../services/scan_pipeline.dart';
import '../services/models/scan_item.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double healthScore = 97;
  double progress = 0;
  bool scanning = false;
  String currentTask = "Ready for AI Analysis";

  // المتغيرات الجديدة لربط البيانات المحرك
  final CleanerEngine _engine = CleanerEngine();
  final ScanPipeline _pipeline = ScanPipeline();
  List<ScanItem> scanItems = [];
  int totalFiles = 0;
  int totalBytes = 0;
  bool analysisFinished = false;

  // دالة بدء الفحص والتحليل الرقمي
  Future<void> startAnalysis() async {
    if (scanning) return;

    setState(() {
      scanning = true;
      analysisFinished = false;
      progress = 0;
      currentTask = "Initializing AI Engine...";
    });

    await _pipeline.start(
      onStage: (stage, p, message) async {
        setState(() {
          progress = p;
          currentTask = message;
        });
      },
    );

    scanItems = await _engine.scan(
      onStatus: (msg) {
        setState(() {
          currentTask = msg;
        });
      },
      onProgress: (p) {
        setState(() {
          progress = p;
        });
      },
    );

    totalFiles = _engine.totalFiles;
    totalBytes = _engine.totalBytes;

    setState(() {
      scanning = false;
      analysisFinished = true;
      currentTask = "Analysis Complete";
    });
  }

  // دالة تحويل وتنسيق حجم الملفات والمساحة المستهلكة
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "AI Optimizer Pro",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Welcome Back",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "AI Device Dashboard",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              HealthScoreCard(
                score: healthScore,
                status: "Excellent",
              ),
              const SizedBox(height: 25),
              LiveScanCard(
                currentTask: currentTask,
                progress: progress,
                scanning: scanning,
              ),
              const SizedBox(height: 25),
              const Text(
                "Device Overview",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.18,
                children: [
                  StatCard(
                    icon: Icons.delete_outline,
                    title: "Files Found",
                    value: "$totalFiles", // ربط عدد الملفات الفعلي
                  ),
                  const StatCard(
                    icon: Icons.folder_open,
                    title: "Folders",
                    value: "0",
                    color: AppColors.warning,
                  ),
                  StatCard(
                    icon: Icons.storage,
                    title: "Recovered",
                    value: formatBytes(totalBytes), // ربط الحجم الفعلي وتنسيقه
                    color: AppColors.success,
                  ),
                  const StatCard(
                    icon: Icons.speed,
                    title: "Performance",
                    value: "100%",
                    color: AppColors.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Text(
                "AI Recommendation",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const InfoTile(
                icon: Icons.auto_fix_high,
                title: "Optimization Status",
                value: "Device is ready for AI analysis",
              ),
              const SizedBox(height: 12),
              const InfoTile(
                icon: Icons.photo_library_outlined,
                title: "Thumbnail Cache",
                value: "Waiting for scan...",
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              const InfoTile(
                icon: Icons.cleaning_services_outlined,
                title: "Temporary Files",
                value: "Waiting for scan...",
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              const InfoTile(
                icon: Icons.folder_delete_outlined,
                title: "Empty Folders",
                value: "Waiting for scan...",
                color: Colors.cyan,
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Last Optimization",
                      style: TextStyle(
                        color: Colors.white60,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "No optimization has been performed yet.",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              
              // زر بدء التحليل بالذكاء الاصطناعي مدمج هنا
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: scanning ? null : startAnalysis,
                  icon: Icon(
                    scanning ? Icons.sync : Icons.auto_fix_high,
                  ),
                  label: Text(
                    scanning ? "Analyzing..." : "START AI ANALYSIS",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

