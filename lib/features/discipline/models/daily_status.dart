class DailyStatus {
  final DateTime date;
  final bool completed;

  DailyStatus({
    required this.date,
    required this.completed,
  });

  DailyStatus copyWith({bool? completed}) {
    return DailyStatus(
      date: date,
      completed: completed ?? this.completed,
    );
  }
}