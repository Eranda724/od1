import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../app_settings.dart';

class StreakCalendarView extends StatefulWidget {
  final List<String> activeDates;
  final List<String> frozenDates;

  const StreakCalendarView({
    super.key,
    required this.activeDates,
    required this.frozenDates,
  });

  @override
  State<StreakCalendarView> createState() => _StreakCalendarViewState();
}

class _StreakCalendarViewState extends State<StreakCalendarView> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildDayCell(DateTime? date) {
    if (date == null) {
      return const SizedBox(height: 48); // Empty cell for padding days
    }

    final key = _formatDateKey(date);
    final isActive = widget.activeDates.contains(key);
    final isFrozen = widget.frozenDates.contains(key);
    
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isFuture = date.isAfter(now) && !isToday;

    Color bgColor = Colors.white.withValues(alpha: 0.05);
    Color borderColor = Colors.transparent;
    Widget? icon;

    if (isActive) {
      bgColor = PCColors.yellow.withValues(alpha: 0.2);
      icon = const Text('🔥', style: TextStyle(fontSize: 14));
      borderColor = PCColors.yellow.withValues(alpha: 0.5);
    } else if (isFrozen) {
      bgColor = Colors.blue.withValues(alpha: 0.2);
      icon = const Text('❄️', style: TextStyle(fontSize: 14));
      borderColor = Colors.blueAccent.withValues(alpha: 0.5);
    } else if (isToday) {
      borderColor = PCColors.yellow;
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isToday && !isActive && !isFrozen ? 2 : 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (icon == null)
            Text(
              '${date.day}',
              style: TextStyle(
                color: isFuture ? Colors.white38 : (isToday ? PCColors.yellow : Colors.white70),
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          if (icon != null)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(height: 2),
                Text(
                  '${date.day}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine days in month
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    
    // Determine weekday of 1st day (1 = Monday, 7 = Sunday)
    final firstDayWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;

    // Create the grid list
    final List<DateTime?> gridDays = [];
    
    // Add empty padding for days before the 1st
    for (int i = 1; i < firstDayWeekday; i++) {
      gridDays.add(null);
    }
    
    // Add all days of the month
    for (int i = 1; i <= daysInMonth; i++) {
      gridDays.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }

    final monthName = DateFormat.yMMMM(context.locale.languageCode).format(_currentMonth);
    // short day names localization keys
    // In many apps we just hardcode or use shortWeekdays from DateFormat.
    // easy_localization might not have a direct short weekday getter unless defined in strings, 
    // but DateFormat provides localized strings!
    final weekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    return Container(
      decoration: const BoxDecoration(
        color: PCColors.brownDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header: < Month Year >
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _previousMonth,
                ),
                Text(
                  monthName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PCColors.yellow,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Weekday Headers
            Row(
              children: weekDays.map((dayKey) {
                return Expanded(
                  child: Center(
                    child: Text(
                      dayKey.tr().toUpperCase(), 
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 8),
            
            // Calendar Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gridDays.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                return _buildDayCell(gridDays[index]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
