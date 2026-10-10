// ============================================================================
// Project      : AI Cleaner
// File         : lib/services/scan_pipeline.dart
// Version      : 1.1.0
// Last Updated : 2026-10-10
// Purpose      : تنظيم مراحل عرض تقدم عملية الفحص في الواجهة، مع المحافظة
//                على ترتيب المراحل وتوقيع callback المستخدم من الشاشات.
// ----------------------------------------------------------------------------
// Changes in v1.1.0:
// - إضافة ترويسة موحدة وتوثيق عربي.
// - توضيح أن المراحل هنا للعرض وليست عمليات فحص فعلية.
// - الحفاظ على قيم ScanStage وترتيب المراحل.
// - الحفاظ على توقيع start وبيانات callback للتوافق مع الشاشات الحالية.
// - توضيح رسائل المراحل وتوحيد مصدرها.
// - المحافظة على التأخير القصير بين المراحل لعرض تقدم الواجهة.
// ----------------------------------------------------------------------------
// Safety Notes:
// - هذا الملف لا يفحص الملفات ولا يحذفها.
// - نسب التقدم هنا تمثل مراحل العرض فقط، ولا تمثل تقدم CleanerEngine الحقيقي.
// - يجب تشغيل CleanerEngine.scan() لإجراء الفحص الفعلي.
// - يجب عدم إظهار نتيجة نجاح التنظيف اعتمادًا على هذا الملف وحده.
// ----------------------------------------------------------------------------
// Dependencies:
// - Dart SDK فقط.
// ----------------------------------------------------------------------------
// Compatibility:
// - يحافظ على ScanStage وعلى ScanPipeline.start(onStage).
// - يحافظ على قيم التعداد ورسائل المراحل الأصلية.
// - لم يُنفّذ بناء Flutter أو اختبار آلي ضمن هذه المراجعة.
// ============================================================================

/// مراحل العرض التي تمر بها واجهة الفحص.
///
/// هذه القيم تصف المرحلة المعروضة للمستخدم، ولا تنفذ الفحص بنفسها.
enum ScanStage {
  initializing,
  analyzingStorage,
  scanningThumbnails,
  scanningTempFiles,
  scanningLogs,
  scanningEmptyFolders,
  buildingPlan,
  ready,
}

/// توقيع callback الذي تستدعيه مراحل العرض.
///
/// المعاملات:
/// - stage: المرحلة الحالية.
/// - progress: نسبة تقدم العرض من 0.0 إلى 1.0.
/// - message: الرسالة المرتبطة بالمرحلة الحالية.
typedef ScanStageCallback = Future<void> Function(
  ScanStage stage,
  double progress,
  String message,
);

/// منسّق مراحل تقدم واجهة الفحص.
///
/// تنبيه مهم:
/// هذا المنسّق يحاكي تسلسل المراحل لعرضها في الواجهة فقط.
/// لا يستبدل CleanerEngine ولا ينفذ عمليات قراءة أو حذف للملفات.
class ScanPipeline {
  /// مدة الانتظار بين المراحل لأغراض العرض.
  static const Duration _stageDelay = Duration(milliseconds: 500);

  /// ترتيب المراحل المعروضة.
  static const List<ScanStage> _stages = <ScanStage>[
    ScanStage.initializing,
    ScanStage.analyzingStorage,
    ScanStage.scanningThumbnails,
    ScanStage.scanningTempFiles,
    ScanStage.scanningLogs,
    ScanStage.scanningEmptyFolders,
    ScanStage.buildingPlan,
    ScanStage.ready,
  ];

  /// بدء تسلسل مراحل العرض.
  ///
  /// يستدعي [onStage] بالترتيب التالي:
  /// المرحلة الحالية، ونسبة التقدم، والرسالة.
  ///
  /// عند وصول المرحلة إلى ready تكون مراحل العرض قد انتهت؛
  /// لكن ذلك لا يعني أن الفحص الحقيقي قد اكتمل ما لم تنفذه خدمة الفحص.
  ///
  /// إذا رمى [onStage] استثناءً، فسيُمرر الاستثناء إلى المستدعي.
  Future<void> start(ScanStageCallback onStage) async {
    for (int index = 0; index < _stages.length; index++) {
      final ScanStage stage = _stages[index];
      final double progress = (index + 1) / _stages.length;

      await onStage(
        stage,
        progress,
        _message(stage),
      );

      if (index < _stages.length - 1) {
        await Future<void>.delayed(_stageDelay);
      }
    }
  }

  /// إرجاع الرسالة المرتبطة بكل مرحلة.
  ///
  /// أُبقيت الرسائل الإنجليزية للمحافظة على سلوك الواجهة الحالية.
  String _message(ScanStage stage) {
    switch (stage) {
      case ScanStage.initializing:
        return 'Initializing AI Engine...';

      case ScanStage.analyzingStorage:
        return 'Analyzing Device Storage...';

      case ScanStage.scanningThumbnails:
        return 'Scanning Thumbnail Cache...';

      case ScanStage.scanningTempFiles:
        return 'Scanning Temporary Files...';

      case ScanStage.scanningLogs:
        return 'Scanning Log Files...';

      case ScanStage.scanningEmptyFolders:
        return 'Scanning Empty Folders...';

      case ScanStage.buildingPlan:
        return 'Building Safe Cleaning Plan...';

      case ScanStage.ready:
        return 'Analysis Complete';
    }
  }
}
