import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../app_settings.dart';

class MonthCalendarWidget extends StatefulWidget {
  final List<String> activeDates;
  final List<String> frozenDates;

  const MonthCalendarWidget({
    super.key,
    required this.activeDates,
    required this.frozenDates,
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
    if (date == null) {
      return const SizedBox(); // Empty cell for padding days
    }

    final key = _formatDateKey(date);
    final isActive = widget.activeDates.contains(key);
    final isFrozen = widget.frozenDates.contains(key);
    
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isFuture = date.isAfter(now) && !isToday;

    Widget cellContent;
    BoxDecoration? innerDecoration;
    BoxDecoration? outerDecoration;

    if (isToday && !isActive) {
      // Today (not yet exercised) -> Blue circle with potato icon 🥔
      cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1),
          ),
          const SizedBox(height: 2),
          const Text('🥔', style: TextStyle(fontSize: 10, height: 1)),
        ],
      );
      innerDecoration = const BoxDecoration(
        color: Colors.blueAccent,
        shape: BoxShape.circle,
      );
    } else if (isToday && isActive) {
      // Today (exercised) -> Bright yellow circle with flame inside the continuous streak pill
      cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: const TextStyle(color: PCColors.brownDark, fontWeight: FontWeight.bold, fontSize: 13, height: 1),
          ),
          const SizedBox(height: 2),
          const Text('🔥', style: TextStyle(fontSize: 10, height: 1)),
        ],
      );
      innerDecoration = const BoxDecoration(
        color: PCColors.yellow,
        shape: BoxShape.circle,
      );
      
      const borderSide = BorderSide(color: PCColors.yellow, width: 2);
      outerDecoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: borderSide,
          bottom: borderSide,
          left: isPrevActive ? BorderSide.none : borderSide,
          right: isNextActive ? BorderSide.none : borderSide,
        ),
        borderRadius: BorderRadius.horizontal(
          left: isPrevActive ? Radius.zero : const Radius.circular(20),
          right: isNextActive ? Radius.zero : const Radius.circular(20),
        ),
      );
    } else if (isActive) {
      // Past active days -> Continuous gradient bar with yellow border
      cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1),
          ),
          const SizedBox(height: 2),
          const Text('🔥', style: TextStyle(fontSize: 10, height: 1)),
        ],
      );
      
      const borderSide = BorderSide(color: PCColors.yellow, width: 2);
      outerDecoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          top: borderSide,
          bottom: borderSide,
          left: isPrevActive ? BorderSide.none : borderSide,
          right: isNextActive ? BorderSide.none : borderSide,
        ),
        borderRadius: BorderRadius.horizontal(
          left: isPrevActive ? Radius.zero : const Radius.circular(20),
          right: isNextActive ? Radius.zero : const Radius.circular(20),
        ),
      );
      innerDecoration = null;
    } else if (isFrozen) {
      // Freeze used day -> Light blue tint with snowflake
      cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1),
          ),
          const SizedBox(height: 2),
          const Text('❄️', style: TextStyle(fontSize: 10, height: 1)),
        ],
      );
      innerDecoration = BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 1),
      );
    } else {
      // Past missed or Future days
      cellContent = Text(
        '${date.day}',
        style: TextStyle(
          color: isFuture ? Colors.white38 : Colors.white60,
          fontWeight: FontWeight.normal,
        ),
      );
    }

    return Container(
      decoration: outerDecoration,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: innerDecoration,
          alignment: Alignment.center,
          child: cellContent,
        ),
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
    
    // Using simple letters for weekday headers as requested (L M M J V S D style based on locale, or standard localized short weekday)
    final weekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year && _currentMonth.month == now.month;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: < Month Year >
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _previousMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                monthName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: PCColors.yellow,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right, 
                  color: isCurrentMonth ? Colors.white24 : Colors.white,
                ),
                onPressed: isCurrentMonth ? null : _nextMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                    dayKey.tr().toUpperCase().substring(0, 1), 
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
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
            ),
            itemBuilder: (context, index) {
              final date = gridDays[index];
              if (date == null) {
                return _buildDayCell(null, false, false);
              }

              // Check if previous/next day in the same row (week) is active
              // for continuous highlighting
              bool isPrevActive = false;
              bool isNextActive = false;

              if (index % 7 != 0 && index > 0 && gridDays[index - 1] != null) {
                final prevDate = gridDays[index - 1]!;
                isPrevActive = widget.activeDates.contains(_formatDateKey(prevDate));
              }
              
              if (index % 7 != 6 && index < gridDays.length - 1 && gridDays[index + 1] != null) {
                final nextDate = gridDays[index + 1]!;
                isNextActive = widget.activeDates.contains(_formatDateKey(nextDate));
              }

              return _buildDayCell(date, isNextActive, isPrevActive);
            },
          ),
        ],
      ),
    );
  }
}
