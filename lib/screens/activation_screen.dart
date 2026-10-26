import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isActivating = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _normalizePhone(String value) {
    var phone = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.startsWith('+')) phone = phone.substring(1);
    if (phone.startsWith('00')) phone = phone.substring(2);
    if (phone.startsWith('0')) phone = '962${phone.substring(1)}';
    return phone;
  }

  Future<void> _contactWhatsApp() async {
    final phone = _normalizePhone(_phoneController.text);
    final message = phone.isEmpty
        ? 'مرحباً، أريد طلب كود تفعيل AI Optimizer لمدة شهر مقابل 2 دينار.'
        : 'مرحباً، أريد طلب كود تفعيل AI Optimizer لمدة شهر مقابل 2 دينار. رقم هاتفي: $phone';
    final uri = Uri.parse(
      'https://wa.me/962780494789?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب. اتصل على 0780494789.')),
      );
    }
  }

  Future<void> _activate() async {
    if (_isActivating) return;
    final phone = _normalizePhone(_phoneController.text);
    final code = _codeController.text.trim().toUpperCase();

    if (!RegExp(r'^9627[789][0-9]{7}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم هاتف أردني صحيحًا مثل 079XXXXXXX.')),
      );
      return;
    }
    if (!RegExp(r'^[A-F0-9]{12}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل كود التفعيل الصحيح المكوّن من 12 خانة.')),
      );
      return;
    }

    setState(() => _isActivating = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('redeemActivationCode')
          .call<Map<String, dynamic>>({'phone': phone, 'code': code});
      final data = result.data;
      if (data['success'] != true) {
        throw Exception('Activation was not confirmed by the server.');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription_phone', phone);
      if (!mounted) return;
      final expiry = data['expiresAt'] is String
          ? DateTime.tryParse(data['expiresAt'] as String)
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(expiry == null
              ? 'تم تفعيل الاشتراك بنجاح.'
              : 'تم التفعيل بنجاح حتى ${expiry.day}/${expiry.month}/${expiry.year}.'),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = e.code == 'invalid-argument'
          ? 'رقم الهاتف أو كود التفعيل غير صحيح.'
          : e.code == 'failed-precondition'
              ? 'الكود غير صالح أو سبق استخدامه.'
              : e.code == 'permission-denied'
                  ? 'ليس لديك صلاحية لتنفيذ الطلب.'
                  : 'تعذّر التفعيل الآن. تحقق من إعدادات Firebase والإنترنت.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء التفعيل. حاول مرة أخرى.')),
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
                        const GlowLogo(size: 108)
                            .animate()
                            .fade(duration: 600.ms)
                            .slideY(begin: -.2),
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
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'رقم الهاتف المرتبط بالاشتراك',
                            hintText: '07XXXXXXXX',
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
                            labelText: 'كود التفعيل',
                            hintText: 'أدخل الكود الذي استلمته',
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
                          title: _isActivating ? 'جارٍ التحقق...' : 'تحقق من التفعيل',
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
                              child: Text('طلب كود التفعيل عبر واتساب — 2 دينار'),
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.05),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Column(
                            children: [
                              _FeatureRow(
                                icon: Icons.cleaning_services_outlined,
                                title: 'تنظيف الملفات غير الضرورية',
                                subtitle: 'مع مراجعة النتائج قبل الحذف',
                              ),
                              Divider(color: Colors.white12, height: 22),
                              _FeatureRow(
                                icon: Icons.phone_android,
                                title: 'اشتراك مرتبط برقمك',
                                subtitle: 'كود واحد لمدة شهر بعد تأكيد الدفع',
                              ),
                              Divider(color: Colors.white12, height: 22),
                              _FeatureRow(
                                icon: Icons.lock_outline,
                                title: 'تفعيل آمن',
                                subtitle: 'التحقق من الاشتراك عبر الخادم',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'الدفع يتم يدوياً بعد التواصل عبر واتساب. لا ترسل بيانات محفظتك السرية أو كلمة مرورك.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 11),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: const Color(0xFF00F2FE), size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
}
