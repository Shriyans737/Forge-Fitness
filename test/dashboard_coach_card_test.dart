import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/coach/services/coach_engine.dart';
import 'package:forge/features/coach/widgets/dashboard_coach_card.dart';
import 'package:forge/theme.dart';

void main() {
  testWidgets('dashboard coach card shows the top insight from its context', (
    tester,
  ) async {
    final context = CoachContext(now: DateTime(2026, 10, 10, 12), recovery: 20);
    final insights = const CoachEngine().generate(context);
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.darkTheme,
        home: Scaffold(
          body: DashboardCoachCard(
            insights: insights,
            onOpen: () => opened = true,
            onInsightShown: (_) {},
          ),
        ),
      ),
    );

    expect(find.text(insights.first.title), findsOneWidget);
    await tester.tap(find.text(insights.first.title));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
