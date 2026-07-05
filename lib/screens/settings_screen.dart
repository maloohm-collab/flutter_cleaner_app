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
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),

      body: ListView(

        padding: const EdgeInsets.all(20),

        children: [

          const Text(
            "General",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Card(
            color: AppColors.card,
            child: SwitchListTile(
              value: animations,
              onChanged: (v) {
                setState(() => animations = v);
              },
              title: const Text("Animations"),
              subtitle: const Text("Enable UI animations"),
            ),
          ),

          Card(
            color: AppColors.card,
            child: SwitchListTile(
              value: vibration,
              onChanged: (v) {
                setState(() => vibration = v);
              },
              title: const Text("Vibration"),
              subtitle: const Text("Vibrate after cleaning"),
            ),
          ),

          Card(
            color: AppColors.card,
            child: SwitchListTile(
              value: autoClean,
              onChanged: (v) {
                setState(() => autoClean = v);
              },
              title: const Text("Auto Clean"),
              subtitle: const Text("Run cleaning automatically"),
            ),
          ),

          const SizedBox(height: 30),

          const Divider(),

          const SizedBox(height: 20),

          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Version"),
            subtitle: Text("AI Optimizer Premium v2.0"),
          ),

          const ListTile(
            leading: Icon(Icons.code),
            title: Text("Developer"),
            subtitle: Text("Mohammad Malooh"),
          ),

        ],

      ),

    );

  }

}
