// Predefined bill types
const List<String> predefinedBillTypes = [
  'Electricity',
  'Water',
  'Internet',
  'Home Credit',
  'Phone',
  'Gas',
  'Insurance',
  'Rent',
  'Subscription',
  'Tuition',
  'Medical',
];

class Bill {
  final String id;
  final String type; // Name/Type
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final String frequency; // Everyday, Weekly, Monthly, etc.

  Bill({
    required this.id,
    required this.type,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    this.frequency = 'Monthly',
  });

  Bill copyWith({
    String? id,
    String? type,
    double? amount,
    DateTime? dueDate,
    bool? isPaid,
    String? frequency,
  }) {
    return Bill(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      frequency: frequency ?? this.frequency,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amount': amount,
    'dueDate': dueDate.toIso8601String(),
    'isPaid': isPaid,
    'frequency': frequency,
  };

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
    id: json['id'],
    type: json['type'],
    amount: (json['amount'] as num).toDouble(),
    dueDate: DateTime.parse(json['dueDate']),
    isPaid: json['isPaid'] ?? false,
    frequency: json['frequency'] ?? 'Monthly',
  );
}
