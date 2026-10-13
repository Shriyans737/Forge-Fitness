import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/splash/splash_painter.dart';
import 'package:forge/features/splash/splash_screen.dart';

void main() {
  testWidgets(
    'keeps the splash moving and defers home until preload and 1.9s',
    (tester) async {
      final preload = Completer<void>();
      var homeBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: false),
              child: SplashScreen(
                preloadFuture: preload.future,
                homeBuilder: (_) {
                  homeBuilds++;
                  return const Scaffold(body: Center(child: Text('Real home')));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(homeBuilds, 0);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is SplashPainter,
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 500));
      final painter = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is SplashPainter,
        ),
      );
      expect(
        (painter.painter! as SplashPainter).animation.value,
        greaterThan(0),
      );
      await tester.pump(const Duration(milliseconds: 1400));
      expect(homeBuilds, 0);

      preload.complete();
      await tester.pump();
      expect(homeBuilds, greaterThan(0));
      expect(find.text('Real home'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pump();
      expect(find.text('Real home'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter is SplashPainter,
        ),
        findsNothing,
      );
    },
  );

  testWidgets('watchdog escapes a muted splash ticker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: SplashScreen(
            preloadFuture: Future<void>.value(),
            homeBuilder: (_) =>
                const Scaffold(body: Center(child: Text('Real home'))),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Real home'), findsNothing);

    await tester.pump(const Duration(seconds: 6));

    expect(find.text('Real home'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is SplashPainter,
      ),
      findsNothing,
    );
  });

  testWidgets(
    'shows a clear fallback if preload has not completed at timeout',
    (tester) async {
      final preload = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            preloadFuture: preload.future,
            homeBuilder: (_) =>
                const Scaffold(body: Center(child: Text('Real home'))),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));

      expect(
        find.text('Forge is taking longer than expected to load.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      preload.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Real home'), findsOneWidget);
    },
  );

  testWidgets('preload errors are logged and do not prevent home', (
    tester,
  ) async {
    final preload = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          preloadFuture: preload.future,
          homeBuilder: (_) =>
              const Scaffold(body: Center(child: Text('Real home'))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1900));
    preload.completeError(StateError('startup test failure'));
    await tester.pump();

    expect(find.text('Real home'), findsOneWidget);
  });

  testWidgets('reduced motion bypasses the splash immediately', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: SplashScreen(
              preloadFuture: Future<void>.value(),
              homeBuilder: (_) =>
                  const Scaffold(body: Center(child: Text('Real home'))),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Real home'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is SplashPainter,
      ),
      findsNothing,
    );
  });
}
