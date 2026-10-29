import 'package:flutter/material.dart';
import 'package:flutter_cleaner_app/screens/storage_permission_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Future<bool?> openAndTap(WidgetTester tester, String text) async {
  bool? result;
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: Center(child: ElevatedButton(onPressed: () async { result = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(builder: (_) => const StoragePermissionScreen())); }, child: const Text('open'))))));
  await tester.tap(find.text('open')); await tester.pumpAndSettle(); await tester.tap(find.text(text)); await tester.pumpAndSettle(); return result;
}
void main() {
  testWidgets('explains permission before requesting it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StoragePermissionScreen()));
    expect(find.text('لماذا نطلبها؟'), findsOneWidget); expect(find.text('لا يُحذف شيء دون موافقتك'), findsOneWidget); expect(find.text('متابعة'), findsOneWidget); expect(find.text('ليس الآن'), findsOneWidget);
  });
  testWidgets('continue returns true', (tester) async { expect(await openAndTap(tester, 'متابعة'), isTrue); });
  testWidgets('not now returns false', (tester) async { expect(await openAndTap(tester, 'ليس الآن'), isFalse); });
}
