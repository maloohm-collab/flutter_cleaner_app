import 'package:flutter/material.dart';

import '../utils/colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool vibration = true;
  bool animations = true;
  bool autoClean = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "General",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // تجميع خيارات التحكم داخل حاوية موحدة بتصميم زجاجي فخم لتوحيد الهوية البصرية
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: animations,
                  onChanged: (v) {
                    setState(() => animations = v);
                  },
                  activeColor: const Color(0xFF00F2FE),
                  title: const Text(
                    "Animations",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    "Enable UI animations",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
                ),
                SwitchListTile(
                  value: vibration,
                  onChanged: (v) {
                    setState(() => vibration = v);
                  },
                  activeColor: const Color(0xFF00F2FE),
                  title: const Text(
                    "Vibration",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    "Vibrate after cleaning",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
                ),
                SwitchListTile(
                  value: autoClean,
                  onChanged: (v) {
                    setState(() => autoClean = v);
                  },
                  activeColor: const Color(0xFF00F2FE),
                  title: const Text(
                    "Auto Clean",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    "Run cleaning automatically",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 35),

          const Text(
            "About",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // تجميع معلومات التطبيق والمطور داخل حاوية حداثية متناسقة
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.03)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Color(0xFF4FACFE)),
                  title: const Text(
                    "Version",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    "AI Optimizer Premium v1.0.0", // توحيد الإصدار ليتطابق مع شاشة الوصول
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
                ),
                ListTile(
                  leading: const Icon(Icons.code, color: Color(0xFF00F2FE)),
                  title: const Text(
                    "Developer",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    "Mohammad Malooh",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
