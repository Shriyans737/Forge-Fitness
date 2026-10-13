import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';

final Map<String, Set<Muscle>> _muscleNameMap = {
  'abdominals': {Muscle.abs},
  'abs': {Muscle.abs},
  'biceps': {Muscle.bicepsLeft, Muscle.bicepsRight},
  'triceps': {Muscle.tricepsLeft, Muscle.tricepsRight},
  'forearms': {Muscle.forearmsLeft, Muscle.forearmsRight},
  'quadriceps': {Muscle.quadsLeft, Muscle.quadsRight},
  'quads': {Muscle.quadsLeft, Muscle.quadsRight},
  'hamstrings': {Muscle.hamstringsLeft, Muscle.hamstringsRight},
  'calves': {Muscle.calvesLeft, Muscle.calvesRight},
  'glutes': {Muscle.glutesLeft, Muscle.glutesRight},
  'chest': {Muscle.chestLeft, Muscle.chestRight},
  'lats': {Muscle.latsBackLeft, Muscle.latsBackRight},
  'middle back': {Muscle.latsBackLeft, Muscle.latsBackRight},
  'lower back': {Muscle.lowerLatsBackLeft, Muscle.lowerLatsBackRight},
  'traps': {Muscle.trapsLeft, Muscle.trapsRight},
  'trap': {Muscle.trapsLeft, Muscle.trapsRight},
  'shoulders': {Muscle.deltsLeft, Muscle.deltsRight},
  'shoulder': {Muscle.deltsLeft, Muscle.deltsRight},
  'delts': {Muscle.deltsLeft, Muscle.deltsRight},
  'adductors': {Muscle.quadsLeft, Muscle.quadsRight},
};

Set<Muscle> resolveExerciseMuscles(List<String> muscleNames) {
  final resolved = <Muscle>{};

  for (final rawName in muscleNames) {
    final normalized = _normalizeMuscleName(rawName);
    if (normalized.isEmpty) {
      continue;
    }

    final mapped = _muscleNameMap[normalized];
    if (mapped != null) {
      resolved.addAll(mapped);
    }
  }

  return resolved;
}

Set<String> getUnsupportedMuscleNames(List<String> muscleNames) {
  final unsupported = <String>{};

  for (final rawName in muscleNames) {
    final normalized = _normalizeMuscleName(rawName);
    if (normalized.isEmpty) {
      continue;
    }

    if (!_muscleNameMap.containsKey(normalized)) {
      unsupported.add(rawName.trim());
    }
  }

  return unsupported;
}

String _normalizeMuscleName(String rawName) {
  final value = rawName.trim();
  if (value.isEmpty) {
    return '';
  }

  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
