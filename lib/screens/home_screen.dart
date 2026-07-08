import 'package:flutter/material.dart';
import 'package:flutter_cleaner_app/services/cleaner_engine.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/progress_ring.dart';
import '../widgets/scan_result_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CleanerEngine _engine = CleanerEngine();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // حالة النظام
  bool _scanning = false;
  bool _isCleaning = false;
  bool _hasScanned = false;
  bool _isOptimized = false;
  
  double _progress = 0.0;
  String _currentTask = "Tap Below to Scan System";
  int _healthScore = 100;
  int _currentIndex = 0;
  
  List<ScanItem> scanItems = [];
  final List<Map<String, String>> logs = [];

  // --- دوال التحكم ---

  Future<void> startAnalysis() async {
    if (!await Permission.storage.request().isGranted &&
        !await Permission.manageExternalStorage.request().isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Storage permission is required.")));
      return;
    }

    setState(() {
      _scanning = true;
      _progress = 0.0;
      _currentTask = "Initializing AI Engine...";
      logs.clear();
      scanItems.clear();
    });

    scanItems = await _engine.scan(
      onStatus: (msg) {
        if (!mounted) return;
        _addLog(msg);
        setState(() { _currentTask = msg; });
      },
      onProgress: (p) {
        if (!mounted) return;
        setState(() { _progress = p; });
      },
    );

    setState(() {
      _scanning = false;
      _hasScanned = true;
      _progress = 1.0;
      _currentTask = "Analysis Complete";
      _healthScore = (_engine.totalFiles == 0) ? 100 : (100 - (_engine.totalFiles ~/ 5)).clamp(55, 95);
    });
  }

  Future<void> performCleaning() async {
    final selectedItems = scanItems.where((item) => item.selected).toList();
    if (selectedItems.isEmpty) return;

    setState(() {
      _isCleaning = true;
      _currentTask = "Executing Deep Clean...";
    });

    await _engine.clean(
      selected: selectedItems,
      onStatus: (msg) {
        if (!mounted) return;
        _addLog(msg);
        setState(() { _currentTask = msg; });
      },
    );

    setState(() {
      _isCleaning = false;
      _hasScanned = false;
      _isOptimized = true;
      scanItems.clear();
      _currentTask = "System Fully Optimized!";
      _progress = 1.0;
      _healthScore = 100;
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Optimization Complete!")));
  }

  // --- دوال مساعدة ---

  void _addLog(String message) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    setState(() {
      logs.insert(0, {"time": timeStr, "message": message.startsWith("[AI]") ? message : "[AI] $message"});
    });
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / 1024 / 1024).toStringAsFixed(2)} MB";
  }

  // --- واجهة المستخدم ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        title: const Text("AI OPTIMIZER", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              ProgressRing(progress: _progress, title: _currentTask, subtitle: _isCleaning ? "Purging Garbage..." : "AI Engine"),
              
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(child: _buildInfoCard("HEALTH", "$_healthScore%", const Color(0xFF00E676))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoCard("JUNK", formatBytes(_engine.totalBytes), const Color(0xFFFFD700))),
                ],
              ),
              
              const SizedBox(height: 20),

              Expanded(
                child: scanItems.isEmpty 
                  ? _buildLogsView() 
                  : ListView.builder(
                      itemCount: scanItems.length,
                      itemBuilder: (_, i) => ScanResultCard(
                        item: scanItems[i],
                        onChanged: (val) => setState(() => scanItems[i] = scanItems[i].copyWith(selected: val)),
                      ),
                    ),
              ),

              AnimatedButton(
                title: _isCleaning ? "CLEANING..." : (_hasScanned ? "START OPTIMIZATION" : "START ANALYSIS"),
                icon: Icons.bolt,
                onPressed: (_scanning || _isCleaning) ? null : (_hasScanned ? performCleaning : startAnalysis),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildLogsView() {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(logs[i]["message"]!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: Text(logs[i]["time"]!, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF090D1A),
      child: Column(
        children: [
          const DrawerHeader(child: Center(child: Text("AI OPTIMIZER", style: TextStyle(color: Colors.white, fontSize: 20)))),
          ListTile(title: const Text("Settings", style: TextStyle(color: Colors.white)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          ListTile(title: const Text("About", style: TextStyle(color: Colors.white)), onTap: () => showAboutDialog(context: context, applicationName: "AI Optimizer")),
        ],
      ),
    );
  }
}

            ListTile(
              leading: const Icon(Icons.shield_outlined, color: Colors.white70), 
              title: const Text("AI Deep Shield", style: TextStyle(color: Colors.white)), 
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("This feature is under development"),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_toggle_off_rounded, color: Colors.white70), 
              title: const Text("Cleaning History", style: TextStyle(color: Colors.white)), 
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cleaning History will be implemented.")),
                );
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
                  applicationVersion: "1.0.0",
                  applicationLegalese: "© Mohammad Ghazi Abdullah Mallouh",
                );
              },
            ),
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
            onPressed: () {
              _showPremiumSheet();
            },
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

              ProgressRing(
                progress: state.progress,
                title: state.currentTask,
                subtitle: _isCleaning 
                    ? "Purging Device Garbage..." 
                    : (state.scanning ? "AI Engine Active..." : "System Gatekeeper"),
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
                    _buildStatColumn("${_engine.totalFiles}", _isCleaning || _isOptimized ? "Files Cleaned" : "Files Out", const Color(0xFF00F2FE)),
                    Container(width: 1, height: 22, color: Colors.white10),
                    _buildStatColumn(formatBytes(_engine.totalBytes.toInt()), _isCleaning || _isOptimized ? "Space Freed" : "Junk Size", const Color(0xFFE040FB)),
                    Container(width: 1, height: 22, color: Colors.white10),
                    _buildStatColumn("${state.healthScore.toInt()}%", _isCleaning ? "Cleaning..." : "Performance", const Color(0xFF00E676)),
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
                            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE))),
                            const SizedBox(height: 16),
                            Text(state.currentTask, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
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
                                  TextButton(
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("This feature is under development"),
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
                                    ? const Center(child: Text("No junk files found.", style: TextStyle(color: Colors.white24, fontSize: 11)))
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
                                  _buildInteractiveTool(
                                    Icons.cleaning_services_outlined,
                                    "Deep Clean",
                                    performCleaning,
                                  ),
                                  _buildInteractiveTool(
                                    Icons.folder_open_outlined,
                                    "Large Files",
                                    () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("This feature is under development"),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildInteractiveTool(
                                    Icons.copy_all_outlined,
                                    "Duplicates",
                                    () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("This feature is under development"),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildInteractiveTool(
                                    Icons.developer_mode_outlined,
                                    "App Manager",
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SettingsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
              ),

              const SizedBox(height: 12),

              AnimatedButton(
                title: _isCleaning
                    ? "PROCESSING DEEP CLEAN..."
                    : state.scanning
                        ? "PROCESSING AI ANALYSIS..."
                        : state.analysisFinished
                            ? "START OPTIMIZATION"
                            : _isOptimized 
                                ? "SYSTEM SECURED & READY" 
                                : "START AI ANALYSIS",
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF090D1A),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00F2FE),
        unselectedItemColor: Colors.white38,
        currentIndex: _currentIndex,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        onTap: (index) {
          setState(() => _currentIndex = index);

          switch (index) {
            case 0:
              break;

            case 1:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Tools module coming next")),
              );
              break;

            case 2:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("This feature is under development"),
                ),
              );
              break;

            case 3:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded, size: 20), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.construction_rounded, size: 20), label: "Tools"),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined, size: 20), label: "Monitor"),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined, size: 20), label: "Settings"),
        ],
      ),
    );
  }

  Widget _buildDynamicHealthCard() {
    String scoreText = "--";
    String descText = "Scan Required";
    Color txtColor = Colors.white38;
    Gradient cardGrad = LinearGradient(colors: [Colors.white.withOpacity(0.04), Colors.white.withOpacity(0.02)]);

    if (_isCleaning) {
      scoreText = "CLEAN";
      descText = "Optimizing Core...";
      txtColor = const Color(0xFF00F2FE);
      cardGrad = LinearGradient(colors: [const Color(0xFF00F2FE).withOpacity(0.15), Colors.blue.withOpacity(0.05)]);
    } else if (state.scanning) {
      scoreText = "SCAN";
      descText = "Analyzing...";
      txtColor = const Color(0xFFFFD700);
    } else if (_isOptimized) {
      scoreText = "${state.healthScore.toInt()}%";
      descText = "Optimized";
      txtColor = const Color(0xFF00E676);
      cardGrad = const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)]);
    } else if (_hasScanned) {
      scoreText = "${state.healthScore.toInt()}%";
      descText = state.healthScore > 80 ? "Good" : "Warning";
      txtColor = state.healthScore > 80 ? const Color(0xFF00F2FE) : Colors.orangeAccent;
      cardGrad = LinearGradient(colors: [Colors.red.withOpacity(0.1), Colors.orange.withOpacity(0.02)]);
    } else if (_engine.totalFiles > 0) {
      scoreText = "${state.healthScore.toInt()}%";
      descText = "Scanned";
      txtColor = const Color(0xFF00F2FE);
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
          const Text("AI HEALTH SCORE", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(scoreText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
          const SizedBox(height: 2),
          Text(descText, style: TextStyle(color: txtColor, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildDynamicStatusCard() {
    String statusTitle = _isCleaning ? "LIVE AI SCAN" : "SYSTEM STATUS";
    String statusSub = _isCleaning ? "Purging Files" : (state.scanning ? "Optimizing Channels" : (_isOptimized ? "Optimized" : "Idle"));

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

  Widget _buildInteractiveTool(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
