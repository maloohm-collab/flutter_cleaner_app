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
import 'duplicate_files_screen.dart';

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
  int _lastDeletedBytes = 0;
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

  static const MethodChannel _appCacheChannel = MethodChannel('ai_optimizer/app_cache_review');

  Future<void> _showAppCacheReview() async {
    if (!Platform.isAndroid) { _showMessage('هذه الميزة متاحة على Android فقط.'); return; }
    try {
      final List<dynamic> apps = await _appCacheChannel.invokeMethod<List<dynamic>>('listApps') ?? [];
      if (!mounted) return;
      showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF25334D), builder: (sheetContext) => SafeArea(child: SizedBox(height: MediaQuery.of(sheetContext).size.height * 0.82, child: Column(children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('مراجعة ذاكرة التطبيقات', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('اختر تطبيقًا لفتح صفحة التخزين في إعدادات Android، ثم امسح ذاكرة التخزين المؤقت يدويًا. لا يمكن للتطبيق قراءة ذاكرة التطبيقات الخاصة أو حذفها مباشرة.', style: TextStyle(color: Color(0xFFE0E7F2), fontSize: 15, height: 1.5))),
        Expanded(child: ListView.builder(itemCount: apps.length, itemBuilder: (_, index) {
          final app = Map<String, dynamic>.from(apps[index] as Map);
          return ListTile(leading: const Icon(Icons.apps, color: Color(0xFF00F2FE)), title: Text(app['name'].toString(), style: const TextStyle(color: Colors.white)), subtitle: Text(app['packageName'].toString(), style: const TextStyle(color: Color(0xFFD4DEEF), fontSize: 12)), trailing: const Icon(Icons.open_in_new, color: Color(0xFFFFB74D)), onTap: () async { Navigator.pop(sheetContext); try { await _appCacheChannel.invokeMethod('openAppSettings', {'packageName': app['packageName']}); } on PlatformException { if (mounted) _showMessage('تعذر فتح إعدادات التطبيق.'); } });
        })),
        TextButton(onPressed: () async { try { await _appCacheChannel.invokeMethod('openStorageSettings'); } on PlatformException { if (mounted) _showMessage('تعذر فتح إعدادات التطبيقات.'); } }, child: const Text('فتح إعدادات جميع التطبيقات')),
      ]))));
    } on PlatformException { if (mounted) _showMessage('تعذر قراءة قائمة التطبيقات.'); }
  }

  void _showDuplicateFiles() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DuplicateFilesScreen()),
    );
  }

  void _showLargestFiles() {
    final files = _engine.largestAccessibleFiles;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LargestFilesScreen(
          files: files,
          formatBytes: formatBytes,
          onOpenFile: _showSingleFileDetails,
        ),
      ),
    );
  }

  /// يفتح شاشة كاملة لتفاصيل الملفات المكتشفة، بدل نافذة قصيرة قابلة للانقطاع.
  Future<void> _showCategoryDetails(ScanItem item) async {
    final List<File> files = _engine.filesForCategory(item.id);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CategoryDetailsScreen(
          title: item.title,
          files: files,
          formatBytes: formatBytes,
          canSelectForDeletion: item.safeToDelete,
          initialSelectedPaths: item.selectedPaths,
          onSelectFiles: (List<String> paths) {
            setState(() {
              final index = scanItems.indexWhere((candidate) => candidate.id == item.id);
              if (index >= 0) {
                scanItems[index] = scanItems[index].copyWith(
                  selected: paths.isNotEmpty,
                  selectedPaths: List<String>.unmodifiable(paths),
                );
              }
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showSingleFileDetails(String path, int bytes) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FilePathDetailsScreen(path: path, bytes: bytes, formatBytes: formatBytes),
      ),
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
          (item) =>
              item.selected &&
              item.safeToDelete &&
              item.selectedPaths.isNotEmpty,
        )
        .toList();

    if (selectedItems.isEmpty) {
      _showMessage(
        'حدد عنصرًا واحدًا على الأقل من العناصر القابلة للمعالجة.',
      );
      return;
    }

    int selectedBytes = 0;
    int selectedFileCount = 0;
    for (final ScanItem item in selectedItems) {
      final Set<String> paths = item.selectedPaths.toSet();
      for (final File file in _engine.filesForCategory(item.id)) {
        if (!paths.contains(file.path)) continue;
        try {
          if (await file.exists()) {
            selectedBytes += await file.length();
            selectedFileCount++;
          }
        } on FileSystemException {
          // قد يختفي الملف بين الفحص والمراجعة؛ لا نحتسبه كتقدير مؤكد.
        }
      }
    }

    if (selectedFileCount == 0) {
      _showMessage('الملفات المحددة لم تعد متاحة. أعد الفحص ثم حاول مجددًا.');
      return;
    }

    final bool? shouldClean = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.border),
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
                    color: AppColors.textPrimary,
                    fontSize: 19,
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
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.55,
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
                  color: Color(0xFF087F9B),
                  fontSize: 16,
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
      _lastDeletedBytes = _engine.lastDeletedBytes;
      _hasCleanupResult = true;

      if (operationFailed) {
        _lastCleanupMessage =
            'انتهت العملية مع خطأ. راجع السجل قبل إعادة المحاولة.';
      } else if (deletedCount > 0) {
        _lastCleanupMessage =
            'أفاد المحرك بحذف $deletedCount ملف. الحجم المحسوب للملفات المحذوفة: ${formatBytes(_lastDeletedBytes)}.';
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
        ? 'ملفات مرشحة'
        : showLastCleanup
            ? 'ملفات حُذفت'
            : 'ملفات مرشحة';

    final String bytesLabel = _hasScanned
        ? 'الحجم المرصود'
        : showLastCleanup
            ? 'الحجم المحدد'
            : 'الحجم المحدد';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.background,
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
                    'تنظيف الملفات محليًا • الإصدار 1.0.0',
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
              title: const Text('الإعدادات', style: TextStyle(color: Colors.white)),
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
                'حول محرك الفحص',
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
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        centerTitle: true,
        title: const Text(
          'AI OPTIMIZER',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
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
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      '$displayedFiles',
                      filesLabel,
                      AppColors.primary,
                    ),
                    Container(
                      width: 1,
                      height: 22,
                      color: AppColors.border,
                    ),
                    _buildStatColumn(
                      formatBytes(displayedBytes),
                      bytesLabel,
                      const Color(0xFF9A8CFF),
                    ),
                    Container(
                      width: 1,
                      height: 22,
                      color: AppColors.border,
                    ),
                    _buildStatColumn(
                      state.scanning
                          ? '${(state.progress * 100).round()}%'
                          : _isCleaning
                              ? '...'
                              : _hasScanned
                                  ? 'جاهز'
                                  : showLastCleanup
                                      ? 'تم'
                                      : '—',
                      'الحالة',
                      AppColors.success,
                    ),
                  ],
                ),
              ),
              if (_hasScanned && scanItems.isEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'جرد الملفات المتاحة',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatColumn('${_engine.imageFiles}', 'صور • ${formatBytes(_engine.imageBytes)}', const Color(0xFF64B5F6)),
                          _buildStatColumn('${_engine.videoFiles}', 'فيديو • ${formatBytes(_engine.videoBytes)}', const Color(0xFFFFB74D)),
                          _buildStatColumn('${_engine.otherFiles}', 'ملفات أخرى • ${formatBytes(_engine.otherBytes)}', AppColors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'يعرض هذا الجرد الملفات التي سمح Android للتطبيق بقراءتها، ولا يمثل كامل مساحة الهاتف.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _showLargestFiles,
                          icon: const Icon(Icons.storage_rounded, size: 16),
                          label: const Text('عرض أكبر الملفات'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : scanItems.isNotEmpty
                        ? ListView(
                            padding: const EdgeInsets.only(bottom: 12),
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border, width: 1.3),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'العناصر المكتشفة',
                                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'تم العثور على ${scanItems.length} فئات مرشحة. افتح زر التفاصيل في كل بطاقة لمشاهدة أسماء الملفات ومساراتها وأحجامها قبل اختيار الحذف.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 17, height: 1.5, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              for (int index = 0; index < scanItems.length; index++)
                                ScanResultCard(
                                  item: scanItems[index],
                                  onDetails: () => _showCategoryDetails(scanItems[index]),
                                ),
                            ],
                          )
                        : _buildLogsAndTools(),
              ),
              const SizedBox(height: 12),
              AnimatedButton(
                title: _isCleaning
                    ? 'جارٍ تنظيف الملفات...'
                    : state.scanning || _isStartingScan
                        ? 'جارٍ فحص الملفات...'
                        : state.analysisFinished
                            ? 'تنظيف الملفات المحددة'
                            : _hasScanned
                                ? 'اكتمل الفحص'
                                : 'ابدأ فحص الملفات',
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
        backgroundColor: AppColors.card,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.white70,
        currentIndex: _currentIndex,
        selectedFontSize: 12,
        unselectedFontSize: 12,
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
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined, size: 20),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // بطاقة ملخص الفحص
  // ---------------------------------------------------------------------------

  Widget _buildDynamicHealthCard() {
    final bool busy = _isCleaning || state.scanning || _isStartingScan;
    final String value = _isCleaning
        ? '...'
        : state.scanning || _isStartingScan
            ? '${(state.progress * 100).round()}%'
            : _hasScanned
                ? '${state.totalFiles}'
                : _hasCleanupResult
                    ? '$_lastDeletedFiles'
                    : '—';
    final String caption = _isCleaning
        ? 'جارٍ التنظيف'
        : state.scanning || _isStartingScan
            ? 'تقدم الفحص'
            : _hasScanned
                ? 'ملف مرشح'
                : _hasCleanupResult
                    ? 'ملف/ملفات حُذفت وفق نتيجة المحرك'
                    : 'ابدأ الفحص لعرض النتائج';

    return Container(
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(minHeight: 104),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172C45), Color(0xFF122033)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            const Icon(Icons.folder_copy_outlined, color: AppColors.primary, size: 18),
            const SizedBox(width: 7),
            Expanded(child: Text(
              _hasCleanupResult && !_hasScanned ? 'نتيجة آخر تنظيف' : 'نتائج الفحص',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
            )),
          ]),
          const SizedBox(height: 8),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: busy ? AppColors.warning : AppColors.textPrimary, fontSize: 26, height: 1, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // بطاقة حالة العملية
  // ---------------------------------------------------------------------------

  Widget _buildDynamicStatusCard() {
    final bool busy = _isCleaning || state.scanning || _isStartingScan;
    final String statusTitle = _isCleaning
        ? 'حالة التنظيف'
        : state.scanning || _isStartingScan
            ? 'الفحص جارٍ'
            : _hasScanned
                ? 'الفحص مكتمل'
                : _hasCleanupResult
                    ? 'آخر عملية'
                    : 'جاهز للعمل';
    final String statusSubtitle = _isCleaning
        ? 'حذف العناصر التي اخترتها'
        : state.scanning || _isStartingScan
            ? 'فحص الملفات المتاحة'
            : _hasScanned
                ? 'راجع النتائج قبل الحذف'
                : _hasCleanupResult
                    ? 'يمكنك إعادة الفحص للتحقق'
                    : 'ابدأ بفحص الملفات';

    return Container(
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(minHeight: 104),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(
              _isCleaning ? Icons.cleaning_services_rounded : Icons.radar_rounded,
              color: busy ? AppColors.warning : AppColors.success,
              size: 18,
            ),
            const SizedBox(width: 7),
            Expanded(child: Text(statusTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 9),
          Text(state.currentTask, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: busy ? state.progress.clamp(0.0, 1.0).toDouble() : (_hasScanned ? 1 : 0),
              backgroundColor: const Color(0xFF2A3A52),
              valueColor: AlwaysStoppedAnimation<Color>(busy ? AppColors.warning : AppColors.primary),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 5),
          Text(statusSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.timeline_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('سجل العمليات', style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800,
                ))),
                TextButton(
                  onPressed: _showOperationLog,
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  child: const Text('عرض السجل'),
                ),
              ]),
              const SizedBox(height: 4),
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('ستظهر هنا آخر رسائل الفحص والتنظيف بعد بدء عملية.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4))),
                  ]),
                )
              else
                ...logs.take(2).map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    const Icon(Icons.circle, color: AppColors.primary, size: 7),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35))),
                    const SizedBox(width: 8),
                    Text(entry['time'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  ]),
                )),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('أدوات سريعة', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800,
          )),
        ),
        _buildWideTool(
          Icons.copy_all_rounded,
          'اكتشاف الملفات المكررة',
          'فحص قراءة فقط مع مقارنة المحتوى وعرض المسارات دون حذف تلقائي.',
          _showDuplicateFiles,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildInteractiveTool(
              Icons.cleaning_services_rounded, 'تنظيف المحدد', performCleaning,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildInteractiveTool(
              Icons.apps_rounded, 'ذاكرة التطبيقات', _showAppCacheReview,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildInteractiveTool(
              Icons.settings_rounded, 'الإعدادات', () {
                Navigator.push(context, MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ));
              },
            )),
          ],
        ),
        if (_hasCleanupResult) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(_lastCleanupMessage, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
          ),
        ],
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
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideTool(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ]),
        ),
      ),
    );
  }

  Widget _buildInteractiveTool(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}


/// شاشة مستقلة وواضحة لمراجعة كل ملف ومساره قبل اختيار التنظيف.
class CategoryDetailsScreen extends StatefulWidget {
  final String title;
  final List<File> files;
  final String Function(int) formatBytes;
  final bool canSelectForDeletion;
  final List<String> initialSelectedPaths;
  final ValueChanged<List<String>> onSelectFiles;

  const CategoryDetailsScreen({
    super.key,
    required this.title,
    required this.files,
    required this.formatBytes,
    required this.canSelectForDeletion,
    this.initialSelectedPaths = const <String>[],
    required this.onSelectFiles,
  });

  @override
  State<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends State<CategoryDetailsScreen> {
  final Set<String> _selectedPaths = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedPaths.addAll(widget.initialSelectedPaths);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'مراجعة الملفات',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.files.length} ملف مكتشف • ${_selectedPaths.length} محدد',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'راجع اسم كل ملف ومساره وحجمه، وحدد الملفات التي تريد حذفها فقط. لن يُحذف شيء قبل تأكيد العملية في الشاشة التالية.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.files.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد ملفات متاحة للعرض.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 17),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: widget.files.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final File file = widget.files[index];
                        final bool selected = _selectedPaths.contains(file.path);
                        return FutureBuilder<int>(
                          future: file.length(),
                          builder: (context, snapshot) {
                            final String size = snapshot.hasError
                                ? 'الحجم غير متاح'
                                : snapshot.hasData
                                    ? widget.formatBytes(snapshot.data!)
                                    : 'جارٍ حساب الحجم…';
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected ? AppColors.primary : AppColors.border,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: selected,
                                    activeColor: AppColors.primary,
                                    onChanged: widget.canSelectForDeletion
                                        ? (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedPaths.add(file.path);
                                              } else {
                                                _selectedPaths.remove(file.path);
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          file.uri.pathSegments.isEmpty
                                              ? file.path
                                              : file.uri.pathSegments.last,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'الحجم: $size',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        SelectableText(
                                          file.path,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                            height: 1.45,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () => Clipboard.setData(
                                              ClipboardData(text: file.path),
                                            ),
                                            icon: const Icon(Icons.copy_rounded, size: 18),
                                            label: const Text('نسخ المسار'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            if (widget.canSelectForDeletion)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedPaths.isEmpty
                        ? null
                        : () => widget.onSelectFiles(_selectedPaths.toList()),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      'اعتماد ${_selectedPaths.length} ملف محدد',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      disabledBackgroundColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// صفحة تفاصيل الملف الكبير؛ تعرض المسار ولا تفتح الملف نفسه.
class FilePathDetailsScreen extends StatelessWidget {
  final String path;
  final int bytes;
  final String Function(int) formatBytes;

  const FilePathDetailsScreen({super.key, required this.path, required this.bytes, required this.formatBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: const Color(0xFF172A45), title: const Text('تفاصيل الملف', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD8E2EE))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF147D92), size: 42),
          const SizedBox(height: 14),
          Text(path.split('/').isEmpty ? path : path.split('/').last, style: const TextStyle(color: Color(0xFF172A45), fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          const Text('الحجم المرصود', style: TextStyle(color: Color(0xFF52647A), fontSize: 15)),
          Text(formatBytes(bytes), style: const TextStyle(color: Color(0xFF147D92), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          const Text('المسار الكامل', style: TextStyle(color: Color(0xFF52647A), fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          SelectableText(path, style: const TextStyle(color: Color(0xFF26384F), fontSize: 15, height: 1.5)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: path)), icon: const Icon(Icons.copy_rounded), label: const Text('نسخ مسار الملف', style: TextStyle(fontSize: 16)))),
          const SizedBox(height: 8),
          const Text('لم يتم فتح الملف أو حذفه. هذه صفحة معلومات لمساعدتك على الوصول إليه يدويًا عبر مدير الملفات.', style: TextStyle(color: Color(0xFF43536A), fontSize: 15, height: 1.5)),
        ])),
      ]),
    );
  }
}


/// شاشة كاملة لعرض الملفات الأكبر حجمًا مع اسم الملف ومساره وحجمه.
class LargestFilesScreen extends StatelessWidget {
  final List<MapEntry<String, int>> files;
  final String Function(int) formatBytes;
  final void Function(String, int) onOpenFile;

  const LargestFilesScreen({
    super.key,
    required this.files,
    required this.formatBytes,
    required this.onOpenFile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172A45),
        title: const Text('أكبر الملفات المكتشفة',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD7E5)),
            ),
            child: const Text(
              'هذه الملفات مرتبة حسب الحجم. اضغط على أي ملف لعرض اسمه الكامل ومساره وحجمه. هذه الشاشة لا تحذف الملفات.',
              style: TextStyle(color: Color(0xFF243B56), fontSize: 16,
                  height: 1.5, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: files.isEmpty
                ? const Center(child: Text('لا توجد ملفات لعرضها. أعد الفحص أولًا.',
                    style: TextStyle(color: Color(0xFF34465D), fontSize: 17)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = files[index];
                      final parts = entry.key.split('/');
                      final name = parts.isEmpty ? entry.key : parts.last;
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onOpenFile(entry.key, entry.value),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD7E5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.insert_drive_file_outlined,
                                    color: Color(0xFF075E75), size: 30),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(
                                        color: Color(0xFF172A45), fontSize: 17,
                                        fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 6),
                                      Text(entry.key, style: const TextStyle(
                                        color: Color(0xFF34465D), fontSize: 14,
                                        height: 1.4)),
                                      const SizedBox(height: 7),
                                      Text('الحجم: ${formatBytes(entry.value)}',
                                        style: const TextStyle(
                                          color: Color(0xFF075E75), fontSize: 15,
                                          fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 8),
                                      const Text('اضغط لعرض تفاصيل الملف',
                                        style: TextStyle(
                                          color: Color(0xFF52647A), fontSize: 14)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: Color(0xFF075E75), size: 28),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
