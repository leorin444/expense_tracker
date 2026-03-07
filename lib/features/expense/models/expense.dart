import 'package:hive/hive.dart';

part 'expense.g.dart';

@HiveType(typeId: 0)
class Expense extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String category;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  int timestamp; // millisecondsSinceEpoch, used for sync conflict resolution

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Convert Expense to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'timestamp': timestamp,
    };
  }

  /// Create Expense from Firestore Map
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      timestamp:
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
