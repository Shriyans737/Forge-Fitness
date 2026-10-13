import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../theme.dart';
import '../widgets/exercise_video_section.dart';
import '../widgets/ui/pill_tag.dart';
import '../widgets/ui/primary_gradient_button.dart';
import '../widgets/ui/shimmer_box.dart';
import 'active_workout_screen.dart';
import 'exercise_progress_screen.dart';
import '../widgets/muscle_map.dart';

/// Read-only information for an exercise stored in the local library.
///
/// The bundled free-exercise-db JSON contains relative image paths, rather
/// than image assets. Those paths are served from the dataset's repository.
class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({
    required this.exercise,
    this.showAddToWorkout = true,
    super.key,
  });

  final Exercise exercise;
  final bool showAddToWorkout;

  static const _imageBaseUrl =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';

  List<String> get _imagePaths => exercise.imagePaths
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .toList(growable: false);

  List<String> get _instructions => exercise.instructions
      .map((instruction) => instruction.trim())
      .where((instruction) => instruction.isNotEmpty)
      .toList(growable: false);

  List<String> get _primaryMuscles => exercise.primaryMuscles
      .map((muscle) => muscle.trim())
      .where((muscle) => muscle.isNotEmpty)
      .toList(growable: false);

  List<String> get _secondaryMuscles => exercise.secondaryMuscles
      .map((muscle) => muscle.trim())
      .where((muscle) => muscle.isNotEmpty)
      .toList(growable: false);

  String _imageUrlForPath(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return '$_imageBaseUrl${path.replaceAll('\\', '/')}';
  }

  Widget _imageGallery(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final imageHeight =
        (MediaQuery.sizeOf(context).width * 0.62).clamp(
      ForgeSpacing.xxl * 3,
      ForgeSpacing.xxxl * 4,
    );
    final imagePaths = _imagePaths;
    if (imagePaths.isEmpty) {
      return _ImageFallback(
        message: 'No images available for this exercise',
        color: tokens.surfaceVariant,
        height: imageHeight,
      );
    }

    final images = imagePaths.asMap().entries.map((entry) {
      final image = _ExerciseImage(
        imageUrl: _imageUrlForPath(entry.value),
        heroTag: 'exercise-demo-${exercise.id}',
        useHero: entry.key == 0,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: ForgeSpacing.xxs),
        child: image,
      );
    }).toList(growable: false);

    if (images.length == 1) {
      return SizedBox(height: imageHeight, child: images.single);
    }

    if (images.length == 2) {
      return SizedBox(
        height: imageHeight,
        child: Row(
          children: [
            Expanded(child: images.first),
            const SizedBox(width: ForgeSpacing.xs),
            Expanded(child: images.last),
          ],
        ),
      );
    }

    return SizedBox(
      height: imageHeight,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: images[index],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final equipment = exercise.equipment?.trim();
    final instructions = _instructions;
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            ForgeSpacing.md,
            ForgeSpacing.sm,
            ForgeSpacing.md,
            ForgeSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imageGallery(context),
              const SizedBox(height: ForgeSpacing.lg),
              Text(
                exercise.name,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: ForgeSpacing.sm),
              Wrap(
                spacing: ForgeSpacing.xs,
                runSpacing: ForgeSpacing.xs,
                children: [
                  PillTag(
                    label: exercise.muscleGroup.isEmpty
                        ? 'Body part not specified'
                        : 'Body part · ${exercise.muscleGroup}',
                    variant: PillTagVariant.accent,
                  ),
                  ..._primaryMuscles.map(
                    (muscle) => PillTag(
                      label: 'Target · $muscle',
                      variant: PillTagVariant.accent,
                    ),
                  ),
                  ..._secondaryMuscles.map(
                    (muscle) => PillTag(
                      label: 'Secondary · $muscle',
                      variant: PillTagVariant.neutral,
                    ),
                  ),
                  PillTag(
                    label: equipment == null || equipment.isEmpty
                        ? 'Bodyweight / unspecified'
                        : equipment,
                    variant: PillTagVariant.neutral,
                    icon: Icons.fitness_center,
                  ),
                ],
              ),
              const SizedBox(height: ForgeSpacing.lg),
              ExerciseVideoSection(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
              ),
              const SizedBox(height: ForgeSpacing.lg),
              MuscleMapWidget(
                primaryMuscles: _primaryMuscles,
                secondaryMuscles: _secondaryMuscles,
              ),
              const SizedBox(height: ForgeSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExerciseProgressScreen(
                        exerciseId: exercise.id,
                        exerciseName: exercise.name,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.show_chart),
                  label: const Text('Progress'),
                ),
              ),
              const SizedBox(height: ForgeSpacing.lg),
              Container(
                padding: const EdgeInsets.all(ForgeSpacing.md),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(tokens.cardRadius),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to perform',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: ForgeSpacing.md),
                    if (instructions.isEmpty)
                      const _InstructionsFallback()
                    else
                      ...instructions.asMap().entries.map(
                        (entry) => _InstructionStep(
                          number: entry.key + 1,
                          instruction: entry.value,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ),
      bottomNavigationBar: showAddToWorkout
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ForgeSpacing.md,
                  vertical: ForgeSpacing.xs,
                ),
                child: SizedBox(
                  height: ForgeSpacing.xxxl - ForgeSpacing.xs,
                  child: PrimaryGradientButton(
                    label: 'Add to workout',
                    icon: Icons.add_rounded,
                    expand: true,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ActiveWorkoutScreen(
                            initialExerciseIds: [exercise.id],
                            initialWorkoutName: exercise.name,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _ExerciseImage extends StatelessWidget {
  const _ExerciseImage({
    required this.imageUrl,
    required this.heroTag,
    required this.useHero,
  });

  final String imageUrl;
  final String heroTag;
  final bool useHero;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(tokens.heroRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        fit: BoxFit.contain,
        placeholder: (context, _) => const ShimmerBox(),
        errorWidget: (context, error, stackTrace) {
          debugPrint(
            'Exercise image failed: url=$imageUrl error=$error\n'
            'stackTrace=$stackTrace',
          );
          return _ImageFallback(
            message: 'Exercise demo unavailable',
            color: tokens.surfaceVariant,
            height: MediaQuery.sizeOf(context).width * 0.62,
          );
        },
      ),
    );
    return useHero
        ? Hero(tag: heroTag, child: image)
        : image;
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({
    required this.message,
    required this.color,
    required this.height,
  });

  final String message;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(
          Theme.of(context).extension<ForgeTokens>()!.heroRadius,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              size: ForgeSpacing.xxl,
            ),
            const SizedBox(height: ForgeSpacing.xs),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InstructionsFallback extends StatelessWidget {
  const _InstructionsFallback();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(ForgeSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(
        Theme.of(context).extension<ForgeTokens>()!.controlRadius,
      ),
    ),
    child: const Text('No instructions available for this exercise'),
  );
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.instruction});

  final int number;
  final String instruction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ForgeSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: ForgeSpacing.sm,
          child: Text('$number', style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(width: ForgeSpacing.sm),
        Expanded(
          child: Text(
            instruction,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
      ],
    ),
  );
}
