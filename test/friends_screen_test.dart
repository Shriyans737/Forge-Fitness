import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/screens/friends_screen.dart';
import 'package:forge/services/auth_service.dart';

void main() {
  testWidgets('Friends shows an offline state when Firebase is unavailable', (
    tester,
  ) async {
    AuthService.isFirebaseInitialized = false;

    await tester.pumpWidget(
      const MaterialApp(home: FriendsScreen(displayName: 'Alex Smith')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Friends are offline. Check your internet connection.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
