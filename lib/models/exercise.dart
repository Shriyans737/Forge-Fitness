import 'package:hive/hive.dart';

part 'exercise.g.dart';

@HiveType(typeId: 0)
class Exercise extends HiveObject {
  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.description,
    this.videoUrl,
    this.isCustom = false,
    this.videoId,
    this.imagePaths = const [],
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.equipment,
    this.level,
    this.instructions = const [],
    this.targetRepMin = 8,
    this.targetRepMax = 12,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String muscleGroup;

  @HiveField(3)
  String description;

  @HiveField(4)
  String? videoUrl;

  @HiveField(5, defaultValue: false)
  bool isCustom;

  @HiveField(6)
  String? videoId;

  @HiveField(7, defaultValue: [])
  List<String> imagePaths;

  @HiveField(8, defaultValue: [])
  List<String> primaryMuscles;

  @HiveField(9, defaultValue: [])
  List<String> secondaryMuscles;

  @HiveField(10)
  String? equipment;

  @HiveField(11)
  String? level;

  @HiveField(12, defaultValue: [])
  List<String> instructions;

  @HiveField(13, defaultValue: 8)
  int targetRepMin;

  @HiveField(14, defaultValue: 12)
  int targetRepMax;
}
