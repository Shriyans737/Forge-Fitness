import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/screens/name_onboarding_screen.dart';
import 'package:forge/theme.dart';
import 'package:forge/widgets/ui/primary_gradient_button.dart';

void main() {
  testWidgets('onboarding keeps Continue disabled for an empty name', (
    tester,
  ) async {
    var savedName = '';
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.lightTheme,
        home: NameOnboardingScreen(onContinue: (name) => savedName = name),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('What should we call you?'), findsOneWidget);
    expect(
      tester
          .widget<PrimaryGradientButton>(find.byType(PrimaryGradientButton))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(
      tester
          .widget<PrimaryGradientButton>(find.byType(PrimaryGradientButton))
          .onPressed,
      isNull,
    );
    expect(savedName, isEmpty);

    await tester.enterText(find.byType(TextField), ' Mira ');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    expect(savedName, 'Mira');
  });
}
