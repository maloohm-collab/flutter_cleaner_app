// ============================================================================
// Project      : AI Cleaner / AI Optimizer
// File         : lib/screens/home_screen.dart
// Version      : 1.1.0
// Last Updated : 2026-10-10
// Purpose      : الواجهة الرئيسية لفحص الملفات المرشحة، وعرض النتائج، والسماح
//                للمستخدم باختيار الملفات وتأكيد حذفها من خلال CleanerEngine.
// ----------------------------------------------------------------------------
// Changes in v1.1.0:
// - إصلاح قابلية تعديل قائمة نتائج الفحص في الواجهة.
// - إضافة استيراد PlatformException الصحيح.
// - الحفاظ على التصميم العام ومكونات الواجهة الحالية.
// - منع بدء الفحص أثناء التنظيف أو بدء فحص آخر.
// - إبقاء تأكيد المستخدم شرطًا قبل الحذف.
// - توضيح الفرق بين الحجم المرصود والحجم المحرر فعليًا.
// - عدم الادعاء بتنظيف بيانات التطبيقات الأخرى الخاصة.
// ----------------------------------------------------------------------------
// Safety Notes:
// - الملفات المرشحة ليست بالضرورة ملفات غير مهمة.
// - لا يتم الحذف قبل موافقة المستخدم.
// - نتائج الفحص لا تعني أن الملفات حُذفت.
// - الحجم المحدد للحذف ليس ضمانًا للحجم الذي سيتحرر فعليًا.
// - يجب أن يتحقق CleanerEngine من المسارات قبل الحذف.
// ----------------------------------------------------------------------------
// Dependencies:
// - flutter/material.dart
// - flutter/services.dart
// - permission_handler
// - services/cleaner_engine.dart
// - services/scan_item.dart
// - models/dashboard_state.dart
// - widgets/scan_result_card.dart
// - widgets/animated_button.dart
// - widgets/progress_ring.dart
// - utils/colors.dart
// - screens/settings_screen.dart
// ----------------------------------------------------------------------------
// Compatibility:
// - يحافظ على HomeScreen وstartAnalysis وperformCleaning.
// - يحافظ على المكونات والأدوات المستخدمة في التصميم الحالي.
// - يجب أن يتوافق ScanResultCard مع item وonChanged.
// - لم يُنفّذ بناء Flutter أو اختبار على جهاز فعلي.
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cleaner_app/services/cleaner_engine.dart';
import 'package:flutter_cleaner_app/services/scan_item.dart';
import 'package:flutter_cleaner_app/models/dashboard_state.dart';
import 'package:flutter_cleaner_app/widgets/scan_result_card.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/progress_ring.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // محرك الفحص والحذف الفعلي.
  final CleanerEngine _engine = CleanerEngine();

  // مفتاح القائمة الجانبية.
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  // الحالة الموحدة المستخدمة في عناصر الواجهة.
  DashboardState state = const DashboardState();

  // نتائج الفحص الحالية، بما فيها اختيارات المستخدم.
  // يجب أن تكون هذه القائمة قابلة للتعديل لأن نتائج المحرك غير قابلة للتعديل.
  List<ScanItem> scanItems = <ScanItem>[];

  // سجل رسائل الفحص والتنظيف.
  final List<Map<String, String>> logs = <Map<String, String>>[];

  // هل اكتمل فحص حالي؟
  bool _hasScanned = false;

  // هل توجد عملية حذف جارية؟
  bool _isCleaning = false;

  // يمنع تشغيل عمليتين في الوقت نفسه.
  bool _isStartingScan = false;

  // معلومات آخر عملية تنظيف.
  int _lastDeletedFiles = 0;
  int _lastSelectedBytes = 0;
  bool _hasCleanupResult = false;
  String _lastCleanupMessage = 'لم تبدأ عملية التنظيف بعد';

  // فهرس شريط التنقل السفلي.
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    state = state.copyWith(
      currentTask: 'جاهز للفحص',
      progress: 0.0,
    );
  }

  // ---------------------------------------------------------------------------
  // الصلاحيات
  // ---------------------------------------------------------------------------

  /// طلب صلاحية الوصول إلى الملفات المشتركة على Android.
  Future<bool> _requestStorageAccess() async {
    try {
      if (!Platform.isAndroid) {
        return false;
      }

      final PermissionStatus currentStatus =
          await Permission.manageExternalStorage.status;

      if (currentStatus.isGranted) {
        return true;
      }

      final PermissionStatus requestedStatus =
          await Permission.manageExternalStorage.request();

      return requestedStatus.isGranted;
    } on PlatformException catch (error, stackTrace) {
      debugPrint('Storage permission error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } catch (error, stackTrace) {
      debugPrint('Unexpected storage permission error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  void _showPermissionMessage() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'يلزم منح صلاحية الوصول إلى الملفات المشتركة لإجراء الفحص.',
        ),
        backgroundColor: const Color(0xFF202942),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'الإعدادات',
          textColor: const Color(0xFF00F2FE),
          onPressed: () {
            openAppSettings();
          },
        ),
      ),
    );
  }

  void _showLargestFiles() {
    final files = _engine.largestAccessibleFiles;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('أكبر الملفات التي أمكن قراءتها',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('قائمة للعرض فقط. لا يتم حذف الصور أو الفيديوهات من هذه الشاشة.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                Expanded(
                  child: files.isEmpty
                    ? const Center(child: Text('أعد الفحص أولًا لعرض الملفات.', style: TextStyle(color: Colors.white70)))
                    : ListView.separated(
                        itemCount: files.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                        itemBuilder: (_, index) {
                          final entry = files[index];
                          final segments = entry.key.split('/');
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF00F2FE)),
                            title: Text(segments.isEmpty ? entry.key : segments.last,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(entry.key,
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Text(formatBytes(entry.value),
                              style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11)),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// يعرض الملفات التي اكتشفها المحرك فعلًا ضمن الفئة المختارة.
  Future<void> _showCategoryDetails(ScanItem item) async {
    final List<File> files = _engine.filesForCategory(item.id);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${files.length} ملف مكتشف • ${item.readableSize} إجمالي الحجم المرصود',
                    style: const TextStyle(color: Color(0xFF00F2FE), fontSize: 13)),
                  const SizedBox(height: 8),
                  const Text('راجع الاسم والمسار قبل اختيار الفئة للتنظيف. عرض الملفات لا يعني أنها حُذفت.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: files.isEmpty
                      ? const Center(child: Text('لا توجد تفاصيل ملفات متاحة لهذه الفئة.', style: TextStyle(color: Colors.white70)))
                      : ListView.separated(
                          itemCount: files.length,
                          separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                          itemBuilder: (_, index) {
                            final file = files[index];
                            return FutureBuilder<int>(
                              future: file.length(),
                              builder: (context, snapshot) {
                                final size = snapshot.hasError ? 'غير متاح' : snapshot.hasData ? formatBytes(snapshot.data!) : 'جارٍ حساب الحجم...';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF00F2FE)),
                                  title: Text(file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(file.path, style: const TextStyle(color: Colors.white60, fontSize: 10),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                  trailing: Text(size, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                );
                              },
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // بدء الفحص
  // ---------------------------------------------------------------------------

  Future<void> startAnalysis() async {
    if (_isStartingScan || state.scanning || _isCleaning) {
      return;
    }

    setState(() {
      _isStartingScan = true;
      state = state.copyWith(
        currentTask: 'التحقق من صلاحيات التخزين...',
      );
    });

    final bool hasPermission = await _requestStorageAccess();

    if (!mounted) return;

    if (!hasPermission) {
      setState(() {
        _isStartingScan = false;
        state = state.copyWith(
          scanning: false,
          analysisFinished: false,
          currentTask: 'صلاحية التخزين غير متاحة',
          progress: 0.0,
        );
      });

      _showPermissionMessage();
      return;
    }

    setState(() {
      _isStartingScan = false;
      _hasScanned = false;
      scanItems = <ScanItem>[];
      logs.clear();

      state = state.copyWith(
        scanning: true,
        analysisFinished: false,
        progress: 0.0,
        currentTask: 'بدء فحص الملفات...',
        totalFiles: 0,
        totalBytes: 0,
      );
    });

    _addLog('بدأ فحص الملفات المشتركة');

    try {
      final List<ScanItem> results = await _engine.scan(
        onStatus: (String message) {
          if (!mounted) return;

          _addLog(message);

          setState(() {
            state = state.copyWith(
              currentTask: message,
            );
          });
        },
        onProgress: (double progress) {
          if (!mounted) return;

          final double safeProgress =
              progress.clamp(0.0, 1.0).toDouble();

          setState(() {
            state = state.copyWith(
              progress: safeProgress,
            );
          });
        },
      );

      if (!mounted) return;

      // إصلاح مهم:
      // قد يعيد CleanerEngine قائمة غير قابلة للتعديل.
      // ننسخ النتائج حتى يمكن تحديث selected عند ضغط المستخدم.
      final List<ScanItem> mutableResults =
          List<ScanItem>.from(results);

      final int totalFiles = mutableResults.fold<int>(
        0,
        (sum, item) => sum + item.files,
      );

      final int totalBytes = mutableResults.fold<int>(
        0,
        (sum, item) => sum + item.bytes,
      );

      setState(() {
        scanItems = mutableResults;
        _hasScanned = true;

        state = state.copyWith(
          scanning: false,
          analysisFinished: true,
          progress: 1.0,
          currentTask: 'اكتمل فحص الملفات',
          totalFiles: totalFiles,
          totalBytes: totalBytes,
        );
      });

      _addLog('اكتمل الفحص: $totalFiles ملف مرشح');

      if (mutableResults.isEmpty || totalFiles == 0) {
        _showMessage(
          'لم يعثر الفحص على ملفات مرشحة وفق قواعد المحرك الحالية.',
        );
      } else {
        _showMessage(
          'اكتمل الفحص. راجع الملفات المرشحة قبل حذف أي منها.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Scan error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _hasScanned = false;
        scanItems = <ScanItem>[];

        state = state.copyWith(
          scanning: false,
          analysisFinished: false,
          progress: 0.0,
          currentTask: 'تعذر إكمال الفحص',
        );
      });

      _addLog('حدث خطأ أثناء الفحص');
      _showMessage(
        'تعذر إكمال الفحص. تحقق من الصلاحيات ثم أعد المحاولة.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // تنظيف الملفات المحددة
  // ---------------------------------------------------------------------------

  Future<void> performCleaning() async {
    if (state.scanning || _isStartingScan || _isCleaning) {
      return;
    }

    if (!_hasScanned || !state.analysisFinished) {
      _showMessage('ابدأ فحص الملفات أولًا.');
      return;
    }

    final List<ScanItem> selectedItems = scanItems
        .where(
          (item) => item.selected && item.safeToDelete,
        )
        .toList();

    if (selectedItems.isEmpty) {
      _showMessage(
        'حدد عنصرًا واحدًا على الأقل من العناصر القابلة للمعالجة.',
      );
      return;
    }

    final int selectedBytes = selectedItems.fold<int>(
      0,
      (total, item) => total + item.bytes,
    );

    final int selectedFileCount = selectedItems.fold<int>(
      0,
      (sum, item) => sum + item.files,
    );

    final bool? shouldClean = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1326),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFFD700),
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تأكيد حذف الملفات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'سيحاول التطبيق حذف الملفات الموجودة ضمن العناصر التي اخترتها.\n\n'
            'عدد الملفات المرصودة: $selectedFileCount\n'
            'الحجم التقديري: ${formatBytes(selectedBytes)}\n\n'
            'قد يتعذر حذف بعض الملفات. لا تتابع إذا لم تكن متأكدًا من العناصر المحددة.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'متابعة الحذف',
                style: TextStyle(
                  color: Color(0xFF00F2FE),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldClean != true || !mounted) {
      return;
    }

    setState(() {
      _isCleaning = true;
      _lastSelectedBytes = selectedBytes;
      _lastDeletedFiles = 0;
      _hasCleanupResult = false;
      _lastCleanupMessage = 'بدأت محاولة حذف الملفات المحددة';

      logs.clear();

      state = state.copyWith(
        scanning: false,
        analysisFinished: false,
        progress: 0.05,
        currentTask: 'جارٍ حذف الملفات المحددة...',
      );
    });

    _addLog('بدأت عملية حذف الملفات المحددة');

    int deletedCount = 0;
    bool operationFailed = false;

    try {
      deletedCount = await _engine.clean(
        selected: selectedItems,
        onStatus: (String message) {
          if (!mounted) return;

          _addLog(message);

          setState(() {
            _lastCleanupMessage = message;

            state = state.copyWith(
              currentTask: message,
            );
          });
        },
      );
    } catch (error, stackTrace) {
      operationFailed = true;

      debugPrint('Cleaning error: $error');
      debugPrintStack(stackTrace: stackTrace);

      _addLog('حدث خطأ أثناء عملية الحذف');
    }

    if (!mounted) return;

    setState(() {
      _isCleaning = false;
      _hasScanned = false;
      scanItems = <ScanItem>[];

      _lastDeletedFiles = deletedCount;
      _hasCleanupResult = true;

      if (operationFailed) {
        _lastCleanupMessage =
            'انتهت العملية مع خطأ. راجع السجل قبل إعادة المحاولة.';
      } else if (deletedCount > 0) {
        _lastCleanupMessage =
            'أفاد المحرك بحذف $deletedCount ملف. الحجم المحرر غير مؤكد.';
      } else {
        _lastCleanupMessage =
            'لم يؤكد المحرك حذف أي ملفات.';
      }

      state = state.copyWith(
        scanning: false,
        analysisFinished: false,
        progress: 1.0,
        currentTask: operationFailed
            ? 'انتهت العملية مع خطأ'
            : deletedCount > 0
                ? 'اكتملت محاولة حذف الملفات'
                : 'لم يتم حذف ملفات',
        totalFiles: 0,
        totalBytes: 0,
      );
    });

    _addLog(_lastCleanupMessage);

    if (operationFailed) {
      _showMessage('حدث خطأ أثناء التنظيف. راجع سجل العملية.');
    } else if (deletedCount > 0) {
      _showMessage(
        'أفاد المحرك بحذف $deletedCount ملف. '
        'يمكنك إعادة الفحص للتحقق مما تبقى.',
      );
    } else {
      _showMessage(
        'لم يتم تأكيد حذف أي ملفات. '
        'قد تكون الملفات غير متاحة أو تعذر حذفها.',
      );
    }

    // لا نعيد الفحص تلقائيًا.
    // يبدأ المستخدم فحصًا جديدًا عندما يرغب في ذلك.
  }

  // ---------------------------------------------------------------------------
  // أدوات مساعدة
  // ---------------------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF202942),
      ),
    );
  }

  String formatBytes(int bytes) {
    if (bytes < 0) return 'غير معروف';
    if (bytes < 1024) return '$bytes B';

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// إضافة رسالة إلى السجل مع تحديد حجمه حتى لا يتضخم بلا حدود.
  void _addLog(String message) {
    final DateTime now = DateTime.now();

    final String timeString =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    logs.insert(0, <String, String>{
      'time': timeString,
      'message': message.startsWith('[AI]') ? message : '[AI] $message',
    });

    if (logs.length > 100) {
      logs.removeRange(100, logs.length);
    }
  }

  // ---------------------------------------------------------------------------
  // نافذة الاشتراك
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // بناء الواجهة
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool showLastCleanup =
        !_hasScanned &&
        !_isCleaning &&
        !state.scanning &&
        _hasCleanupResult;

    final int displayedFiles = _hasScanned
        ? state.totalFiles
        : showLastCleanup
            ? _lastDeletedFiles
            : 0;

    final int displayedBytes = _hasScanned
        ? state.totalBytes
        : showLastCleanup
            ? _lastSelectedBytes
            : 0;

    final String filesLabel = _hasScanned
        ? 'Candidates'
        : showLastCleanup
            ? 'Files Deleted'
            : 'Candidates';

    final String bytesLabel = _hasScanned
        ? 'Candidate Size'
        : showLastCleanup
            ? 'Selected Size'
            : 'Candidate Size';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: const Color(0xFF090D1A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF0E1326),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'AI OPTIMIZER PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Local File Cleanup • v1.0.0',
                    style: TextStyle(
                      color: Color(0xFF00F2FE),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.white70),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                'About Engine',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);

                showAboutDialog(
                  context: context,
                  applicationName: 'AI Optimizer',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© AI Cleaner',
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        centerTitle: true,
        title: const Text(
          'AI OPTIMIZER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 5),
              ProgressRing(
                progress: state.progress,
                title: state.currentTask,
                subtitle: _isCleaning
                    ? 'حذف الملفات المحددة...'
                    : state.scanning
                        ? 'جارٍ فحص الملفات...'
                        : _hasScanned
                            ? 'راجع العناصر قبل الحذف'
                            : 'جاهز لبدء الفحص',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDynamicHealthCard(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDynamicStatusCard(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      '$displayedFiles',
                      filesLabel,
                      const Color(0xFF00F2FE),
                    ),
                    Container(
                      width: 1,
                      height: 22,
                      color: Colors.white10,
                    ),
                    _buildStatColumn(
                      formatBytes(displayedBytes),
                      bytesLabel,
                      const Color(0xFFE040FB),
                    ),
                    Container(
                      width: 1,
                      height: 22,
                      color: Colors.white10,
                    ),
                    _buildStatColumn(
                      state.scanning
                          ? '${(state.progress * 100).round()}%'
                          : _isCleaning
                              ? '...'
                              : _hasScanned
                                  ? 'Ready'
                                  : showLastCleanup
                                      ? 'Done'
                                      : '--',
                      'Operation',
                      const Color(0xFF00E676),
                    ),
                  ],
                ),
              ),
              if (_hasScanned) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STORAGE INVENTORY • ACCESSIBLE FILES',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildStatColumn('${_engine.imageFiles}', 'Photos • ${formatBytes(_engine.imageBytes)}', const Color(0xFF64B5F6))),
                          Expanded(child: _buildStatColumn('${_engine.videoFiles}', 'Videos • ${formatBytes(_engine.videoBytes)}', const Color(0xFFFFB74D))),
                          Expanded(child: _buildStatColumn('${_engine.otherFiles}', 'Other files • ${formatBytes(_engine.otherBytes)}', Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Inventory is limited to files Android allowed the app to read; it is not the phone’s complete storage meter.',
                        style: TextStyle(color: Colors.white60, fontSize: 10, height: 1.35),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _showLargestFiles,
                          icon: const Icon(Icons.storage_rounded, size: 16),
                          label: const Text('View largest files'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF00F2FE)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _isCleaning
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00F2FE),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              state.currentTask,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : scanItems.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Detected Items',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'راجع العناصر وحدد ما تريد حذفه. '
                                'لا تحدد ملفًا لا تعرف وظيفته.',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: scanItems.length,
                                  itemBuilder: (context, index) {
                                    return ScanResultCard(
                                      item: scanItems[index],
                                      onDetails: () => _showCategoryDetails(scanItems[index]),
                                      onChanged: (value) {
                                        setState(() {
                                          scanItems[index] =
                                              scanItems[index].copyWith(
                                            selected: value ?? false,
                                          );
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : _buildLogsAndTools(),
              ),
              const SizedBox(height: 12),
              AnimatedButton(
                title: _isCleaning
                    ? 'DELETING SELECTED FILES...'
                    : state.scanning || _isStartingScan
                        ? 'SCANNING FILES...'
                        : state.analysisFinished
                            ? 'CLEAN SELECTED FILES'
                            : _hasScanned
                                ? 'SCAN COMPLETE'
                                : 'START FILE SCAN',
                icon: _isCleaning || state.scanning || _isStartingScan
                    ? Icons.hourglass_top_rounded
                    : state.analysisFinished
                        ? Icons.delete_outline_rounded
                        : _hasScanned
                            ? Icons.check_circle_outline_rounded
                            : Icons.radar_rounded,
                onPressed: _isStartingScan ||
                        state.scanning ||
                        _isCleaning
                    ? null
                    : state.analysisFinished
                        ? performCleaning
                        : startAnalysis,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF090D1A),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00F2FE),
        unselectedItemColor: Colors.white38,
        currentIndex: _currentIndex,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded, size: 20),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined, size: 20),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // بطاقة ملخص الفحص
  // ---------------------------------------------------------------------------

  Widget _buildDynamicHealthCard() {
    String mainText = '--';
    String description = 'Scan Required';
    Color textColor = Colors.white38;

    Gradient cardGradient = LinearGradient(
      colors: [
        Colors.white.withOpacity(0.04),
        Colors.white.withOpacity(0.02),
      ],
    );

    if (_isCleaning) {
      mainText = 'DELETE';
      description = 'Processing...';
      textColor = const Color(0xFF00F2FE);

      cardGradient = LinearGradient(
        colors: [
          const Color(0xFF00F2FE).withOpacity(0.15),
          Colors.blue.withOpacity(0.05),
        ],
      );
    } else if (state.scanning || _isStartingScan) {
      mainText = 'SCAN';
      description = 'Analyzing files...';
      textColor = const Color(0xFFFFD700);
    } else if (_hasScanned) {
      mainText = '${state.totalFiles}';
      description = 'Candidate files';
      textColor = const Color(0xFF00F2FE);

      cardGradient = LinearGradient(
        colors: [
          const Color(0xFF00F2FE).withOpacity(0.10),
          Colors.blue.withOpacity(0.03),
        ],
      );
    } else if (_hasCleanupResult) {
      mainText = '$_lastDeletedFiles';
      description = 'Files deleted';
      textColor = _lastDeletedFiles > 0
          ? const Color(0xFF00E676)
          : Colors.orangeAccent;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      height: 90,
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'FILES FOUND',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mainText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // بطاقة حالة العملية
  // ---------------------------------------------------------------------------

  Widget _buildDynamicStatusCard() {
    final String statusTitle = _isCleaning
        ? 'FILE CLEANUP'
        : 'SCAN STATUS';

    final String statusSubtitle = _isCleaning
        ? 'Deleting selected files'
        : state.scanning || _isStartingScan
            ? 'Scanning shared storage'
            : _hasScanned
                ? 'Review candidates'
                : _hasCleanupResult
                    ? 'Last cleanup finished'
                    : 'Waiting for scan';

    return Container(
      padding: const EdgeInsets.all(12),
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                _isCleaning
                    ? Icons.delete_outline_rounded
                    : Icons.radar_outlined,
                color: const Color(0xFF00F2FE),
                size: 14,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  statusTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            state.currentTask,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.progress.clamp(0.0, 1.0).toDouble(),
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF00F2FE),
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              statusSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // سجل العمليات والأدوات
  // ---------------------------------------------------------------------------

  void _showOperationLog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF10172A),
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.65,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سجل العملية الحالية',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('السجل مؤقت ويُمسح عند بدء عملية جديدة.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 12),
                Expanded(
                  child: logs.isEmpty
                    ? const Center(child: Text('لا توجد عمليات مسجلة.', style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (_, index) {
                          final entry = logs[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.info_outline, color: Color(0xFF00F2FE)),
                            title: Text(entry['message'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            subtitle: Text(entry['time'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogsAndTools() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Operation Logs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                _showOperationLog();
              },
              child: const Text(
                'View log',
                style: TextStyle(
                  color: Color(0xFF4FACFE),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        Container(
          height: 90,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.02),
            ),
          ),
          child: logs.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد عمليات مسجلة بعد.',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (_, index) {
                    final Map<String, String> log = logs[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: const Color(0xFF00F2FE)
                                .withOpacity(0.7),
                            size: 12,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              log['message'] ?? '',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            log['time'] ?? '',
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInteractiveTool(
              Icons.cleaning_services_outlined,
              'Deep Clean',
              performCleaning,
            ),
            _buildInteractiveTool(
              Icons.settings_outlined,
              'Settings',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_hasCleanupResult)
          Text(
            _lastCleanupMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.4,
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // عناصر الإحصاءات والأدوات
  // ---------------------------------------------------------------------------

  Widget _buildStatColumn(
    String value,
    String title,
    Color valueColor,
  ) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTool(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.04),
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
