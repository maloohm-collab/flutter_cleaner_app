import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/colors.dart';
import 'activation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool animations = true;
  bool vibration = true;
  bool _loadingSubscription = true;
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt('subscription_expiry_ms');
    if (!mounted) return;
    setState(() {
      _expiry = expiryMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiryMs);
      _loadingSubscription = false;
    });
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
        content: const Text(
          'سيتم إنهاء جلسة هذا الجهاز وإزالة حالة التفعيل المحلية. ستحتاج إلى التفعيل مجددًا للدخول.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('subscription_expiry_ms');
    await prefs.remove('subscription_activated_at_ms');
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ActivationScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _expiry != null && _expiry!.isAfter(DateTime.now());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _sectionTitle('الحساب والاشتراك'),
          const SizedBox(height: 10),
          _panel(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF173A55),
                    child: Icon(Icons.workspace_premium_outlined, color: AppColors.primary),
                  ),
                  title: const Text('حالة الاشتراك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    _loadingSubscription
                        ? 'جارٍ التحقق...'
                        : active
                            ? 'مفعّل حتى ${_formatDate(_expiry!)}'
                            : 'لا يوجد اشتراك مفعّل على هذا الجهاز',
                    style: TextStyle(color: active ? AppColors.success : AppColors.warning, height: 1.5),
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                  title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: const Text('إنهاء التفعيل المحلي على هذا الجهاز', style: TextStyle(color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('تفضيلات التطبيق'),
          const SizedBox(height: 10),
          _panel(
            child: Column(
              children: [
                SwitchListTile(
                  value: animations,
                  onChanged: (value) => setState(() => animations = value),
                  activeTrackColor: AppColors.primary,
                  title: const Text('المؤثرات الحركية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('تفضيل بصري لهذه الجلسة فقط', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const Divider(color: AppColors.border, height: 1),
                SwitchListTile(
                  value: vibration,
                  onChanged: (value) => setState(() => vibration = value),
                  activeTrackColor: AppColors.primary,
                  title: const Text('الاهتزاز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('الإعداد لا يفعّل الاهتزاز حاليًا؛ سيبقى تفضيلًا شكليًا حتى ربطه بوظيفة فعلية.', style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('حول التطبيق'),
          const SizedBox(height: 10),
          _panel(
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.shield_outlined, color: AppColors.primary),
                  title: Text('التنظيف الآمن أولًا', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text('لا يحذف التطبيق ملفاتك الشخصية تلقائيًا. راجع كل عنصر قبل الحذف.', style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
                ),
                Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text('AI Optimizer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text('الإصدار 1.0.0 • صُمّم لمساعدتك على فهم مساحة التخزين', style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
      );

  Widget _panel({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}
