import 'package:flutter/material.dart';
import '../models/exercise_item.dart';
import '../models/exercise_icons.dart';

class ExerciseThumbnail extends StatelessWidget {
  final ExerciseItem def;
  final double width;
  final double height;
  final double iconSize;
  final BoxFit fit;

  const ExerciseThumbnail({
    super.key,
    required this.def,
    required this.width,
    required this.height,
    this.iconSize = 32,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white12
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: buildExerciseVisual(
          def,
          size: iconSize,
          width: width,
          height: height,
          fit: fit,
        ),
      ),
    );
  }
}
