// ============================================================================
// Project      : AI Cleaner
// File         : lib/models/dashboard_state.dart
// Version      : 1.1.0
// Last Updated : 2026-10-10
// Purpose      : تمثيل الحالة الموحدة للوحة التحكم، بما يشمل حالة الفحص
//                والتقدم ودرجة الصحة والإحصاءات والمهمة الحالية.
// ----------------------------------------------------------------------------
// Changes in v1.1.0:
// - إضافة ترويسة موحدة وتوثيق عربي.
// - الحفاظ على الحقول والقيم الافتراضية الحالية.
// - المحافظة على دالة copyWith والتوافق مع الشاشات.
// - حصر progress ضمن النطاق 0.0 إلى 1.0.
// - حصر healthScore ضمن النطاق 0.0 إلى 100.0.
// ----------------------------------------------------------------------------
// Safety Notes:
// - healthScore قيمة عرضية تعتمد على طريقة حساب المستدعي، وليست تشخيصًا
//   حقيقيًا لصحة الجهاز.
// - progress يجب أن يعكس تقدم العملية الفعلية عند ربطه بمحرك الفحص.
// - analysisFinished لا يعني أن الملفات حُذفت؛ بل يدل على انتهاء التحليل.
// ----------------------------------------------------------------------------
// Dependencies:
// - Dart SDK فقط.
// ----------------------------------------------------------------------------
// Compatibility:
// - يحافظ على جميع أسماء الحقول والوسائط الحالية.
// - يحافظ على القيم الافتراضية الحالية.
// - لم يُنفّذ بناء Flutter أو اختبار آلي ضمن هذه المراجعة.
// ============================================================================

/// الحالة غير القابلة للتعديل للبيانات المعروضة في لوحة التحكم.
class DashboardState {
  /// هل عملية الفحص جارية حاليًا؟
  final bool scanning;

  /// هل انتهى تحليل الملفات؟
  ///
  /// لا تعني هذه القيمة أن عملية التنظيف أو الحذف قد اكتملت.
  final bool analysisFinished;

  /// نسبة تقدم العملية من 0.0 إلى 1.0.
  final double progress;

  /// درجة الصحة المعروضة في الواجهة من 0 إلى 100.
  ///
  /// يجب التعامل معها بوصفها مؤشرًا تقديريًا فقط.
  final double healthScore;

  /// عدد الملفات المكتشفة.
  final int totalFiles;

  /// إجمالي حجم الملفات المكتشفة بالبايت.
  final int totalBytes;

  /// وصف المهمة الحالية المعروض للمستخدم.
  final String currentTask;

  /// إنشاء حالة جديدة بالقيم الافتراضية.
  const DashboardState({
    this.scanning = false,
    this.analysisFinished = false,
    this.progress = 0,
    this.healthScore = 100,
    this.totalFiles = 0,
    this.totalBytes = 0,
    this.currentTask = 'Ready',
  });

  /// إنشاء نسخة محدثة من الحالة مع الاحتفاظ بالحقول غير المعدلة.
  ///
  /// تُحصر progress وhealthScore ضمن نطاقيهما المتوقعين.
  DashboardState copyWith({
    bool? scanning,
    bool? analysisFinished,
    double? progress,
    double? healthScore,
    int? totalFiles,
    int? totalBytes,
    String? currentTask,
  }) {
    final double nextProgress =
        (progress ?? this.progress).clamp(0.0, 1.0).toDouble();

    final double nextHealthScore =
        (healthScore ?? this.healthScore)
            .clamp(0.0, 100.0)
            .toDouble();

    return DashboardState(
      scanning: scanning ?? this.scanning,
      analysisFinished: analysisFinished ?? this.analysisFinished,
      progress: nextProgress,
      healthScore: nextHealthScore,
      totalFiles: totalFiles ?? this.totalFiles,
      totalBytes: totalBytes ?? this.totalBytes,
      currentTask: currentTask ?? this.currentTask,
    );
  }
}
