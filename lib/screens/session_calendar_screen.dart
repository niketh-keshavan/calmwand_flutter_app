import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../models/session_model.dart';
import '../utils/app_theme.dart';
import 'session_detail_screen.dart';

/// Full calendar view showing session history month by month
class SessionCalendarScreen extends StatefulWidget {
  const SessionCalendarScreen({super.key});

  @override
  State<SessionCalendarScreen> createState() => _SessionCalendarScreenState();
}

class _SessionCalendarScreenState extends State<SessionCalendarScreen> {
  late DateTime _currentMonth;
  
  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    if (nextMonth.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() {
        _currentMonth = nextMonth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final sessions = sessionProvider.sessionArray;
    
    // Create a set of dates that have sessions
    final sessionDates = <DateTime>{};
    final sessionsByDate = <DateTime, List<SessionModel>>{};
    
    for (final session in sessions) {
      final date = DateTime(
        session.timestamp.year,
        session.timestamp.month,
        session.timestamp.day,
      );
      sessionDates.add(date);
      sessionsByDate.putIfAbsent(date, () => []).add(session);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Calendar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade900,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Column(
          children: [
            // Month navigation
            _buildMonthNavigator(),
            
            // Calendar grid
            Expanded(
              child: _buildCalendarGrid(sessionDates, sessionsByDate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigator() {
    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year && 
                           _currentMonth.month == now.month;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left),
            color: Colors.blue.shade700,
          ),
          Text(
            _formatMonth(_currentMonth),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          IconButton(
            onPressed: isCurrentMonth ? null : _nextMonth,
            icon: const Icon(Icons.chevron_right),
            color: isCurrentMonth ? Colors.grey.shade400 : Colors.blue.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(
    Set<DateTime> sessionDates,
    Map<DateTime, List<SessionModel>> sessionsByDate,
  ) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    
    // Get the weekday of the first day (1 = Monday, 7 = Sunday)
    // Adjust for Sunday start (0 = Sunday)
    final firstWeekday = (firstDayOfMonth.weekday % 7);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        children: [
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          
          // Calendar days
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday) {
                  return const SizedBox(); // Empty cells before first day
                }
                
                final day = index - firstWeekday + 1;
                final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                final hasSession = sessionDates.contains(date);
                final isToday = _isToday(date);
                final sessionsOnDay = sessionsByDate[date] ?? [];
                
                return GestureDetector(
                  onTap: hasSession ? () => _showSessionsForDay(date, sessionsOnDay) : null,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: hasSession 
                          ? Colors.green.shade100 
                          : (isToday ? Colors.blue.shade50 : Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday 
                          ? Border.all(color: Colors.blue.shade400, width: 2)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasSession || isToday ? FontWeight.bold : FontWeight.normal,
                            color: hasSession 
                                ? Colors.green.shade800 
                                : (isToday ? Colors.blue.shade700 : Colors.black87),
                          ),
                        ),
                        if (hasSession)
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        if (sessionsOnDay.length > 1)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${sessionsOnDay.length}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Legend
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.green.shade100, 'Session completed'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.blue.shade50, 'Today', hasBorder: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: hasBorder ? Border.all(color: Colors.blue.shade400, width: 2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  void _showSessionsForDay(DateTime date, List<SessionModel> sessions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sessions on ${_formatDate(date)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.check, color: Colors.green.shade700),
                    ),
                    title: Text('Session #${session.sessionNumber}'),
                    subtitle: Text('${session.duration ~/ 60} min • Score: ${session.score?.toStringAsFixed(0) ?? 'N/A'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SessionDetailScreen(session: session),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatMonth(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }
}
