 // Path: lib/screens/home_screen.dart
 //
 // Project: AI Cleaner / AI Optimizer
 // Purpose: الواجهة الرئيسية للفحص والتنظيف الفعلي للملفات المرشحة.
 //
 // ملاحظات مهمة:
 // 1. هذا الملف مسؤول عن الواجهة والصلاحيات وتنسيق عملية التنظيف.
 // 2. CleanerEngine هو المسؤول عن اكتشاف الملفات وحذف الملفات التي اختارها المستخدم.
 // 3. لا نعتبر كل ملف مؤقت ملفًا غير مهم؛ لذلك يجب مراجعة العناصر قبل حذفها.
 // 4. لا ندّعي تنظيف ذاكرة التطبيقات الأخرى الخاصة، لأن Android لا يسمح بذلك
 //    للتطبيقات العادية دون صلاحيات نظام خاصة.
 // 5. لا نعرض مساحة محددة على أنها مساحة محررة فعلًا؛ الحجم المعروض تقديري.
 // 6. لا توجد خطوات تنظيف وهمية أو إعادة فحص تلقائية بعد انتهاء الحذف.

import 'dart:io';

import 'package:flutter/material.dart';
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

  // نتائج الفحص الحالية، بما فيها اختيار المستخدم.
  List<ScanItem> scanItems = [];

  // سجل رسائل الفحص والتنظيف.
  final List<Map<String, String>> logs = [];

  // هل اكتمل فحص حالي؟
  bool _hasScanned = false;

  // هل توجد عملية حذف جارية؟
  bool _isCleaning = false;

  // يمنع تشغيل عمليتين في الوقت نفسه.
  bool _isStartingScan = false;

  // معلومات آخر عملية تنظيف.
  // هذه القيم لا تعني أن الحجم المحدد قد تحرر بالكامل من الجهاز.
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

  /// يطلب صلاحية الوصول إلى الملفات المشتركة على Android.
  ///
  /// ملاحظة:
  /// - صلاحية التخزين التقليدية لا تكفي للوصول إلى جميع المجلدات على Android
  ///   الحديث.
  /// - صلاحية الوصول إلى جميع الملفات تخضع لسياسات Google Play ومتطلبات Android.
  /// - حتى بعد منحها، لا يستطيع التطبيق العادي الدخول إلى البيانات الخاصة
  ///   للتطبيقات الأخرى أو حذفها.
  Future<bool> _requestStorageAccess() async {
    try {
      // محرك الفحص الحالي يعتمد على مسار تخزين Android.
      if (!Platform.isAndroid) {
        return false;
      }

      // إذا كانت الصلاحية ممنوحة مسبقًا فلا حاجة إلى طلبها مجددًا.
      final currentStatus =
          await Permission.manageExternalStorage.status;

      if (currentStatus.isGranted) {
        return true;
      }

      // في إصدارات Android الحديثة قد ينقل الطلب المستخدم إلى إعدادات النظام.
      final requestedStatus =
          await Permission.manageExternalStorage.request();

      if (requestedStatus.isGranted) {
        return true;
      }

      return false;
    } catch (error, stackTrace) {
      debugPrint('Storage permission error: $error');
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

  // ---------------------------------------------------------------------------
  // بدء الفحص
  // ---------------------------------------------------------------------------

  Future<void> startAnalysis() async {
    // منع بدء فحص جديد أثناء الفحص أو الحذف.
    if (_isStartingScan || state.scanning || _isCleaning) {
      return;
    }

    setState(() {
      _isStartingScan = true;
      state = state.copyWith(
        currentTask: 'التحقق من صلاحيات التخزين...',
      );
    });

    final hasPermission = await _requestStorageAccess();

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

    // نبدأ الفحص من حالة نظيفة.
    setState(() {
      _isStartingScan = false;
      _hasScanned = false;
      scanItems = [];
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
      // استدعاء المحرك مباشرة بدل مراحل المحاكاة السابقة.
      //
      // onStatus: يعرض رسالة الحالة التي يرسلها المحرك.
      // onProgress: يحدّث مؤشر التقدم حسب قيمة المحرك.
      final results = await _engine.scan(
        onStatus: (message) {
          if (!mounted) return;

          _addLog(message);

          setState(() {
            state = state.copyWith(
              currentTask: message,
            );
          });
        },
        onProgress: (progress) {
          if (!mounted) return;

          final safeProgress =
              progress.clamp(0.0, 1.0).toDouble();

          setState(() {
            state = state.copyWith(
              progress: safeProgress,
            );
          });
        },
      );

      if (!mounted) return;

      final totalFiles = _engine.totalFiles;
      final totalBytes = _engine.totalBytes;

      setState(() {
        scanItems = results;
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

      if (results.isEmpty || totalFiles == 0) {
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

        state = state.copyWith(
          scanning: false,
          analysisFinished: false,
          progress: 0.0,
          currentTask: 'تعذر إكمال الفحص',
        );
      });

      _addLog('حدث خطأ أثناء الفحص');
      _showMessage('تعذر إكمال الفحص. تحقق من الصلاحيات ثم أعد المحاولة.');
    }
  }

  // ---------------------------------------------------------------------------
  // تنظيف الملفات المحددة
  // ---------------------------------------------------------------------------

  Future<void> performCleaning() async {
    // لا يسمح بالحذف إذا كانت هناك عملية أخرى جارية.
    if (state.scanning || _isStartingScan || _isCleaning) {
      return;
    }

    // يجب وجود فحص مكتمل قبل السماح بالحذف.
    if (!_hasScanned || !state.analysisFinished) {
      _showMessage('ابدأ فحص الملفات أولًا.');
      return;
    }

    // لا نرسل إلى المحرك إلا العناصر التي حددها المستخدم والتي يسمح المحرك
    // بمعالجتها. اختيار المستخدم وحده لا يلغي التحقق الداخلي في المحرك.
    final selectedItems = scanItems
        .where(
          (item) => item.selected && item.safeToDelete,
        )
        .toList();

    if (selectedItems.isEmpty) {
      _showMessage('حدد عنصرًا واحدًا على الأقل من العناصر القابلة للمعالجة.');
      return;
    }

    // هذا مجموع الأحجام المسجلة للعناصر المحددة، وليس ضمانًا للمساحة
    // التي ستتحرر فعلًا؛ فقد يتعذر حذف بعض الملفات أو تكون قد اختفت بالفعل.
    final selectedBytes = selectedItems.fold<int>(
      0,
      (total, item) => total + item.bytes,
    );

    final shouldClean = await showDialog<bool>(
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
            'عدد الملفات المرصودة: ${selectedItems.fold<int>(0, (sum, item) => sum + item.files)}\n'
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
      // الحذف الفعلي يتم داخل CleanerEngine.
      // لا نضيف خطوات زمنية وهمية تدّعي تنظيف الذاكرة أو تحسين أداء النظام.
      deletedCount = await _engine.clean(
        selected: selectedItems,
        onStatus: (message) {
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

    // لا نعلن أن الجهاز أصبح مثاليًا، ولا نرفع درجة صحة الجهاز تلقائيًا.
    // نعرض فقط العدد الذي أعاده المحرك بوصفه عدد الملفات التي حذفها بنجاح.
    setState(() {
      _isCleaning = false;
      _hasScanned = false;
      scanItems = [];

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
      _showMessage(
        'حدث خطأ أثناء التنظيف. راجع سجل العملية.',
      );
    } else if (deletedCount > 0) {
      _showMessage(
        'تم حذف $deletedCount ملف وفق نتيجة المحرك. يمكنك إعادة الفحص للتحقق مما تبقى.',
      );
    } else {
      _showMessage(
        'لم يتم تأكيد حذف أي ملفات. قد تكون الملفات غير متاحة أو تعذر حذفها.',
      );
    }

    // لا نعيد الفحص تلقائيًا:
    // هذا يترك للمستخدم فرصة مراجعة نتيجة التنظيف وبدء فحص جديد عند رغبته.
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

  /// يضيف رسالة إلى سجل العمليات مع تحديد حجمه حتى لا يتضخم بلا حدود.
  void _addLog(String message) {
    final now = DateTime.now();

    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    logs.insert(0, {
      'time': timeString,
      'message': message.startsWith('[AI]')
          ? message
          : '[AI] $message',
    });

    // الاحتفاظ بآخر 100 رسالة فقط.
    if (logs.length > 100) {
      logs.removeRange(100, logs.length);
    }
  }

  // ---------------------------------------------------------------------------
  // نافذة الاشتراك
  // ---------------------------------------------------------------------------

  void _showPremiumSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1326),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFFD700),
                size: 45,
              ),
              const SizedBox(height: 12),
              const Text(
                'AI Premium',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'واجهة الاشتراك قيد التطوير. '
                'لا يوجد حاليًا تفعيل فعلي للدفع أو ميزات تنظيف إضافية مرتبطة باشتراك.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F2FE),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'قريبًا',
                  style: TextStyle(
                    color: Color(0xFF090D1A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // بناء الواجهة
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // إذا كانت عملية التنظيف الأخيرة هي المعروضة، نظهر نتائجها.
    // أما بعد بدء فحص جديد، فنرجع إلى بيانات الفحص الحالي.
    final showLastCleanup =
        !_hasScanned &&
        !_isCleaning &&
        !state.scanning &&
        _hasCleanupResult;

    final displayedFiles = _hasScanned
        ? _engine.totalFiles
        : showLastCleanup
            ? _lastDeletedFiles
            : 0;

    final displayedBytes = _hasScanned
        ? _engine.totalBytes
        : showLastCleanup
            ? _lastSelectedBytes
            : 0;

    final filesLabel = _hasScanned
        ? 'Files Found'
        : showLastCleanup
            ? 'Files Deleted'
            : 'Files Found';

    final bytesLabel = _hasScanned
        ? 'Candidate Size'
        : showLastCleanup
            ? 'Selected Size'
            : 'Candidate Size';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,

      // القائمة الجانبية.
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
              leading: const Icon(
                Icons.shield_outlined,
                color: Colors.white70,
              ),
              title: const Text(
                'AI Deep Shield',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showMessage('ميزة الحماية قيد التطوير.');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.history_toggle_off_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                'Cleaning History',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showMessage(
                  'سجل التنظيف الدائم غير متاح بعد؛ السجل الحالي مؤقت.',
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

      // الشريط العلوي.
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.menu,
            color: Colors.white,
          ),
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
        actions: [
          IconButton(
            icon: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFFFD700),
              size: 24,
            ),
            onPressed: _showPremiumSheet,
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 5),

              // مؤشر تقدم العملية الحالية.
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

              // بطاقتا ملخص الفحص والحالة الحالية.
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

              // إحصاءات الفحص أو آخر عملية تنظيف.
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

              const SizedBox(height: 12),

              // محتوى المساحة الرئيسية:
              // 1. أثناء الحذف: عرض الحالة الفعلية.
              // 2. بعد الفحص: عرض العناصر التي يستطيع المحرك التعامل معها.
              // 3. قبل الفحص: عرض سجل الرسائل والأدوات.
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

              // الزر الرئيسي يتغير وفق حالة الفحص.
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

      // شريط التنقل السفلي.
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

          switch (index) {
            case 0:
              // الشاشة الرئيسية الحالية.
              break;

            case 1:
              _showMessage('قسم الأدوات قيد التطوير.');
              break;

            case 2:
              _showMessage('قسم المراقبة قيد التطوير.');
              break;

            case 3:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded, size: 20),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.construction_rounded, size: 20),
            label: 'Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined, size: 20),
            label: 'Monitor',
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
      // نعرض عدد الملفات المرصودة بدل اختراع درجة لصحة الجهاز.
      mainText = '${_engine.totalFiles}';
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
            'SCAN SUMMARY',
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
                _showMessage('عرض السجل الكامل قيد التطوير.');
              },
              child: const Text(
                'View All >',
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
                    final log = logs[index];

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
          'Smart Tools',
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
              Icons.folder_open_outlined,
              'Large Files',
              () {
                _showMessage('ميزة البحث عن الملفات الكبيرة قيد التطوير.');
              },
            ),
            _buildInteractiveTool(
              Icons.copy_all_outlined,
              'Duplicates',
              () {
                _showMessage('ميزة البحث عن الملفات المكررة قيد التطوير.');
              },
            ),
            _buildInteractiveTool(
              Icons.developer_mode_outlined,
              'App Manager',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
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
