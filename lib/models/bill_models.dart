// Predefined expense types
const List<String> predefinedExpenseTypes = [
  'Car Loan',
  'Electricity',
  'Water',
  'Internet',
  'Home Credit',
  'Skyro',
  'Netflix',
  'Phone',
  'Gas',
  'Insurance',
  'Rent',
  'Subscription',
  'Tuition',
  'Medical',
  'Groceries',
  'Transportation',
  'Dining',
  'Shopping',
  'Utilities',
];

// Predefined income types
const List<String> predefinedIncomeTypes = [
  'Salary',
  'Remittance',
  'Business',
  'Allowance',
  'Scholarship',
  'Freelance',
  'Investment',
  'Bonus',
  'Commission',
  'Dividend',
  'Pension',
  'Gift',
  'Refund',
  'Rental Income',
];

// Legacy support - combined list
const List<String> predefinedBillTypes = [
  ...predefinedExpenseTypes,
  ...predefinedIncomeTypes,
];

class Bill {
  final String id;
  final String type; // Name/Type
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final bool isIncome;
  final String frequency; // Everyday, Weekly, Monthly, etc.

  Bill({
    required this.id,
    required this.type,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    this.isIncome = false,
    this.frequency = 'Monthly',
  });

  Bill copyWith({
    String? id,
    String? type,
    double? amount,
    DateTime? dueDate,
    bool? isPaid,
    bool? isIncome,
    String? frequency,
  }) {
    return Bill(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      isIncome: isIncome ?? this.isIncome,
      frequency: frequency ?? this.frequency,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amount': amount,
    'dueDate': dueDate.toIso8601String(),
    'isPaid': isPaid,
    'isIncome': isIncome,
    'frequency': frequency,
  };

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
    id: json['id'],
    type: json['type'],
    amount: (json['amount'] as num).toDouble(),
    dueDate: DateTime.parse(json['dueDate']),
    isPaid: json['isPaid'] ?? false,
    isIncome: json['isIncome'] ?? false,
    frequency: json['frequency'] ?? 'Monthly',
  );
}
