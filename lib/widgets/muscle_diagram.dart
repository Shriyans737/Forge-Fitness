import 'package:flutter/material.dart';
import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';

import '../data/muscle_name_mapping.dart';
import '../models/exercise.dart';

class MuscleDiagram extends StatelessWidget {
  const MuscleDiagram({
    required this.exercise,
    super.key,
  });

  final Exercise exercise;

  Set<Muscle> get _targetMuscles => resolveExerciseMuscles([
    ...exercise.primaryMuscles,
    ...exercise.secondaryMuscles,
  ]);

  bool _isFrontMuscle(Muscle muscle) {
    switch (muscle) {
      case Muscle.trapsLeft:
      case Muscle.trapsRight:
      case Muscle.deltsLeft:
      case Muscle.deltsRight:
      case Muscle.chestLeft:
      case Muscle.chestRight:
      case Muscle.abs:
      case Muscle.tricepsLeft:
      case Muscle.tricepsRight:
      case Muscle.bicepsLeft:
      case Muscle.bicepsRight:
      case Muscle.forearmsLeft:
      case Muscle.forearmsRight:
      case Muscle.quadsLeft:
      case Muscle.quadsRight:
      case Muscle.calvesLeft:
      case Muscle.calvesRight:
        return true;
      case Muscle.latsBackLeft:
      case Muscle.latsBackRight:
      case Muscle.lowerLatsBackLeft:
      case Muscle.lowerLatsBackRight:
      case Muscle.glutesLeft:
      case Muscle.glutesRight:
      case Muscle.hamstringsLeft:
      case Muscle.hamstringsRight:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetMuscles = _targetMuscles;
    if (targetMuscles.isEmpty) {
      return const SizedBox.shrink();
    }

    final unsupportedMuscles = getUnsupportedMuscleNames([
      ...exercise.primaryMuscles,
      ...exercise.secondaryMuscles,
    ]);

    final frontMuscles = targetMuscles.where(_isFrontMuscle).toSet();
    final backMuscles = targetMuscles.where((muscle) => !_isFrontMuscle(muscle)).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target muscles',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 12) / 2;
              return Row(
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _BodySideView(
                      title: 'Front',
                      isFront: true,
                      selectedMuscles: frontMuscles,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: itemWidth,
                    child: _BodySideView(
                      title: 'Back',
                      isFront: false,
                      selectedMuscles: backMuscles,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (unsupportedMuscles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Unmapped names: ${unsupportedMuscles.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _BodySideView extends StatelessWidget {
  const _BodySideView({
    required this.title,
    required this.isFront,
    required this.selectedMuscles,
  });

  final String title;
  final bool isFront;
  final Set<Muscle> selectedMuscles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: InteractiveBodySvg(
            isFront: isFront,
            selectedMuscles: selectedMuscles,
            enableSelection: false,
            highlightColor: isFront
                ? const Color(0xFF1FA39A)
                : const Color(0xFF2D6CDF),
            disabledColor: const Color(0xFFCAD6D9),
            selectedStrokeWidth: 2.5,
            unselectedStrokeWidth: 1.2,
            width: double.infinity,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
