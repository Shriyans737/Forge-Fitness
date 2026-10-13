import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/dashboard/widgets/dashboard_friends_card.dart';
import 'package:forge/services/friend_data_service.dart';
import 'package:forge/services/friends_dashboard_controller.dart';
import 'package:forge/services/friends_service.dart';
import 'package:forge/theme.dart';

void main() {
  test('controller tracks incoming requests and caches friend data', () async {
    final requests = StreamController<List<FriendRequest>>();
    final friends = StreamController<List<FriendSummary>>();
    var loads = 0;
    final controller = FriendsDashboardController(
      loadUid: () async => 'me',
      incomingRequests: (_) => requests.stream,
      friends: (_) => friends.stream,
      loadFriendData: (_) async {
        loads++;
        return _sharedData();
      },
    );

    await controller.start();
    requests.add([_request()]);
    friends.add([_friend()]);
    await Future<void>.delayed(Duration.zero);

    expect(controller.incomingRequestCount, 1);
    expect(controller.friends, [_friend()]);
    expect(await controller.dataFor('friend'), isNotNull);
    expect(loads, 1);

    controller.dispose();
    await requests.close();
    await friends.close();
  });

  testWidgets('dashboard Friends card shows shared metrics and See all', (
    tester,
  ) async {
    final requests = StreamController<List<FriendRequest>>();
    final friends = StreamController<List<FriendSummary>>();
    final controller = FriendsDashboardController(
      loadUid: () async => 'me',
      incomingRequests: (_) => requests.stream,
      friends: (_) => friends.stream,
      loadFriendData: (_) async => _sharedData(),
    );
    await controller.start();
    friends.add([_friend()]);
    await Future<void>.delayed(Duration.zero);

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.darkTheme,
        home: Scaffold(
          body: ListView(
            children: [
              DashboardFriendsCard(
                controller: controller,
                onSeeAll: () {},
                onOpenFriend: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('FRIENDS'), findsOneWidget);
    expect(find.textContaining('kcal · 1800'), findsOneWidget);
    expect(find.textContaining('steps · 6400'), findsOneWidget);
    expect(find.textContaining('vol · 1200'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.dispose();
    await requests.close();
    await friends.close();
  });

  testWidgets('empty Friends card offers Add friends', (tester) async {
    final requests = StreamController<List<FriendRequest>>();
    final friends = StreamController<List<FriendSummary>>();
    final controller = FriendsDashboardController(
      loadUid: () async => 'me',
      incomingRequests: (_) => requests.stream,
      friends: (_) => friends.stream,
    );
    await controller.start();
    friends.add(const []);
    await Future<void>.delayed(Duration.zero);

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.darkTheme,
        home: Scaffold(
          body: DashboardFriendsCard(
            controller: controller,
            onSeeAll: () {},
            onOpenFriend: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Your Forge crew starts here.'), findsOneWidget);
    expect(find.text('Add friends'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.dispose();
    await requests.close();
    await friends.close();
  });
}

FriendSummary _friend() =>
    const FriendSummary(uid: 'friend', username: 'alex', displayName: 'Alex');

FriendRequest _request() => const FriendRequest(
  id: 'request',
  fromUid: 'friend',
  toUid: 'me',
  fromUsername: 'alex',
  fromDisplayName: 'Alex',
  createdAt: null,
);

FriendSharedData _sharedData() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return FriendSharedData(
    workouts: SharedCategoryData(
      shared: true,
      days: {
        today: {
          'dailyTotals': {'totalVolume': 1200},
        },
      },
    ),
    food: SharedCategoryData(
      shared: true,
      days: {
        today: {'calories': 1800},
      },
    ),
    health: SharedCategoryData(
      shared: true,
      days: {
        today: {'steps': 6400},
      },
    ),
    body: const SharedCategoryData(shared: false, days: {}),
    lastSynced: null,
  );
}
