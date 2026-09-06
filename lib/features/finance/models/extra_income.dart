class ExtraIncome {
  final String source;
  final double amount;
  final DateTime date;
  final String userId;

  ExtraIncome({
    required this.source,
    required this.amount,
    required this.date,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'amount': amount,
      'date': date.toIso8601String(),
      'userId': userId,
    };
  }

  factory ExtraIncome.fromMap(Map<String, dynamic> map) {
    return ExtraIncome(
      source: map['source'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      userId: map['userId'] as String,
    );
  }
}
