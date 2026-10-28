import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cleaner_app/services/duplicate_file_scanner.dart';
import 'package:flutter_cleaner_app/utils/colors.dart';

class DuplicateFilesScreen extends StatefulWidget {
  const DuplicateFilesScreen({super.key});

  @override
  State<DuplicateFilesScreen> createState() => _DuplicateFilesScreenState();
}

class _DuplicateFilesScreenState extends State<DuplicateFilesScreen> {
  final DuplicateFileScanner _scanner = DuplicateFileScanner();
  List<DuplicateFileGroup> _groups = const <DuplicateFileGroup>[];
  bool _scanning = false;
  bool _scanned = false;
  String _status = 'ابدأ الفحص للبحث عن نسخ متطابقة فعلًا.';
  int _generation = 0;

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _scan() async {
    if (_scanning) return;
    final generation = ++_generation;
    setState(() {
      _scanning = true;
      _scanned = false;
      _groups = const <DuplicateFileGroup>[];
      _status = 'جارٍ بدء الفحص...';
    });
    try {
      final results = await _scanner.scan(
        onStatus: (message) {
          if (!mounted || generation != _generation) return;
          setState(() => _status = message);
        },
        shouldCancel: () => !mounted || generation != _generation,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _groups = results;
        _scanned = true;
        _status = results.isEmpty
            ? 'لم يتم العثور على مجموعات مكررة مؤكدة ضمن الملفات التي أمكن قراءتها.'
            : 'عُثر على ${results.length} مجموعة من الملفات المتطابقة.';
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _status = 'تعذر إكمال الفحص. تحقق من صلاحيات الملفات ثم حاول مجددًا.');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _scanning = false);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final reclaimable = _groups.fold<int>(0, (sum, group) => sum + group.reclaimableBytes);
    final duplicateFiles = _groups.fold<int>(0, (sum, group) => sum + group.paths.length);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('الملفات المكررة', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.copy_all_rounded, color: AppColors.primary, size: 24),
                    SizedBox(width: 9),
                    Expanded(child: Text('اكتشاف النسخ المتطابقة', style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.bold,
                    ))),
                  ]),
                  const SizedBox(height: 9),
                  const Text(
                    'يتحقق الفحص من محتوى الملفات، وليس الاسم أو الحجم فقط. لا يحذف التطبيق أي نسخة من هذه الشاشة.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: _scanning
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search_rounded),
                      label: Text(_scanning ? 'جارٍ فحص الملفات...' : 'ابدأ فحص المكررات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF07121D),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  if (_scanning) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 4),
                  ],
                  const SizedBox(height: 10),
                  Text(_status, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                  if (_scanned && _groups.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _summary('المجموعات', '${_groups.length}')),
                      Expanded(child: _summary('الملفات', '$duplicateFiles')),
                      Expanded(child: _summary('المساحة المحتملة', _formatBytes(reclaimable))),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                      'المساحة المحتملة تقدير نظري عند الاحتفاظ بنسخة واحدة من كل مجموعة؛ لم يتم حذف أي ملف.',
                      style: TextStyle(color: AppColors.warning, fontSize: 12, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: !_scanned
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(mainAxisSize: MainAxisSize.min, children: const [
                          Icon(Icons.manage_search_rounded, size: 52, color: AppColors.primary),
                          SizedBox(height: 12),
                          Text('الفحص للقراءة فقط', style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold,
                          )),
                          SizedBox(height: 6),
                          Text('ستظهر هنا المجموعات التي ثبت تطابق محتويات ملفاتها.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
                        ]),
                      ),
                    )
                  : _groups.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('لا توجد نسخ متطابقة مؤكدة ضمن الملفات التي أمكن الوصول إليها.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5)),
                        ))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          itemCount: _groups.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final group = _groups[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ExpansionTile(
                                iconColor: AppColors.primary,
                                collapsedIconColor: AppColors.textSecondary,
                                title: Text('مجموعة ${index + 1} • ${_formatBytes(group.bytes)} لكل نسخة',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                                subtitle: Text('${group.paths.length} نسخ • مساحة محتملة ${_formatBytes(group.reclaimableBytes)}',
                                  style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                                children: [
                                  for (var i = 0; i < group.paths.length; i++)
                                    ListTile(
                                      leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.textSecondary),
                                      title: SelectableText(
                                        group.paths[i].split(Platform.pathSeparator).last,
                                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                      ),
                                      subtitle: SelectableText(group.paths[i],
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                                      trailing: IconButton(
                                        tooltip: 'نسخ المسار',
                                        icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('انسخ المسار من النص القابل للتحديد إذا لم يعمل النسخ التلقائي.')),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]),
  );
}
