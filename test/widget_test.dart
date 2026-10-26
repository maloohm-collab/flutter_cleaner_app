import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleaner_app/main.dart';

void main() {
  testWidgets('AI Cleaner opens the activation screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CleanerApp());
    await tester.pumpAndSettle();

    expect(find.text('AI SYSTEM ACCESS'), findsOneWidget);
    expect(find.text('Smart Cleaner & Optimizer'), findsOneWidget);
    expect(find.text('Activation Key'), findsOneWidget);
  });
}
