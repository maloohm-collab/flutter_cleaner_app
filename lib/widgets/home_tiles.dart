import 'package:flutter/material.dart';
import '../utils/colors.dart';

class StatColumn extends StatelessWidget {
  final String value; final String title; final Color valueColor;
  const StatColumn(this.value, this.title, this.valueColor, {super.key});
  @override
  Widget build(BuildContext context) => Flexible(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2), Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
  ]));
}
class WideToolTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  const WideToolTile(this.icon, this.title, this.subtitle, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Material(color: AppColors.card, borderRadius: BorderRadius.circular(16), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Row(children: [
    Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppColors.primary.withAlpha(26), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: AppColors.primary, size: 24)),
    const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)), const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
    ])), const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
  ]))));
}
class InteractiveToolTile extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const InteractiveToolTile(this.icon, this.label, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Material(color: AppColors.card, borderRadius: BorderRadius.circular(16), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Container(constraints: const BoxConstraints(minHeight: 94), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withAlpha(26), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: AppColors.primary, size: 22)),
    const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
  ]))));
}
