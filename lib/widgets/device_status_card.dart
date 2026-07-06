import 'package:flutter/material.dart';
import '../utils/colors.dart';

class DeviceStatusCard extends StatelessWidget {

  final String androidVersion;
  final int health;

  const DeviceStatusCard({
    super.key,
    required this.androidVersion,
    required this.health,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [

          const Row(
            children: [
              Icon(Icons.phone_android),
              SizedBox(width: 10),
              Text(
                "Device Information",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            ],
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Android"),
              Text(androidVersion),
            ],
          ),

          const Divider(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("AI Health"),
              Text("$health%"),
            ],
          ),

        ],
      ),
    );

  }

}
