class ExerciseItem {
  final String id;
  final String name;
  final String icon;
  final String unit;

  ExerciseItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.unit,
  });

  factory ExerciseItem.fromMap(String id, Map<String, dynamic> data) {
    return ExerciseItem(
      id: id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '💪',
      unit: data['unit'] ?? 'reps',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'icon': icon,
        'unit': unit,
      };
}