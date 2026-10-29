import 'package:flutter/material.dart';
import 'package:flutter_cleaner_app/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('subscriptionRemainingLabel', () {
    test('uses correct Arabic wording', () {
      expect(subscriptionRemainingLabel(0), 'ينتهي اليوم');
      expect(subscriptionRemainingLabel(1), 'متبقٍ يوم واحد');
      expect(subscriptionRemainingLabel(2), 'متبقٍ يومان');
      expect(subscriptionRemainingLabel(5), 'متبقٍ 5 أيام');
      expect(subscriptionRemainingLabel(10), 'متبقٍ 10 أيام');
      expect(subscriptionRemainingLabel(11), 'متبقٍ 11 يومًا');
    });
  });
  testWidgets('shows remaining days for active subscription', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'subscription_activated_at_ms': now.subtract(const Duration(days: 20)).millisecondsSinceEpoch,
      'subscription_expiry_ms': now.add(const Duration(days: 10, hours: 1)).millisecondsSinceEpoch,
    });
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen())); await tester.pumpAndSettle();
    expect(find.text('متبقٍ 10 أيام'), findsOneWidget); expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
  testWidgets('shows no countdown without local activation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen())); await tester.pumpAndSettle();
    expect(find.text('لا يوجد تفعيل محلي على هذا الجهاز'), findsOneWidget); expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
