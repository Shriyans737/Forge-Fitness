import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/motion.dart';
import '../controllers/exercise_library_controller.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../services/ads_service.dart';
import '../theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/ui/pill_tag.dart';
import '../widgets/ui/shimmer_box.dart';
import 'add_exercise_screen.dart';
import 'exercise_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({this.entryReplayKey = 0, super.key});

  final int entryReplayKey;

  static const _imageBaseUrl =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final ExerciseLibraryController _controller;
  late final Box<WorkoutSession> _workoutBox;
  late int _completedWorkoutCount;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final exercisesBox = Hive.box<Exercise>('exercises');
    _controller = ExerciseLibraryController(
      exercises: exercisesBox.values.toList(),
    );
    exercisesBox.listenable().addListener(_handleExercisesChanged);
    _workoutBox = Hive.box<WorkoutSession>('workoutSessions');
    _completedWorkoutCount = _workoutBox.values.length;
    _workoutBox.listenable().addListener(_handleWorkoutsChanged);
  }

  @override
  void dispose() {
    Hive.box<Exercise>('exercises')
        .listenable()
        .removeListener(_handleExercisesChanged);
    _workoutBox.listenable().removeListener(_handleWorkoutsChanged);
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleExercisesChanged() {
    if (!mounted) {
      return;
    }
    final exercises = Hive.box<Exercise>('exercises').values.toList();
    _controller.setExercises(exercises);
  }

  void _handleWorkoutsChanged() {
    final nextCount = _workoutBox.values.length;
    if (mounted && nextCount != _completedWorkoutCount) {
      setState(() => _completedWorkoutCount = nextCount);
    }
  }

  void _openAddExercise() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddExerciseScreen()));
  }

  Widget _buildAddExerciseButton() => FloatingActionButton(
    heroTag: 'library_add_exercise_fab',
    tooltip: 'Add Custom Exercise',
    onPressed: _openAddExercise,
    child: const Icon(Icons.add),
  );

  String _imageUrlFor(Exercise exercise) {
    final path = exercise.imagePaths
        .map((value) => value.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (path.isEmpty ||
        path.startsWith('http://') ||
        path.startsWith('https://')) {
      return path;
    }
    return '${LibraryScreen._imageBaseUrl}${path.replaceAll('\\', '/')}';
  }

  Widget _quickFilters() {
    final muscles = _controller.availableMuscleGroups;
    final equipment = _controller.availableEquipment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (muscles.isNotEmpty)
          SizedBox(
            height: ForgeSpacing.xxxl,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: ForgeSpacing.md),
              children: muscles
                  .map(
                    (muscle) => Padding(
                      padding: const EdgeInsets.only(right: ForgeSpacing.xs),
                      child: FilterChip(
                        label: Text(muscle),
                        selected: _controller.selectedMuscleGroups.contains(
                          muscle,
                        ),
                        onSelected: (_) =>
                            _controller.toggleMuscleGroup(muscle),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        if (equipment.isNotEmpty)
          SizedBox(
            height: ForgeSpacing.xxxl,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: ForgeSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: ForgeSpacing.xs),
                  child: ChoiceChip(
                    label: const Text('Any equipment'),
                    selected: _controller.selectedEquipment == 'Any',
                    onSelected: (_) => _controller.setEquipment('Any'),
                  ),
                ),
                ...equipment.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: ForgeSpacing.xs),
                    child: ChoiceChip(
                      label: Text(item),
                      selected: _controller.selectedEquipment == item,
                      onSelected: (_) => _controller.setEquipment(
                        _controller.selectedEquipment == item ? 'Any' : item,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openFilters() async {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.heroRadius),
        ),
      ),
      builder: (sheetContext) => _ExerciseFilterSheet(controller: _controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final exercises = _controller.filteredExercises;

        return Scaffold(
          appBar: AppBar(title: const Text('Exercise Library')),
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  ForgeSpacing.md,
                  ForgeSpacing.sm,
                  ForgeSpacing.md,
                  ForgeSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _controller.setSearch,
                        decoration: InputDecoration(
                          hintText: 'Search 800+ movements',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    _controller.setSearch('');
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: ForgeSpacing.xs),
                    _FilterButton(
                      count: _controller.activeFilterCount,
                      onPressed: _openFilters,
                    ),
                  ],
                ),
              ),
              _quickFilters(),
              Expanded(
                child: exercises.isEmpty
                    ? _EmptyLibrary(
                        hasExercises: _controller.allExercises.isNotEmpty,
                        onClear: () {
                          _searchController.clear();
                          _controller.clearFilters();
                        },
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          ForgeSpacing.md,
                          ForgeSpacing.xs,
                          ForgeSpacing.md,
                          ForgeSpacing.md +
                              ForgeMotion.navBarHeight +
                              ForgeMotion.navBottomInset +
                              MediaQuery.viewPaddingOf(context).bottom,
                        ),
                        itemCount: exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = exercises[index];
                          final staggerIndex = index > 10 ? 10 : index;
                          return TweenAnimationBuilder<double>(
                            key: ValueKey(
                              'exercise-${exercise.id}-${widget.entryReplayKey}',
                            ),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              final delay = staggerIndex * 0.045;
                              final progress = ((value - delay) / (1 - delay))
                                  .clamp(0.0, 1.0);
                              return Opacity(
                                opacity: progress,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    (1 - progress) * ForgeSpacing.sm,
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: ForgeSpacing.sm,
                              ),
                              child: _ExerciseCard(
                                exercise: exercise,
                                imageUrl: _imageUrlFor(exercise),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ExerciseDetailScreen(
                                        exercise: exercise,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_completedWorkoutCount >= 15)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ForgeSpacing.md,
                      ForgeSpacing.xs,
                      ForgeSpacing.md,
                      ForgeSpacing.xs,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildAddExerciseButton(),
                        ),
                        const SizedBox(height: ForgeSpacing.md),
                        BannerAdWidget(adUnitId: AdsService.exerciseBanner),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: _completedWorkoutCount >= 15
              ? null
              : Padding(
                  padding: const EdgeInsets.only(
                    bottom:
                        ForgeMotion.navBarHeight + ForgeMotion.navBottomInset,
                  ),
                  child: _buildAddExerciseButton(),
                ),
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Filter exercises',
          onPressed: onPressed,
          icon: const Icon(Icons.filter_list),
        ),
        if (count > 0)
          Positioned(
            right: ForgeSpacing.xxs,
            top: ForgeSpacing.xxs,
            child: Container(
              padding: const EdgeInsets.all(ForgeSpacing.xxs),
              constraints: const BoxConstraints(
                minWidth: ForgeSpacing.md,
                minHeight: ForgeSpacing.md,
              ),
              decoration: BoxDecoration(
                color: tokens.accentTeal,
                borderRadius: BorderRadius.circular(tokens.pillRadius),
              ),
              child: Text(
                count.toString(),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _ExerciseFilterSheet extends StatelessWidget {
  const _ExerciseFilterSheet({required this.controller});

  final ExerciseLibraryController controller;

  @override
  Widget build(BuildContext context) {
    final muscleGroups = controller.availableMuscleGroups;
    final equipmentOptions = controller.availableEquipment;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: ForgeSpacing.md,
          right: ForgeSpacing.md,
          top: ForgeSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + ForgeSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter library',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (controller.hasActiveFilters)
                  TextButton(
                    onPressed: () {
                      controller.clearFilters();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
            const SizedBox(height: ForgeSpacing.sm),
            Text(
              'Muscle groups',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: ForgeSpacing.xs),
            Wrap(
              spacing: ForgeSpacing.xs,
              runSpacing: ForgeSpacing.xs,
              children: muscleGroups.map((muscleGroup) {
                final selected = controller.selectedMuscleGroups.contains(
                  muscleGroup,
                );
                return FilterChip(
                  label: Text(muscleGroup),
                  selected: selected,
                  onSelected: (_) => controller.toggleMuscleGroup(muscleGroup),
                );
              }).toList(),
            ),
            const SizedBox(height: ForgeSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: controller.selectedEquipment,
              decoration: const InputDecoration(
                labelText: 'Equipment',
                border: OutlineInputBorder(),
              ),
              items: ['Any', ...equipmentOptions].map((value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                controller.setEquipment(value);
              },
            ),
            const SizedBox(height: ForgeSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: controller.selectedLevel,
              decoration: const InputDecoration(
                labelText: 'Level',
                border: OutlineInputBorder(),
              ),
              items: ExerciseLibraryController.levelOptions.map((level) {
                return DropdownMenuItem<String>(
                  value: level,
                  child: Text(level),
                );
              }).toList(),
              onChanged: (value) {
                controller.setLevel(value);
              },
            ),
            const SizedBox(height: ForgeSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Apply filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.imageUrl,
    required this.onTap,
  });

  final Exercise exercise;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final equipment = exercise.equipment?.trim();
    Widget image = imageUrl.isEmpty
        ? _DemoFallback(color: tokens.surfaceVariant)
        : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, _) => const ShimmerBox(),
            errorWidget: (context, error, stackTrace) {
              debugPrint(
                'Exercise thumbnail failed: url=$imageUrl error=$error\n'
                'stackTrace=$stackTrace',
              );
              return _DemoFallback(color: tokens.surfaceVariant);
            },
          );
    if (imageUrl.isNotEmpty) {
      image = Hero(tag: 'exercise-demo-${exercise.id}', child: image);
    }

    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(tokens.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(ForgeSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.cardRadius),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.controlRadius),
                child: SizedBox(
                  width: ForgeSpacing.xxxl,
                  height: ForgeSpacing.xxxl,
                  child: image,
                ),
              ),
              const SizedBox(width: ForgeSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: tokens.textPrimary),
                    ),
                    const SizedBox(height: ForgeSpacing.xs),
                    Wrap(
                      spacing: ForgeSpacing.xs,
                      runSpacing: ForgeSpacing.xxs,
                      children: [
                        PillTag(
                          label: exercise.muscleGroup.isEmpty
                              ? 'General'
                              : exercise.muscleGroup,
                          variant: PillTagVariant.accent,
                        ),
                        if (equipment != null && equipment.isNotEmpty)
                          PillTag(
                            label: equipment,
                            variant: PillTagVariant.neutral,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ForgeSpacing.xxs),
              Icon(Icons.chevron_right, color: tokens.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoFallback extends StatelessWidget {
  const _DemoFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color,
    child: Center(
      child: Icon(
        Icons.fitness_center_rounded,
        color: Theme.of(context).extension<ForgeTokens>()!.textMuted,
      ),
    ),
  );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.hasExercises, required this.onClear});

  final bool hasExercises;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ForgeSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasExercises ? Icons.search_off_rounded : Icons.fitness_center,
              size: ForgeSpacing.xxxl,
              color: tokens.textMuted,
            ),
            const SizedBox(height: ForgeSpacing.sm),
            Text(
              hasExercises
                  ? 'No matches. Try another search or filter.'
                  : 'Your exercise library is empty.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: tokens.textSecondary),
            ),
            if (hasExercises) ...[
              const SizedBox(height: ForgeSpacing.sm),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
