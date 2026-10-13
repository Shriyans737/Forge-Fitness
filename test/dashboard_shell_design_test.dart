import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/motion.dart';
import 'package:forge/core/widgets/glass_nav_bar.dart';
import 'package:forge/features/dashboard/widgets/liquid_start_button.dart';
import 'package:forge/theme.dart';
import 'package:forge/widgets/ui/floating_bottom_nav.dart';

void main() {
  testWidgets('glass navigation selects a tab and updates its selection', (
    tester,
  ) async {
    var selectedIndex = 0;
    const items = [
      FloatingNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined),
      FloatingNavItem(label: 'Workouts', icon: Icons.fitness_center_outlined),
      FloatingNavItem(label: 'Library', icon: Icons.library_books_outlined),
      FloatingNavItem(label: 'Health', icon: Icons.favorite_outline),
      FloatingNavItem(
        label: 'Friends',
        icon: Icons.people_alt_outlined,
        badgeCount: 2,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.darkTheme,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Center(child: Text('Selected ${items[selectedIndex].label}')),
            bottomNavigationBar: GlassNavBar(
              items: items,
              selectedIndex: selectedIndex,
              onTap: (index) => setState(() => selectedIndex = index),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Workouts'));
    await tester.pump();
    expect(find.text('Selected Workouts'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Workouts' &&
            widget.properties.selected == true,
      ),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
    final selectedLabel = tester.widget<Text>(find.text('Workouts'));
    expect(selectedLabel.style?.color, const Color(0xFFE8F5F1));
    await tester.tap(find.text('Friends'));
    await tester.pump();
    expect(find.text('Selected Friends'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.startsWith('Friends') == true &&
            widget.properties.selected == true,
      ),
      findsOneWidget,
    );
    await tester.pump(ForgeMotion.tabSelection);
  });

  testWidgets('liquid start button starts a workout on a quick tap', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidStartButton(
            reduceMotion: true,
            onStartWorkout: () => starts++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(LiquidStartButton));
    await tester.pump(ForgeMotion.liquidQuickRise);
    await tester.pump(ForgeMotion.liquidReadyHold);
    expect(starts, 1);
  });

  testWidgets('liquid start button starts after a full press and hold', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LiquidStartButton(onStartWorkout: () => starts++)),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LiquidStartButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(ForgeMotion.liquidRise);
    await gesture.up();
    expect(starts, 0);
    await tester.pump(ForgeMotion.liquidReadyHold);
    expect(starts, 1);
  });
}
