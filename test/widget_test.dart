import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleaner_app/main.dart';

void main() {
  testWidgets('AI Optimizer activation screen shows code field and WhatsApp option',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CleanerApp());
    await tester.pumpAndSettle();

    expect(find.text('AI OPTIMIZER'), findsOneWidget);
    expect(find.text('رمز التفعيل'), findsOneWidget);
    expect(find.text('الاشتراك عبر واتساب — 2 دينار'), findsOneWidget);
  });
}
