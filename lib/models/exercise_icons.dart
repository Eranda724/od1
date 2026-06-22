import 'package:flutter/material.dart';

class ExerciseIconItem {
  final String id;
  final String label;
  final IconData icon;

  const ExerciseIconItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

const List<ExerciseIconItem> exerciseIcons = [
  ExerciseIconItem(id: 'default', label: 'Default', icon: Icons.fitness_center),
  ExerciseIconItem(id: 'run', label: 'Running', icon: Icons.directions_run),
  ExerciseIconItem(id: 'walk', label: 'Walking', icon: Icons.directions_walk),
  ExerciseIconItem(id: 'cycle', label: 'Cycling', icon: Icons.directions_bike),
  ExerciseIconItem(id: 'gym', label: 'Gym', icon: Icons.fitness_center),
  ExerciseIconItem(id: 'yoga', label: 'Yoga', icon: Icons.self_improvement),
  ExerciseIconItem(id: 'swim', label: 'Swimming', icon: Icons.pool),
  ExerciseIconItem(id: 'football', label: 'Football', icon: Icons.sports_soccer),
  ExerciseIconItem(id: 'basketball', label: 'Basketball', icon: Icons.sports_basketball),
  ExerciseIconItem(id: 'boxing', label: 'Boxing', icon: Icons.sports_mma),
];

IconData getExerciseIcon(String id) {
  return exerciseIcons.firstWhere(
    (e) => e.id == id,
    orElse: () => exerciseIcons.first,
  ).icon;
}

/// Returns true if the stored icon value is an emoji (not a Material Icon ID).
bool isEmojiIcon(String value) {
  return !exerciseIcons.any((e) => e.id == value);
}

/// Smart display widget — renders emoji as Text or Material Icon as Icon.
Widget buildExerciseIconWidget(String value, {double size = 28, Color? iconColor}) {
  if (isEmojiIcon(value)) {
    return Text(value, style: TextStyle(fontSize: size));
  }
  return Icon(getExerciseIcon(value), size: size, color: iconColor ?? Colors.amber.shade900);
}

const List<String> exerciseEmojis = [
  '💪', // Default
  '🏃', '🚶', '🚴', '🏊', '🧘', '🤸', '⛹️', '⚽', '🏀',
  '🏈', '🎾', '🏐', '🥊', '🥋', '🤼', '🏋️', '🧗', '🔥', '🏆',
  '⏱️', '🥇', '⚡', '😅', '💯', '❤️', '🌟', '🎯', '🏋️‍♀️', '🏋️‍♂️',
  '🎽', '🎿', '🏂', '🏄', '🚣', '🤺', '🤾', '🏌️',
];