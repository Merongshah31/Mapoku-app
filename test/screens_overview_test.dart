import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapoku/core/theme/app_theme.dart';
import 'package:mapoku/screens/reports_screen.dart';
import 'package:mapoku/screens/rewards_screen.dart';
import 'package:mapoku/state/app_scope.dart';
import 'package:mapoku/state/app_state.dart';

void main() {
  Widget wrapWithApp(Widget child) {
    final state = AppState();
    return AppScope(
      state: state,
      child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
    );
  }

  testWidgets('reports screen shows status, CTA and segmented controls', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithApp(const ReportsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Status: Active community updates'), findsOneWidget);
    expect(find.text('Report an obstacle'), findsAtLeastNWidgets(1));
    expect(find.text('Community'), findsOneWidget);
    expect(find.textContaining('My reports'), findsOneWidget);
    expect(find.text('Still there'), findsWidgets);
  });

  testWidgets('rewards screen shows points summary and tabs', (tester) async {
    await tester.pumpWidget(wrapWithApp(const RewardsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Status: Earning'), findsOneWidget);
    expect(find.text('Your points'), findsOneWidget);
    expect(find.text('Ways to earn'), findsOneWidget);
    expect(find.text('Redeem'), findsOneWidget);
    expect(find.textContaining('Vouchers'), findsOneWidget);
  });
}
