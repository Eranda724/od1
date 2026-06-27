class SessionItem {
  final String exerciseId;
  final String exerciseName;
  final String? description;
  final int streak;
  final int lifetimeTotal;
  final int defaultReps;
  final int defaultTimer;
  final String unit;

  SessionItem({
    required this.exerciseId,
    required this.exerciseName,
    this.description,
    required this.streak,
    required this.lifetimeTotal,
    required this.defaultReps,
    required this.defaultTimer,
    required this.unit,
  });
}
