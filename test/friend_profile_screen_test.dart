import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/screens/friend_profile_screen.dart';
import 'package:forge/services/friend_data_service.dart';
import 'package:forge/services/friends_service.dart';
import 'package:forge/theme.dart';

void main() {
  test('friend data day IDs use yyyy-MM-dd', () {
    expect(FriendDataService.dayId(DateTime(2025, 2, 3)), '2025-02-03');
  });

  testWidgets('profile distinguishes locked categories from empty days', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final data = FriendSharedData(
      workouts: const SharedCategoryData(shared: true, days: {}),
      food: const SharedCategoryData(shared: false, days: {}),
      health: SharedCategoryData(
        shared: true,
        days: {
          today: {'steps': 5200},
        },
      ),
      body: const SharedCategoryData(shared: true, days: {}),
      lastSynced: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [ForgeTokens.dark]),
        home: FriendProfileScreen(
          friend: const FriendSummary(
            uid: 'friend-uid',
            username: 'alex',
            displayName: 'Alex',
          ),
          loadFriendData: (_) async => data,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsWidgets);
    expect(find.text('Today'), findsOneWidget);
    expect(tester.getRect(find.text('Today')).right, lessThanOrEqualTo(800));
    final verticalScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('No data for this day.'),
      300,
      scrollable: verticalScrollable,
    );
    expect(find.text('No data for this day.'), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(
      find.text("Food isn't sharing this."),
      300,
      scrollable: verticalScrollable,
    );
    expect(find.text("Food isn't sharing this."), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Steps · 5200'),
      300,
      scrollable: verticalScrollable,
    );
    expect(find.text('Steps · 5200'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
