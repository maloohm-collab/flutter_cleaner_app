import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ستحتاج لإضافته في pubspec لإظهار الوقت التلقائي في السجلات

import '../services/cleaner_service.dart';
import '../utils/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/progress_ring.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CleanerService cleaner = CleanerService();
  bool scanning = false;
  double progress = 0;
  String status = "Ready";
  final List<Map<String, String>> logs = []; // استخدام خريطة لحفظ السجل مع الوقت

  Future<void> startCleaning() async {
    if (scanning) return;

    bool granted = await cleaner.requestPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Storage permission denied"),
        ),
      );
      return;
    }

    setState(() {
      scanning = true;
      status = "Scanning...";
      progress = .05;
      logs.clear();
    });

    // إضافة سجل البداية الافتراضي المطابق للصورة
    _addLog("Scanning directories...");

    await cleaner.startCleaning(
      onLog: (msg) {
        setState(() {
          _addLog(msg);
          progress += 0.05;
          if (progress > .95) {
            progress = .95;
          }
        });
      },
      onUpdate: () {
        setState(() {});
      },
    );

    setState(() {
      scanning = false;
      progress = 1.0;
      status = "Optimization Complete";
      _addLog("Optimization Complete");
    });
  }

  // دالة مساعدة لصياغة السجلات مع الطوابع الزمنية الحالية
  void _addLog(String message) {
    final String timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
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
        // إضافة أيقونة القائمة الجانبية اليسرى كما في الصورة 1000204253.png
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
          // إضافة تاج الـ Premium الذهبي في الجانب الأيمن العلوي
          IconButton(
            icon: const Icon(Icons.workspace_premium_rounded, color: AppColors.accentGold, size: 26),
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
              // حلقة تقدم حقيقية ومحدثة لحظياً بناءً على التصميم المطور
              ProgressRing(
                progress: progress,
                isComplete: !scanning && progress == 1.0,
              ),

              const SizedBox(height: 25),

              // لوحة الإحصائيات الأفقية المدمجة المكونة من 3 أعمدة
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      cleaner.deletedFiles.toString(),
                      "Files Cleaned",
                      const Color(0xFF00F2FE),
                    ),
                    Container(width: 1, height: 35, color: Colors.white10),
                    _buildStatColumn(
                      cleaner.formattedSize,
                      "Space Freed",
                      const Color(0xFFE040FB),
                    ),
                    Container(width: 1, height: 35, color: Colors.white10),
                    _buildStatColumn(
                      scanning ? "${(progress * 100).toInt()}%" : "100%",
                      "Performance",
                      AppColors.successGreen,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // قسم عنوان لوحة السجلات (Scan Log) مع زر التوسيع الإضافي
              Row(
                mainAxisAlignment: MainAxisAlignment.between,
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

              // حاوية عرض قائمة السجلات الدقيقة
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withOpacity(0.4),
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
                                mainAxisAlignment: MainAxisAlignment.between,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: AppColors.successGreen.withOpacity(0.8),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        logs[i]["message"]!,
                                        style: const TextStyle(color: Colors.whitede, fontSize: 13),
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

              // قسم أدوات الصيانة الذكية (Smart Tools) المضاف من التصميم
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

              // زر الفحص الأساسي المعدل والمصلح بالكامل
              AnimatedButton(
                title: scanning ? "SCANNING..." : "RUN DEEP CLEAN",
                icon: scanning ? Icons.sync_rounded : Icons.cleaning_services,
                onPressed: scanning ? null : startCleaning,
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
      // إدراج شريط التنقل السفلي الاحترافي الكامل المتواجد بالصورة المعتمدة
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

  // بناء وحدة عرض إحصائيات الأعمدة
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

  // بناء مربعات أدوات الصيانة الفردية السفلية
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

