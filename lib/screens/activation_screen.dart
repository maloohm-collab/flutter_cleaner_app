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
                      const GlowLogo(size: 120)
                          .animate()
                          .fade(duration: 700.ms)
                          .slideY(begin: -0.4),

                      const SizedBox(height: 30),

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

                      const SizedBox(height: 10),

                      const Text(
                        "Secure AI Cleaning Engine",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      )
                          .animate()
                          .fade(delay: 350.ms),

                      const SizedBox(height: 45),

                      TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Activation Key",
                          hintStyle:
                              const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(
                            Icons.vpn_key_rounded,
                            color: AppColors.primary,
                          ),
                          filled: true,
                          fillColor: AppColors.field,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      )
                          .animate()
                          .fade(delay: 450.ms)
                          .slideX(begin: -.3),

                      const SizedBox(height: 30),

                      AnimatedButton(
                        title: "INITIALIZE SYSTEM",
                        icon: Icons.arrow_forward,
                        onPressed: _login,
                      )
                          .animate()
                          .fade(delay: 600.ms)
                          .scale(),

                      const SizedBox(height: 40),

                      const Text(
                        "AI Optimizer Premium",
                        style: TextStyle(
                          color: Colors.white38,
                          letterSpacing: 1.5,
                        ),
                      ),
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
}
