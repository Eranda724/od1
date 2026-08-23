import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../app_settings.dart';

class WeekStreakRow extends StatelessWidget {
  final List<String> activeDates;
  final List<String> frozenDates;
  final DateTime today;
  final int freezesAvailable;
  final int streak;

  const WeekStreakRow({
    super.key,
    required this.activeDates,
    required this.frozenDates,
    required this.today,
    required this.freezesAvailable,
    required this.streak,
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
    final isToday = _isSameDay(date, today);
    bool isFrozen = frozenDates.contains(key);

    final dayNames = [
      'mon'.tr(),
      'tue'.tr(),
      'wed'.tr(),
      'thu'.tr(),
      'fri'.tr(),
      'sat'.tr(),
      'sun'.tr(),
    ];
    final dayLabel = dayNames[date.weekday - 1];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(context, isActive: isActive, isFrozen: isFrozen),
        const SizedBox(height: 2),
        Text(
          dayLabel,
          style: TextStyle(
            color: isToday ? PCColors.yellow : context.textSecondary,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(
    BuildContext context, {
    required bool isActive,
    required bool isFrozen,
  }) {
    const circleSize = 28.0;
    const boxHeight = 36.0; // Uniform vertical bounding box to align day labels
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              width: 28,
              height: 28,
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
              offset: const Offset(0, 5), // Shift down slightly
              child: Image.asset(
                'assets/images/ice_cube_3d.png',
                height: 46,
                width: 36,
                fit: BoxFit.fill,
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
    );
  }
}
