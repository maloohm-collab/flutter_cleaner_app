import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/colors.dart';
import 'activation_screen.dart';

String subscriptionRemainingLabel(int daysLeft) {
  if (daysLeft <= 0) return 'ينتهي اليوم';
  if (daysLeft == 1) return 'متبقٍ يوم واحد';
  if (daysLeft == 2) return 'متبقٍ يومان';
  if (daysLeft <= 10) return 'متبقٍ ${daysLeft} أيام';
  return 'متبقٍ ${daysLeft} يومًا';
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loadingSubscription = true;
  DateTime? _expiry;
  DateTime? _activatedAt;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt('subscription_expiry_ms');
    final activatedMs = prefs.getInt('subscription_activated_at_ms');
    if (!mounted) return;
    setState(() {
      _expiry = expiryMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiryMs);
      _activatedAt = activatedMs == null ? null : DateTime.fromMillisecondsSinceEpoch(activatedMs);
      _loadingSubscription = false;
    });
  }

  double? _remainingFraction() {
    final expiry = _expiry;
    final activated = _activatedAt;
    if (expiry == null || activated == null) return null;
    final total = expiry.difference(activated).inSeconds;
    if (total <= 0) return null;
    final remaining = expiry.difference(DateTime.now()).inSeconds;
    return (remaining / total).clamp(0.0, 1.0).toDouble();
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
          'سيتم إنهاء التفعيل على هذا الجهاز وإزالة حالته المحلية. ستحتاج إلى إدخال رمز التفعيل مرة أخرى للمتابعة.',
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
    await prefs.remove('subscription_phone');
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loadingSubscription
                            ? 'جارٍ التحقق...'
                            : active
                                ? 'مفعّل حتى ${_formatDate(_expiry!)}'
                                : 'لا يوجد تفعيل محلي على هذا الجهاز',
                        style: TextStyle(color: active ? AppColors.success : AppColors.warning, height: 1.5),
                      ),
                      if (active) ...[
                        Text(subscriptionRemainingLabel(_expiry!.difference(DateTime.now()).inDays), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
                        if (_remainingFraction() != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: _remainingFraction(), minHeight: 6, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success))),
                        ],
                      ],
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                  title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: const Text('إنهاء الجلسة المحلية على هذا الجهاز', style: TextStyle(color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: _logout,
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: AppColors.card,
            child: child,
          ),
        ),
      );
}
