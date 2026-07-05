import 'package:flutter/material.dart';

import '../services/cleaner_service.dart';
import '../utils/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/progress_ring.dart';
import '../widgets/stat_card.dart';

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

  final List<String> logs = [];

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

    await cleaner.startCleaning(

      onLog: (msg) {

        setState(() {

          logs.insert(0, msg);

          progress += 0.02;

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

      progress = 1;

      status = "Optimization Complete";

      logs.insert(0, "Finished Successfully");

    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: AppBar(

        elevation: 0,

        backgroundColor: Colors.transparent,

        centerTitle: true,

        title: const Text(
          "AI OPTIMIZER",
          style: TextStyle(
            letterSpacing: 2,
          ),
        ),

        actions: [

          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),

        ],

      ),

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(18),

          child: Column(

            children: [

              ProgressRing(

                progress: progress,

                title: status,

                subtitle: scanning ? "AI Running..." : "System Ready",

              ),

              const SizedBox(height: 25),

              Expanded(

                child: GridView.count(

                  physics: const NeverScrollableScrollPhysics(),

                  crossAxisCount: 2,

                  mainAxisSpacing: 14,

                  crossAxisSpacing: 14,

                  childAspectRatio: 1.2,

                  children: [

                    StatCard(

                      icon: Icons.delete,

                      title: "Files Cleaned",

                      value: cleaner.deletedFiles.toString(),

                    ),

                    StatCard(

                      icon: Icons.folder,

                      title: "Folders",

                      value: cleaner.scannedFolders.toString(),

                      color: AppColors.warning,

                    ),

                    StatCard(

                      icon: Icons.description,

                      title: "Files Scanned",

                      value: cleaner.scannedFiles.toString(),

                      color: AppColors.success,

                    ),

                    StatCard(

                      icon: Icons.storage,

                      title: "Space Saved",

                      value: cleaner.formattedSize,

                      color: AppColors.secondary,

                    ),

                  ],

                ),

              ),

              Container(

                height: 150,

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(

                  color: AppColors.card,

                  borderRadius: BorderRadius.circular(18),

                ),

                child: logs.isEmpty

                    ? const Center(

                        child: Text(

                          "No activity yet",

                          style: TextStyle(
                            color: Colors.white54,
                          ),
                        ),
                      )

                    : ListView.builder(

                        itemCount: logs.length,

                        itemBuilder: (_, i) {

                          return Padding(

                            padding: const EdgeInsets.symmetric(vertical: 2),

                            child: Text(

                              "• ${logs[i]}",

                              style: const TextStyle(
                                color: Colors.greenAccent,
                              ),

                            ),

                          );

                        },

                      ),

              ),

              const SizedBox(height: 20),

              AnimatedButton(

                title: scanning
                    ? "SCANNING..."
                    : "RUN AI CLEAN",

                icon: Icons.auto_fix_high,

                onPressed: scanning
                    ? null
                    : startCleaning,

              ),

            ],

          ),

        ),

      ),

    );

  }

}
