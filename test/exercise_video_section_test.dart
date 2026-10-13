import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/services/youtube_id_service.dart';
import 'package:forge/theme.dart';
import 'package:forge/widgets/exercise_video_section.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() {
  testWidgets('shows tutorial search when the exercise has no video ID', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ExerciseVideoSection(
          exerciseId: 'exercise-id',
          exerciseName: 'Sample exercise',
          service: _fakeService('{}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Watch tutorial'), findsOneWidget);
    expect(find.byType(YoutubePlayer), findsNothing);
  });

  testWidgets('shows a thumbnail without creating the player before tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ExerciseVideoSection(
          exerciseId: 'exercise-id',
          exerciseName: 'Sample exercise',
          service: _fakeService('{"exercise-id":"abcdefghijk"}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(YoutubePlayer), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      contains('/vi/abcdefghijk/hqdefault.jpg'),
    );
    expect(find.text('Open in YouTube'), findsOneWidget);
  });
}

YoutubeIdService _fakeService(String json) =>
    YoutubeIdService(assetLoader: (_) async => json);

Widget _app(Widget child) => MaterialApp(
  theme: ForgeTheme.lightTheme,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      child: child,
    ),
  ),
);
