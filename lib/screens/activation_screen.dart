import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isActivating = false;

  static const String _whatsAppNumber = '962780494789';

  @override
  void dispose() {
    _codeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _contactWhatsApp() async {
    final message = 'مرحباً، أريد الاشتراك في AI Optimizer لمدة شهر مقابل 2 دينار أردني.';
    final uri = Uri.parse(
      'https://wa.me/$_whatsAppNumber?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب. اتصل على 0780494789.')),
      );
    }
  }

  Future<void> _activate() async {
    if (_isActivating) return;
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (phone.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم الهاتف ورمز التفعيل.')),
      );
      return;
    }

    setState(() => _isActivating = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('redeemActivationCode');
      final response = await callable.call(<String, dynamic>{
        'phone': phone,
        'code': code,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['success'] != true || data['expiresAt'] is! String) {
        throw StateError('Invalid activation response');
      }
      final expiry = DateTime.parse(data['expiresAt'] as String);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription_phone', phone);
      await prefs.setInt('subscription_activated_at_ms', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('subscription_expiry_ms', expiry.millisecondsSinceEpoch);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم التحقق من الاشتراك وتفعيله حتى ${expiry.day}/${expiry.month}/${expiry.year}.'),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'resource-exhausted'
          ? 'تم تجاوز عدد المحاولات. حاول بعد ساعة.'
          : error.code == 'failed-precondition'
              ? 'رمز التفعيل غير صحيح أو سبق استخدامه.'
              : error.code == 'invalid-argument'
                  ? 'تحقق من رقم الهاتف ومفتاح الدولة، مثل +962 للأردن أو +1 للولايات المتحدة.'
                  : 'تعذر التحقق من الاشتراك. تحقق من الاتصال وحاول مجددًا.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إكمال التفعيل. حاول مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(.78)),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        const GlowLogo(size: 108),
                        const SizedBox(height: 22),
                        const Text(
                          'AI OPTIMIZER',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'تنظيف ذكي وآمن لمساحة هاتفك',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'تفعيل AI Optimizer',
                          style: TextStyle(color: Color(0xFF00F2FE), fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'أدخل رقم هاتفك مع مفتاح الدولة ورمز التفعيل. التطبيق متاح للمستخدمين حول العالم.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autocorrect: false,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف مع مفتاح الدولة',
                            hintText: '+962780494789 أو +14155552671',
                            prefixIcon: const Icon(Icons.phone_android, color: AppColors.primary),
                            filled: true,
                            fillColor: AppColors.field,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'رمز التفعيل',
                            hintText: 'أدخل رمز التفعيل',
                            prefixIcon: const Icon(Icons.key_rounded, color: AppColors.primary),
                            filled: true,
                            fillColor: AppColors.field,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        AnimatedButton(
                          title: _isActivating ? 'جارٍ التفعيل...' : 'تفعيل التطبيق',
                          icon: Icons.verified_user_outlined,
                          onPressed: _isActivating ? null : _activate,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _contactWhatsApp,
                            icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text('التواصل عبر واتساب للاستفسار'),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF25D366)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'اكتب رقمك الدولي مع مفتاح الدولة (مثل +962 للأردن أو +1 للولايات المتحدة). للمساعدة في الاشتراك أو التفعيل، تواصل مع فريق الدعم عبر واتساب.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
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
