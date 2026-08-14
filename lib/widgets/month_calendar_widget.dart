import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../app_settings.dart';

class MonthCalendarWidget extends StatefulWidget {
  final List<String> activeDates;
  final List<String> frozenDates;
  final String? userStartDate; // first day the user ever logged an exercise
  final int freezesAvailable;
  final int streak;

  const MonthCalendarWidget({
    super.key,
    required this.activeDates,
    required this.frozenDates,
    this.userStartDate,
    required this.freezesAvailable,
    required this.streak,
  });

  @override
  State<MonthCalendarWidget> createState() => _MonthCalendarWidgetState();
}

class _MonthCalendarWidgetState extends State<MonthCalendarWidget> {
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
    final now = DateTime.now();
    if (_currentMonth.year == now.year && _currentMonth.month == now.month) {
      return; // Do not go to future months
    }
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildDayCell(DateTime? date, bool isNextActive, bool isPrevActive) {
    if (date == null) return const SizedBox();

    final key = _formatDateKey(date);
    final isActive = widget.activeDates.contains(key);
    bool isFrozen = widget.frozenDates.contains(key);

    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final isFuture = date.isAfter(now) && !isToday;

    // Days before the user started the app are neutral — not "missed"
    final bool isBeforeStart =
        widget.userStartDate != null &&
        key.compareTo(widget.userStartDate!) < 0;

    // ── Future or pre-start day ──
    if (isFuture || isBeforeStart) {
      return Container(
        margin: const EdgeInsets.all(2),
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, 1),
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: isFuture
                    ? Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.2)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    // ── Today ──
    if (isToday) {
      return Container(
        margin: const EdgeInsets.all(2),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isActive)
                Transform.translate(
                  offset: const Offset(0, -4),
                  child: Image.asset(
                    'assets/images/fire_3d.png',
                    width: 28,
                    height: 28,
                  ),
                ),
              if (isFrozen)
                Transform.translate(
                  offset: const Offset(0, 5),
                  child: OverflowBox(
                    maxWidth: 60,
                    maxHeight: 60,
                    child: Image.asset(
                      'assets/images/ice_cube_3d.png',
                      width: 36,
                      height: 46,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              Transform.translate(
                offset: const Offset(0, 1),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: (isActive || isFrozen)
                        ? Colors.black
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Active day (🔥 as background) ──
    if (isActive) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, -4), // Move fire emoji slightly up
              child: Image.asset(
                'assets/images/fire_3d.png',
                width: 28,
                height: 28,
              ),
            ),
            // Date number on top (shifted slightly down towards the fire's base)
            Transform.translate(
              offset: const Offset(0, 1),
              child: Text(
                '${date.day}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize:
                      14, // Increased size to make the w900 weight look bolder
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Frozen day (🧊 as background) ──
    if (isFrozen) {
      return Container(
        margin: const EdgeInsets.all(2),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, 5), // Center the ice cube emoji
              child: OverflowBox(
                maxWidth: 60,
                maxHeight: 60,
                child: Image.asset(
                  'assets/images/ice_cube_3d.png',
                  width: 36,
                  height: 46,
                  fit: BoxFit.fill,
                ),
              ), // Same size as fire, full opacity
            ),
            Transform.translate(
              offset: const Offset(0, 1),
              child: Text(
                '${date.day}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Past missed day (Broken streak, no freeze available) ──
    return Container(
      margin: const EdgeInsets.all(2),
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, 1),
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth =
        _currentMonth.year == now.year && _currentMonth.month == now.month;

    // Create the grid list
    final List<DateTime?> gridDays = [];

    // Determine days in month
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;

    // Determine weekday of 1st day (1 = Monday, 7 = Sunday)
    final firstDayWeekday = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    ).weekday;

    // Add empty padding for days before the 1st
    for (int i = 1; i < firstDayWeekday; i++) {
      gridDays.add(null);
    }

    // Add all days of the month
    for (int i = 1; i <= daysInMonth; i++) {
      gridDays.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }

    // The month name always shows the current month
    final displayMonth = _currentMonth;
    final monthName = DateFormat.yMMMM(
      context.locale.languageCode,
    ).format(displayMonth);

    // Using simple letters for weekday headers as requested
    final weekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: < Month Year >
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: _previousMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              Text(
                monthName,
                style: const TextStyle(
                  fontSize: 22, // Increased font size for expanded view
                  fontWeight: FontWeight.bold,
                  color: PCColors.yellow,
                ),
              ),

              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: isCurrentMonth
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.2)
                      : Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: isCurrentMonth ? null : _nextMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Weekday Headers
          Row(
            children: weekDays.map((dayKey) {
              return Expanded(
                child: Center(
                  child: Text(
                    dayKey.tr().toUpperCase().substring(0, 1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 4),

          // Grid
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: gridDays.length,
              itemBuilder: (context, index) {
                final date = gridDays[index];

                // Determine if next/prev days are active for styling the streak line
                bool isNextActive = false;
                bool isPrevActive = false;

                if (date != null) {
                  final dateKey = _formatDateKey(date);
                  if (widget.activeDates.contains(dateKey)) {
                    // Check prev day
                    final prevDate = date.subtract(const Duration(days: 1));
                    final prevKey = _formatDateKey(prevDate);
                    isPrevActive = widget.activeDates.contains(prevKey);

                    // Check next day
                    final nextDate = date.add(const Duration(days: 1));
                    final nextKey = _formatDateKey(nextDate);
                    isNextActive = widget.activeDates.contains(nextKey);
                  }
                }

                return _buildDayCell(date, isNextActive, isPrevActive);
              },
            ),
          ),
        ],
      ),
    );
  }
}
