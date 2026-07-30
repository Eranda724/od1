import 'package:flutter/material.dart';
import '../app_settings.dart';

class WeekStreakRow extends StatelessWidget {
  final List<String> activeDates;
  final List<String> frozenDates;
  final DateTime today;

  const WeekStreakRow({
    super.key,
    required this.activeDates,
    required this.frozenDates,
    required this.today,
  });

  String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    // Rolling 7-day window ending on today
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days
          .map((date) => Expanded(child: _buildDayColumn(context, date)))
          .toList(),
    );
  }

  Widget _buildDayColumn(BuildContext context, DateTime date) {
    final key = _dateKey(date);
    final isActive = activeDates.contains(key);
    final isFrozen = frozenDates.contains(key);
    final isToday = _isSameDay(date, today);

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayLabel = dayNames[date.weekday - 1];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(isActive: isActive, isFrozen: isFrozen),
        const SizedBox(height: 8),
        Text(
          dayLabel,
          style: TextStyle(
            color: isToday ? PCColors.yellow : Colors.white54,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildIcon({required bool isActive, required bool isFrozen}) {
    const circleSize = 38.0;
    const boxHeight = 48.0; // Uniform vertical bounding box to align day labels

    if (isActive) {
      return SizedBox(
        width: circleSize, // Keep width tight to prevent row overflow
        height: boxHeight,
        child: OverflowBox(
          maxWidth: 100, // Allow horizontal visual bleed
          maxHeight: 100, // Allow vertical visual bleed
          child: Center(
            child: Image.asset(
              'assets/images/fire_3d.png',
              width: 30,
              height: 30,
            ),
          ),
        ),
      );
    }

    if (isFrozen) {
      return SizedBox(
        width: circleSize,
        height: boxHeight,
        child: OverflowBox(
          maxWidth: 100, // Allow horizontal visual bleed
          maxHeight: 100, // Allow vertical visual bleed
          child: Center(
            child: Transform.translate(
              offset: const Offset(0, 4), // Shift down slightly
              child: Image.asset(
                'assets/images/ice_cube_3d.png',
                height: 66,
                width: 66,
              ),
            ),
          ),
        ),
      );
    }

    // No data / not yet reached
    return SizedBox(
      width: circleSize,
      height: boxHeight,
      child: Center(
        child: Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }
}
