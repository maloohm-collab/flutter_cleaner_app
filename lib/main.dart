import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/activation_screen.dart';
import 'screens/home_screen.dart';
import 'utils/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CleanerApp());
}

class CleanerApp extends StatelessWidget {
  const CleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Optimizer',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF172A45),
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const StartupGate(),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Future<bool> _activationCheck = _checkActivation();

  Future<bool> _checkActivation() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('subscription_phone');
    if (phone == null || phone.trim().isEmpty) return false;

    try {
      final response = await FirebaseFunctions.instance
          .httpsCallable('checkSubscription')
          .call(<String, dynamic>{'phone': phone});
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['active'] != true || data['expiresAt'] is! String) {
        await prefs.remove('subscription_expiry_ms');
        await prefs.remove('subscription_activated_at_ms');
        await prefs.remove('subscription_phone');
        return false;
      }

      final expiry = DateTime.parse(data['expiresAt'] as String);
      await prefs.setInt('subscription_expiry_ms', expiry.millisecondsSinceEpoch);
      return expiry.isAfter(DateTime.now());
    } on FirebaseFunctionsException {
      // Keep a previously verified, unexpired subscription available during
      // temporary network/backend outages; never grant access without a cache.
      final cachedExpiry = prefs.getInt('subscription_expiry_ms');
      return cachedExpiry != null &&
          DateTime.now().millisecondsSinceEpoch < cachedExpiry;
    } catch (_) {
      final cachedExpiry = prefs.getInt('subscription_expiry_ms');
      return cachedExpiry != null &&
          DateTime.now().millisecondsSinceEpoch < cachedExpiry;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _activationCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == true
            ? const HomeScreen()
            : const ActivationScreen();
      },
    );
  }
}
