import 'exercise_item.dart';

class SessionItem {
  final String exerciseId;
  final String exerciseName;
  final String? description;
  final int streak;
  final int monthlyTotal;
  final int defaultReps;
  final int defaultTimer;
  final String unit;
  final ExerciseItem? exerciseDef;

  SessionItem({
    required this.exerciseId,
    required this.exerciseName,
    this.description,
    required this.streak,
    required this.monthlyTotal,
    required this.defaultReps,
    required this.defaultTimer,
    required this.unit,
    this.exerciseDef,
  });
}
