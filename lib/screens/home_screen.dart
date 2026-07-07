import 'package:flutter/material.dart';

// الاستيرادات القياسية للمحرك والحالة الموحدة
import 'package:flutter_cleaner_app/services/cleaner_engine.dart';
import 'package:flutter_cleaner_app/services/scan_pipeline.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart'; 
import 'package:flutter_cleaner_app/models/dashboard_state.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  DashboardState state = const DashboardState();
  List<ScanItem> scanItems = [];
  final List<Map<String, String>> logs = [];

  bool _hasScanned = false;
  bool _isOptimized = false;
  int healthScore = 100;

  @override
  void initState() {
    super.initState();
    state = state.copyWith(
      currentTask: "Tap Below to Scan System",
      progress: 0,
      healthScore: 100,
    );
  }

  // دالة الفحص الذكي
  Future<void> startAnalysis() async {
    if (state.scanning) return;

    setState(() {
      logs.clear();
      _hasScanned = false;
      _isOptimized = false;
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
          state = state.copyWith(progress: progress, currentTask: message);
        });
        _addLog(message);
      },
    );

    scanItems = await _engine.scan(
      onStatus: (msg) {
        if (!mounted) return;
        _addLog(msg);
        setState(() { state = state.copyWith(currentTask: msg); });
      },
      onProgress: (p) {
        if (!mounted) return;
        setState(() { state = state.copyWith(progress: p); });
      },
    );

    if (!mounted) return;

    setState(() {
      _hasScanned = true;
      healthScore = (_engine.totalFiles == 0)
          ? 100
          : (100 - (_engine.totalFiles ~/ 5)).clamp(55, 95);

      state = state.copyWith(
        scanning: false,
        analysisFinished: true,
        progress: 1.0,
        currentTask: "Analysis Complete",
        totalFiles: _engine.totalFiles,
        totalBytes: _engine.totalBytes,
        healthScore: healthScore.toDouble(),
      );
    });
  }

  // دالة التنظيف الفعلي مع إصلاح تضارب الحالات بشكل قطعي
  Future<void> performCleaning() async {
    if (state.scanning) return;

    final selectedItems = scanItems.where((item) => item.selected).toList();
    
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one item to clean.")),
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
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD700), size: 22),
              SizedBox(width: 8),
              Text("Confirm Deletion", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Are you sure you want to permanently delete the selected files (${formatBytes(state.totalBytes.toInt())})?",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Clean Now", style: TextStyle(color: Color(0xFF00F2FE), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (shouldClean != true) return;

    // الدخول في حالة التنظيف الفوري وقفل الأزرار بشكل صحيح
    setState(() {
      state = state.copyWith(
        scanning: true, // تفعيل المؤشر الحركي للتنظيف
        analysisFinished: false,
        currentTask: "Executing deep clean...",
        progress: 0.2,
      );
      logs.clear();
    });

    await _engine.clean(
      selected: selectedItems,
      onStatus: (msg) {
        if (!mounted) return;
        _addLog(msg);
        setState(() { state = state.copyWith(currentTask: msg); });
      },
    );

    // محاكاة رقمية سريعة ومحكمة لإنهاء شريط التقدم بلمسة سينمائية
    for (double p = 0.4; p <= 1.0; p += 0.2) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() { state = state.copyWith(progress: p); });
    }

    if (!mounted) return;

    // حـل الـ Bug الرئيسي: إغلاق حالة الـ scanning فوراً وتصفير العدادات وتحديث راية التحسين
    setState(() {
      scanItems.clear();
      _isOptimized = true;
      _hasScanned = true;
      healthScore = 100; // الآن فقط يصح أن يصبح 100% ممتاز
      
      state = state.copyWith(
        scanning: false, // تحرير الزر من حالة PROCESSING... عـلـى الـفـور
        analysisFinished: false,
        progress: 0.0,
        currentTask: "System Fully Optimized!",
        totalFiles: 0,
        totalBytes: 0,
        healthScore: 100,
      );
      _addLog("Optimization Complete. Device Status: Excellent.");
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

  // نافذة الاشتراك المميز المنبثقة التفاعلية لإحياء الزر العلوي
  void _showPremiumSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1326),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 45),
              const SizedBox(height: 12),
              const Text("Upgrade to AI Premium", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Unlock advanced deep cleaning, automated daily background scheduling, and real-time security scanning updates.", 
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F2FE),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Get Premium - \$4.99/mo", style: TextStyle(color: Color(0xFF090D1A), fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      // قائمة جانبية حقيقية لإحياء زر القائمة
      drawer: Drawer(
        backgroundColor: const Color(0xFF090D1A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF0E1326)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("AI OPTIMIZER PRO", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  SizedBox(height: 4),
                  Text("v1.0.0 - Premium Activated", style: TextStyle(color: Color(0xFF00F2FE), fontSize: 12)),
                ],
              ),
            ),
            ListTile(leading: const Icon(Icons.shield_outlined, color: Colors.white70), title: const Text("AI Deep Shield", style: TextStyle(color: Colors.white)), onPressed: (){}),
            ListTile(leading: const Icon(Icons.history_toggle_off_rounded, color: Colors.white70), title: const Text("Cleaning History", style: TextStyle(color: Colors.white)), onPressed: (){}),
            ListTile(leading: const Icon(Icons.info_outline_rounded, color: Colors.white70), title: const Text("About Engine", style: TextStyle(color: Colors.white)), onPressed: (){}),
          ],
        ),
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        centerTitle: true,
        title: const Text(
          "AI OPTIMIZER",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 24),
            onPressed: _showPremiumSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 5),

              // 1. حلقة التقدم المركزية
              ProgressRing(
                progress: state.progress,
                title: state.currentTask,
                subtitle: state.scanning ? "AI Engine Active..." : "System Gatekeeper",
              ),

              const SizedBox(height: 12),

              // 2. الكروت الجانبية المحدثة هندسياً والمحمية من التداخل والقطع البصري
              Row(
                children: [
                  Expanded(child: _buildDynamicHealthCard()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDynamicStatusCard()),
                ],
              ),

              const SizedBox(height: 12),

              // 3. شريط الأرقام الإحصائي المدمج
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn("${state.totalFiles}", "Files Out", const Color(0xFF00F2FE)),
                    Container(width: 1, height: 22, color: Colors.white10),
                    _buildStatColumn(formatBytes(state.totalBytes.toInt()), "Junk Size", const Color(0xFFE040FB)),
                    Container(width: 1, height: 22, color: Colors.white10),
                    _buildStatColumn(state.scanning ? "${(state.progress * 100).toInt()}%" : "100%", "Engine Stability", const Color(0xFF00E676)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 4. منطقة العرض الذكية الديناميكية المتبادلة بالكامل لقفل المساحة الملمومة
              Expanded(
                child: scanItems.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Detected Items", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.builder(
                              itemCount: scanItems.length,
                              itemBuilder: (context, index) {
                                return ScanResultCard(
                                  item: scanItems[index],
                                  onChanged: (value) {
                                    setState(() {
                                      scanItems[index] = scanItems[index].copyWith(selected: value ?? true);
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
                              const Text("Live AI Core Logs", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                onPressed: () {},
                                child: const Text("View All >", style: TextStyle(color: Color(0xFF4FACFE), fontSize: 12)),
                              ),
                            ],
                          ),
                          Container(
                            height: 70, 
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.01),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.02)),
                            ),
                            child: logs.isEmpty
                                ? const Center(child: Text("No deep scanning logs registered yet.", style: TextStyle(color: Colors.white24, fontSize: 11)))
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
                                                  Icon(Icons.gpp_good_outlined, color: const Color(0xFF00E676).withOpacity(0.7), size: 12),
                                                  const SizedBox(width: 6),
                                                  Expanded(child: Text(logs[i]["message"]!, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                                ],
                                              ),
                                            ),
                                            Text(logs[i]["time"]!, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 10),
                          const Text("Smart Tools", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInteractiveTool(Icons.cleaning_services_outlined, "Deep Clean"),
                              _buildInteractiveTool(Icons.folder_open_outlined, "Large Files"),
                              _buildInteractiveTool(Icons.copy_all_outlined, "Duplicates"),
                              _buildInteractiveTool(Icons.developer_mode_outlined, "App Manager"),
                            ],
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 12),

              // 5. زر آلة الحالة الذكي والمحمي تماماً من التعليق العشوائي والتضارب البصري
              AnimatedButton(
                title: state.scanning
                    ? "PROCESSING DEEP CLEAN..."
                    : state.analysisFinished
                        ? "START OPTIMIZATION"
                        : _isOptimized 
                            ? "SYSTEM SECURED & READY" 
                            : "START AI ANALYSIS",
                icon: state.scanning
                    ? Icons.hourglass_top_rounded
                    : state.analysisFinished
                        ? Icons.bolt_rounded
                        : _isOptimized 
                            ? Icons.verified_user_rounded 
                            : Icons.radar_rounded,
                onPressed: state.scanning
                    ? null
                    : state.analysisFinished
                        ? performCleaning
                        : startAnalysis,
              ),
              const SizedBox(height: 8),
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
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded, size: 20), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.construction_rounded, size: 20), label: "Tools"),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined, size: 20), label: "Monitor"),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined, size: 20), label: "Settings"),
        ],
      ),
    );
  }

  // كارت الصحة الديناميكي المطور محلياً لحل مشكلة الرقم الثابت والتداخل البصري
  Widget _buildDynamicHealthCard() {
    String scoreText = "--";
    String descText = "Scan Required";
    Color txtColor = Colors.white38;
    Gradient cardGrad = LinearGradient(colors: [Colors.white.withOpacity(0.04), Colors.white.withOpacity(0.02)]);

    if (state.scanning) {
      scoreText = "SCAN";
      descText = "Analyzing...";
      txtColor = const Color(0xFFFFD700);
    } else if (_isOptimized) {
      scoreText = "100%";
      descText = "Excellent";
      txtColor = const Color(0xFF00E676);
      cardGrad = const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)]);
    } else if (_hasScanned) {
      scoreText = "$healthScore%";
      descText = healthScore > 80 ? "Good" : "Warning";
      txtColor = healthScore > 80 ? const Color(0xFF00F2FE) : Colors.orangeAccent;
      cardGrad = LinearGradient(colors: [Colors.red.withOpacity(0.15), Colors.orange.withOpacity(0.05)]);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      height: 90,
      decoration: BoxDecoration(
        gradient: cardGrad,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("AI HEALTH", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(scoreText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.black, height: 1.1)),
          const SizedBox(height: 2),
          Text(descText, style: TextStyle(color: txtColor, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // كارت الحالة والمسار المطور محلياً لمنع الاختناق النصي والتداخل
  Widget _buildDynamicStatusCard() {
    String statusTitle = "MONITOR";
    String statusSub = state.scanning ? "Optimizing Channels" : (_isOptimized ? "Secure" : "Idle State");
    
    return Container(
      padding: const EdgeInsets.all(12),
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(_isOptimized ? Icons.verified_user_outlined : Icons.radar_outlined, color: const Color(0xFF00F2FE), size: 14),
              const SizedBox(width: 4),
              Text(statusTitle, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(state.currentTask, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(statusSub, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          )
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String title, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  // أداة ذكية متفاعلة وموحدة الأيقونات والأحجام بشكل نيون فاخر
  Widget _buildInteractiveTool(IconData icon, String label) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Launching $label module..."), duration: const Duration(milliseconds: 600)),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Icon(icon, color: const Color(0xFF00F2FE), size: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}
