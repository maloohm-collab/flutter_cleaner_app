import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/glow_logo.dart';
import 'home_screen.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _login() {
    if (_controller.text.trim() == "Maloohm123") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid Activation Key"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.78),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const GlowLogo(size: 120)
                          .animate()
                          .fade(duration: 700.ms)
                          .slideY(begin: -0.4),

                      const SizedBox(height: 25),

                      const Text(
                        "AI SYSTEM ACCESS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      )
                          .animate()
                          .fade(delay: 200.ms),

                      const SizedBox(height: 8),

                      const Text(
                        "Smart Cleaner & Optimizer",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      )
                          .animate()
                          .fade(delay: 350.ms),

                      const SizedBox(height: 35),

                      const Text(
                        "Welcome Back!",
                        style: TextStyle(
                          color: Color(0xFF4FACFE),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate().fade(delay: 400.ms),
                      
                      const SizedBox(height: 6),
                      
                      const Text(
                        "Enter your access key to continue",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ).animate().fade(delay: 420.ms),

                      const SizedBox(height: 30),

                      TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Activation Key",
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(
                            Icons.vpn_key_rounded,
                            color: AppColors.primary,
                          ),
                          filled: true,
                          fillColor: AppColors.field,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      )
                          .animate()
                          .fade(delay: 450.ms)
                          .slideX(begin: -.3),

                      const SizedBox(height: 25),

                      AnimatedButton(
                        title: "INITIALIZE SYSTEM",
                        icon: Icons.arrow_forward,
                        onPressed: _login,
                      )
                          .animate()
                          .fade(delay: 600.ms)
                          .scale(),

                      const SizedBox(height: 40),

                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Quick Access",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildQuickAccessItem(Icons.search, "Smart Scan"),
                                _buildQuickAccessItem(Icons.delete_outline, "Junk Clean"),
                                _buildQuickAccessItem(Icons.speed, "Memory Boost"),
                                _buildQuickAccessItem(Icons.battery_charging_full, "Battery Saver"),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fade(delay: 700.ms).slideY(begin: 0.15),

                      const SizedBox(height: 35),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.shield_outlined, color: Colors.white38, size: 15),
                          SizedBox(width: 6),
                          Text(
                            "v1.0.0  •  Secure & Private",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessItem(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Icon(icon, color: const Color(0xFF00F2FE), size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

