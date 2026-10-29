import 'package:flutter/material.dart';
import '../utils/colors.dart';

class StoragePermissionScreen extends StatelessWidget {
  const StoragePermissionScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background, foregroundColor: AppColors.textPrimary, elevation: 0, centerTitle: true, title: const Text('صلاحية الوصول إلى الملفات', style: TextStyle(fontWeight: FontWeight.bold))),
    body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: ListView(children: [
        const SizedBox(height: 8), const Center(child: Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 64)), const SizedBox(height: 16),
        const Text('يحتاج التطبيق إلى قراءة ملفات التخزين المشترك ليتمكن من الفحص', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, height: 1.4)),
        const SizedBox(height: 20),
        const _Reason(icon: Icons.search_rounded, title: 'لماذا نطلبها؟', text: 'للبحث في مجلدات مثل التنزيلات والصور عن الملفات المؤقتة والصور المصغرة وملفات APK والملفات المكررة.'),
        const _Reason(icon: Icons.verified_user_outlined, title: 'لا يُحذف شيء دون موافقتك', text: 'الفحص للقراءة فقط. لا يُحذف أي ملف إلا إذا اخترته بنفسك ثم أكدت الحذف.'),
        const _Reason(icon: Icons.lock_outline_rounded, title: 'ما لا يصل إليه التطبيق', text: 'لا يقرأ التطبيق بيانات التطبيقات الأخرى الخاصة (Android/data وAndroid/obb)، ولا يرفع ملفاتك إلى أي مكان.'),
        const _Reason(icon: Icons.settings_outlined, title: 'ماذا سيحدث بعد المتابعة؟', text: 'سيفتح Android صفحة إعدادات خاصة. فعّل خيار السماح بإدارة جميع الملفات لهذا التطبيق ثم ارجع إليه.'),
      ])),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.background, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('متابعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      const SizedBox(height: 8), TextButton(onPressed: () => Navigator.of(context).pop(false), style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary), child: const Text('ليس الآن', style: TextStyle(fontSize: 16))),
    ]))),
  );
}
class _Reason extends StatelessWidget {
  final IconData icon; final String title; final String text;
  const _Reason({required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: AppColors.primary, size: 24), const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)), const SizedBox(height: 4),
      Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
    ])),
  ]));
}
