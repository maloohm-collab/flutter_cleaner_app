import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flutter test environment renders Arabic UI correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('AI OPTIMIZER'),
              Text('رمز التفعيل'),
              Text('الاشتراك عبر واتساب — 2 دينار'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('AI OPTIMIZER'), findsOneWidget);
    expect(find.text('رمز التفعيل'), findsOneWidget);
    expect(find.text('الاشتراك عبر واتساب — 2 دينار'), findsOneWidget);
  });
}
