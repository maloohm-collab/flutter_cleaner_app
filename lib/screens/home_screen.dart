Import 'package:flutter/material.dart';

// الاستيرادات القياسية للمحرك والحالة الموحدة
import 'package:flutter_cleaner_app/services/cleaner_engine.dart';
import 'package:flutter_cleaner_app/services/scan_pipeline.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart'; 
import 'package:flutter_cleaner_app/models/dashboard_state.dart';
import 'package:flutter_cleaner_app/widgets/scan_result_card.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/progress_ring.dart';

import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 📝 المحرك المسؤول عن الفحص والتنظيف
  final CleanerEngine _engine = CleanerEngine();

  // 📝 خط المعالجة (Pipeline) للفحص التدريجي
  final ScanPipeline _pipeline = ScanPipeline();

  // 📝 مفتاح للتحكم بالـ Scaffold (Drawer, SnackBar)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 📝 الحالة العامة للواجهة
  DashboardState state = const DashboardState();

  // 📝 العناصر التي تم اكتشافها أثناء الفحص
  List<ScanItem> scanItems = [];

  // 📝 سجل الأحداث والرسائل اللحظية
  final List<Map<String, String>> logs = [];

  // 📝 أعلام مرتبطة بالحالة الفعلية
  bool _hasScanned = false;   
  bool _isOptimized = false;  
  bool _isCleaning = false;   

  // 📝 مؤشر الصحة (قيمة ابتدائية مرتبطة بالحالة)
  static const int maxHealthScore = 100; 
  int healthScore = maxHealthScore;

  // 📝 مؤشر التبويب الحالي في الـ BottomNavigationBar
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    // ربط القيم بالحالة الحقيقية للمحرك بدل القيم الوهمية
    healthScore = (_engine.totalFiles == 0)
        ? maxHealthScore
        : (maxHealthScore - (_engine.totalFiles ~/ 10)).clamp(40, maxHealthScore);

    _hasScanned = _engine.totalFiles > 0;
    _isOptimized = healthScore == maxHealthScore;

    state = state.copyWith(
      currentTask: _engine.isInitialized 
          ? "Ready to Scan" 
          : "Initializing Engine...",
      progress: _pipeline.progress ?? 0.0,
      healthScore: healthScore,
    );
  }
}

/// بدء عملية الفحص والتحليل
  Future<void> startAnalysis() async {
    // 1. التحقق من الصلاحيات
    if (!await Permission.storage.request().isGranted &&
        !await Permission.manageExternalStorage.request().isGranted) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Storage permission is required to scan files."),
        ),
      );
      return;
    }

    // 2. التحقق من حالة الفحص والتنظيف
    if (state.scanning || _isCleaning) return;

    // 3. طلب صلاحيات الوسائط (للأندرويد الحديث)
    await [
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();

    // 4. ضبط حالة البداية بالقيم الحقيقية بدل الوهمية
    setState(() {
      logs.clear();
      _hasScanned = _engine.totalFiles > 0;   
      _isOptimized = healthScore == maxHealthScore; 
      state = state.copyWith(
        scanning: true,
        analysisFinished: false,
        progress: _pipeline.progress ?? 0.0, // ربط بتقدم الـ Pipeline إن وجد
        currentTask: _engine.isInitialized 
            ? "Engine Ready - Starting Analysis" 
            : "Initializing AI Engine...",
      );
    });
  }

Future<void> runAnalysis() async {
    // 5. بدء الـ Pipeline
    await _pipeline.start(
      onStage: (stage, progress, message) async {
        if (!mounted) return;
        setState(() {
          // ربط التقدم الفعلي بالـ Pipeline بدل النسبة الوهمية
          state = state.copyWith(progress: progress, currentTask: message);
        });
        _addLog(message);
      },
    );

    // 6. بدء الفحص الحقيقي
    scanItems = await _engine.scan(
      onStatus: (msg) {
        if (!mounted) return;
        _addLog(msg);
        setState(() { state = state.copyWith(currentTask: msg); });
      },
      onProgress: (p) {
        if (!mounted) return;
        // ربط التقدم الفعلي بالفحص بدل النسب الوهمية
        setState(() { state = state.copyWith(progress: p); });
      },
    );

    // 7. إنهاء الفحص وتحديث الواجهة
    if (!mounted) return;

    setState(() {
      _hasScanned = true;

      // حساب الصحة بناءً على الملفات الفعلية
      healthScore = (_engine.totalFiles == 0)
          ? maxHealthScore
          : (maxHealthScore - (_engine.totalFiles ~/ 10))
              .clamp(40, maxHealthScore);

      state = state.copyWith(
        scanning: false,
        analysisFinished: true,
        progress: 1.0,
        currentTask: _engine.totalFiles == 0 
            ? "System Clean - No Junk Found" 
            : "Analysis Complete - Junk Detected",
        totalFiles: _engine.totalFiles,
        totalBytes: _engine.totalBytes,
        healthScore: healthScore.toDouble(),
      );
    });
  }


Future<void> performCleaning() async {
    if (state.scanning || _isCleaning) return;

    // ربط العناصر المختارة بالحالة الفعلية
    final selectedItems = scanItems.where((item) => item.selected).toList();
    
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No files selected for cleaning.")),
      );
      return;
    }

    // حساب الحجم الفعلي للملفات المختارة
    final int selectedBytes = selectedItems.fold(0, (sum, item) => sum + item.size);

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
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD700), size: 22),
              SizedBox(width: 8),
              Text("Confirm Deletion", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            selectedItems.length == 1
              ? "Delete ${selectedItems.first.name} (${formatBytes(selectedBytes)}) permanently?"
              : "Delete ${selectedItems.length} files (${formatBytes(selectedBytes)}) permanently?",
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

    // هنا سيبدأ التنفيذ الفعلي للتنظيف (يُكمل في الجزء الخامس)
  }


if (shouldClean != true) return;

    setState(() {
      _isCleaning = true;
      state = state.copyWith(
        scanning: false, 
        analysisFinished: false,
        currentTask: "Executing Deep Clean...",
        progress: 0.0, // يبدأ من صفر فعلي بدل 0.1 وهمي
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
      onProgress: (p) {
        if (!mounted) return;
        // ربط التقدم الفعلي من المحرك بدل النسب الوهمية
        setState(() { state = state.copyWith(progress: p); });
      },
    );

    // خطوات التنظيف مرتبطة بالعناصر الفعلية
    for (int i = 0; i < selectedItems.length; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        state = state.copyWith(
          progress: (i + 1) / selectedItems.length, // نسبة فعلية
          currentTask: "Cleaning ${selectedItems[i].name}...",
        );
      });
    }


if (!mounted) return;

    setState(() {
      _isOptimized = true;
      _hasScanned = true;
      _isCleaning = false; 

      // حساب الصحة الفعلية بعد التنظيف
      healthScore = (_engine.totalFiles == 0)
          ? maxHealthScore
          : (maxHealthScore - (_engine.totalFiles ~/ 10))
              .clamp(40, maxHealthScore);

      state = state.copyWith(
        scanning: false, 
        analysisFinished: false,
        progress: 1.0,
        currentTask: _engine.totalFiles == 0 
            ? "System Clean - No Junk Remaining" 
            : "Optimization Complete - Residual Files Detected",
        totalFiles: _engine.totalFiles,
        totalBytes: _engine.totalBytes,
        healthScore: healthScore,
      );

      // سجل مرتبط بالنتيجة الفعلية
      _addLog(
        _engine.totalFiles == 0
          ? "Optimization Complete. Device Status: Excellent."
          : "Optimization Complete. Some residual files remain."
      );
    });

    // بعد انتهاء التنظيف أعد تشغيل الفحص مباشرة
    await startAnalysis();


void _showPremiumSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1326),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final premiumPrice = _engine.premiumPrice ?? "\$4.99/mo"; 
        final premiumStatus = _engine.isPremiumActive ? "Premium Activated" : "Free Version";

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 45),
              const SizedBox(height: 12),
              Text(
                _engine.isPremiumActive ? "AI Premium Active" : "Upgrade to AI Premium",
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _engine.isPremiumActive
                  ? "You already have access to advanced deep cleaning and real-time security."
                  : "Unlock advanced deep cleaning, automated scheduling, and real-time security scanning.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F2FE),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (!_engine.isPremiumActive) {
                    _engine.activatePremium(); // ربط بعملية التفعيل الفعلية
                  }
                  Navigator.pop(context);
                },
                child: Text(
                  _engine.isPremiumActive ? "Premium Active" : "Get Premium - $premiumPrice",
                  style: const TextStyle(color: Color(0xFF090D1A), fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final premiumStatus = _engine.isPremiumActive ? "Premium Activated" : "Free Version";

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: const Color(0xFF090D1A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0E1326)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("AI OPTIMIZER PRO", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text("v${_engine.version} - $premiumStatus", style: const TextStyle(color: Color(0xFF00F2FE), fontSize: 12)),
                ],
              ),
            ),


ListTile(
              leading: const Icon(Icons.shield_outlined, color: Colors.white70), 
              title: const Text("AI Deep Shield", style: TextStyle(color: Colors.white)), 
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _engine.isShieldActive 
                        ? "AI Deep Shield is currently active and monitoring threats."
                        : "AI Deep Shield is not yet available.",
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_toggle_off_rounded, color: Colors.white70), 
              title: const Text("Cleaning History", style: TextStyle(color: Colors.white)), 
              onTap: () {
                Navigator.pop(context);
                if (_engine.cleaningHistory.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No cleaning history available.")),
                  );
                } else {
                  // عرض السجل الفعلي
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Cleaning History"),
                      content: SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _engine.cleaningHistory.length,
                          itemBuilder: (_, i) {
                            final entry = _engine.cleaningHistory[i];
                            return ListTile(
                              title: Text("${entry.date} - ${formatBytes(entry.cleanedBytes)}"),
                              subtitle: Text("${entry.filesCount} files cleaned"),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: Colors.white70), 
              title: const Text("About Engine", style: TextStyle(color: Colors.white)), 
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: "AI Optimizer",
                  applicationVersion: _engine.version, // ربط بالإصدار الفعلي
                  applicationLegalese: "© ${_engine.author}", // ربط بالكاتب الفعلي
                );
              },
            ),

body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 5),

              ProgressRing(
                progress: state.progress,
                title: state.currentTask,
                subtitle: _isCleaning 
                    ? "Cleaning ${_engine.cleanedFilesCount} files..."
                    : (state.scanning 
                        ? "Scanning ${_engine.totalFiles} files detected..." 
                        : _engine.isInitialized 
                            ? "System Ready" 
                            : "Engine Initializing"),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: _buildDynamicHealthCard()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDynamicStatusCard()),
                ],
              ),

              const SizedBox(height: 12),

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
                    _buildStatColumn(
                      "${_engine.cleanedFilesCount}", 
                      _isCleaning || _isOptimized ? "Files Cleaned" : "Files Detected", 
                      const Color(0xFF00F2FE),
                    ),
                    Container(width: 1, height: 22, color: Colors.white10),
                    _buildStatColumn(
                      formatBytes(_engine.cleanedBytes), 
                      _isCleaning || _isOptimized ? "Space Freed" : "Junk Size", 
                      const Color(0xFFE040FB),
                    ),
                    Container(width: 1, height: 22, color: Colors.white10),
                    _buildStatColumn(
                      "${state.healthScore.toInt()}%", 
                      _isCleaning ? "Cleaning..." : "Performance", 
                      const Color(0xFF00E676),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

Expanded(
                child: _isCleaning
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Cleaning ${_engine.cleanedFilesCount} files...",
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : scanItems.isNotEmpty
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
                                  if (logs.isNotEmpty)
                                    TextButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text("Full Logs"),
                                            content: SizedBox(
                                              height: 200,
                                              child: ListView.builder(
                                                itemCount: logs.length,
                                                itemBuilder: (_, i) {
                                                  return ListTile(
                                                    title: Text(logs[i]["message"]!),
                                                    subtitle: Text(logs[i]["time"]!),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
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
                                    ? const Center(child: Text("No logs available.", style: TextStyle(color: Colors.white24, fontSize: 11)))
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
                                  _buildInteractiveTool(Icons.cleaning_services_outlined, "Deep Clean", performCleaning),
                                  _buildInteractiveTool(Icons.folder_open_outlined, "Large Files", _engine.showLargeFiles),
                                  _buildInteractiveTool(Icons.copy_all_outlined, "Duplicates", _engine.findDuplicates),
                                  _buildInteractiveTool(Icons.developer_mode_outlined, "App Manager", () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                                  }),
                                ],
                              ),
                            ],
                          ),
              ),

              const SizedBox(height: 12),

              AnimatedButton(
                title: _isCleaning
                    ? "Cleaning in Progress..."
                    : state.scanning
                        ? "Scanning Files..."
                        : state.analysisFinished
                            ? "Start Optimization"
                            : _isOptimized 
                                ? "System Optimized" 
                                : "Start AI Analysis",
                icon: _isCleaning || state.scanning
                    ? Icons.hourglass_top_rounded
                    : state.analysisFinished
                        ? Icons.bolt_rounded
                        : _isOptimized 
                            ? Icons.verified_user_rounded 
                            : Icons.radar_rounded,
                onPressed: state.scanning || _isCleaning
                    ? null
                    : state.analysisFinished
                        ? performCleaning
                        : startAnalysis,
              ),
              const SizedBox(height: 8),


