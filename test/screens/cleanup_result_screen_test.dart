import 'package:flutter/material.dart';
import 'package:flutter_cleaner_app/screens/cleanup_result_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Future<bool?> openAndTap(WidgetTester tester, Widget screen, String buttonText) async {
  bool? result;
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: Center(child: ElevatedButton(onPressed: () async { result = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(builder: (_) => screen)); }, child: const Text('open'))))));
  await tester.tap(find.text('open')); await tester.pumpAndSettle();
  await tester.tap(find.text(buttonText)); await tester.pumpAndSettle();
  return result;
}
void main() {
  testWidgets('shows confirmed deleted count and freed size', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CleanupResultScreen(deletedFiles: 3, freedBytes: 2048, selectedBytes: 4096)));
    expect(find.text('اكتمل التنظيف'), findsOneWidget); expect(find.text('3'), findsOneWidget); expect(find.text('2.00 KB'), findsOneWidget);
  });
  testWidgets('does not claim success when nothing was deleted', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CleanupResultScreen(deletedFiles: 0, freedBytes: 0, selectedBytes: 4096)));
    expect(find.text('لم يُحذف أي ملف'), findsOneWidget); expect(find.text('اكتمل التنظيف'), findsNothing);
  });
  testWidgets('rescan returns true', (tester) async {
    expect(await openAndTap(tester, const CleanupResultScreen(deletedFiles: 1, freedBytes: 10, selectedBytes: 10), 'إعادة الفحص'), isTrue);
  });
  testWidgets('done returns false', (tester) async {
    expect(await openAndTap(tester, const CleanupResultScreen(deletedFiles: 1, freedBytes: 10, selectedBytes: 10), 'تم'), isFalse);
  });
}
