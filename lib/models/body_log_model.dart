import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'body_log_model.g.dart';

@HiveType(typeId: 5)
class BodyLog extends HiveObject {
  BodyLog({
    String? id,
    required this.date,
    this.weightKg,
    this.measurements,
    this.notes,
  }) : id = id ?? const Uuid().v4();

  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  double? weightKg;

  @HiveField(3)
  Map<String, double>? measurements;

  @HiveField(4)
  String? notes;
}
