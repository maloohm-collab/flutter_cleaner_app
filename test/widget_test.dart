import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleaner_app/main.dart';

void main() {
  testWidgets('AI Optimizer activation screen shows phone and code fields',
      (WidgetTester tester) async {
    // Firebase is initialized by the Android runtime; widget tests should
    // verify the UI independently of native Firebase services.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CleanerApp());
    await tester.pump();

    expect(find.text('AI OPTIMIZER'), findsOneWidget);
    expect(find.text('رقم الهاتف المرتبط بالاشتراك'), findsOneWidget);
    expect(find.text('كود التفعيل'), findsOneWidget);
    expect(find.text('طلب كود التفعيل عبر واتساب — 2 دينار'), findsOneWidget);
  });
}
