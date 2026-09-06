class Expense {
  String id;
  String title;
  double amount;
  String category;
  DateTime date;
  int timestamp; // millisecondsSinceEpoch, used for sync conflict resolution
  String userId;

  Expense({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Expense copyWith({
    String? title,
    double? amount,
    String? category,
    DateTime? date,
  }) {
    return Expense(
      id: id,
      userId: userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
    );
  }

  /// Convert Expense to JSON Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'timestamp': timestamp,
    };
  }

  /// Create Expense from JSON Map
  factory Expense.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['date'] ?? map['expenseDate'];
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    // Prefer clientExpenseId so that server-returned expenses match the local Hive key
    final resolvedId = (map['clientExpenseId'] ?? map['id'] ?? map['serverId'])?.toString() ?? '';

    return Expense(
      id: resolvedId,
      userId: (map['userId'] ?? '').toString(),
      title: (map['title'] ?? map['note'] ?? map['description'] ?? 'Expense').toString(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: (map['category'] ?? map['categoryName'] ?? 'Other').toString(),
      date: parsedDate,
      timestamp: map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
