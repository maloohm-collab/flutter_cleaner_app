import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cleaner_app/screens/activation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'AI Optimizer activation screen shows code field and WhatsApp option',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: ActivationScreen()),
      );
      // Avoid pumpAndSettle: the screen includes animated visual elements.
      await tester.pump();

      expect(find.text('AI OPTIMIZER'), findsOneWidget);
      expect(find.text('رمز التفعيل'), findsOneWidget);
      expect(find.text('الاشتراك عبر واتساب — 2 دينار'), findsOneWidget);
    },
  );
}
