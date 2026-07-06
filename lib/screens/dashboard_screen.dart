import 'package:flutter/material.dart';

import '../utils/colors.dart';
import '../widgets/health_score_card.dart';
import '../widgets/live_scan_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/info_tile.dart';

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
  children: const [

    StatCard(
      icon: Icons.delete_outline,
      title: "Files Found",
      value: "0",
    ),

    StatCard(
      icon: Icons.folder_open,
      title: "Folders",
      value: "0",
      color: AppColors.warning,
    ),

    StatCard(
      icon: Icons.storage,
      title: "Recovered",
      value: "0 MB",
      color: AppColors.success,
    ),

    StatCard(
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

const SizedBox(height: 30),
