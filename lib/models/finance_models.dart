/// Predefined account types for quick creation
const List<String> accountTypes = [
  'Cash',
  'Bank',
  'Credit Card',
  'E-Wallet',
  'Investment',
  'Savings',
];

/// Predefined transaction categories
const List<String> expenseCategories = [
  'Food',
  'Transportation',
  'Utilities',
  'Shopping',
  'Entertainment',
  'Health',
  'Education',
  'Rent',
  'Subscriptions',
  'Groceries',
  'Other',
];

const List<String> incomeCategories = [
  'Salary',
  'Freelance',
  'Business',
  'Allowance',
  'Gift',
  'Refund',
  'Other',
];

/// Represents a financial account (e.g., Cash, BPI Bank, GCash)
class Account {
  final String id;
  final String name;
  final String type; // Cash, Bank, Credit Card, E-Wallet, etc.
  final double balance;
  final String icon; // emoji or icon identifier
  final int colorValue; // stored as int for serialization

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.balance = 0.0,
    this.icon = '💰',
    this.colorValue = 0xFF4CAF50, // default green
  });

  Account copyWith({
    String? id,
    String? name,
    String? type,
    double? balance,
    String? icon,
    int? colorValue,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'balance': balance,
    'icon': icon,
    'colorValue': colorValue,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'],
    name: json['name'],
    type: json['type'],
    balance: (json['balance'] as num).toDouble(),
    icon: json['icon'] ?? '💰',
    colorValue: json['colorValue'] ?? 0xFF4CAF50,
  );
}

/// Represents a single financial transaction (income or expense)
class FinanceTransaction {
  final String id;
  final double amount;
  final String accountId; // links to Account.id
  final String accountName; // denormalized for easy display
  final String type; // "INCOME" or "EXPENSE"
  final String category;
  final String description;
  final DateTime date;

  FinanceTransaction({
    required this.id,
    required this.amount,
    required this.accountId,
    required this.accountName,
    required this.type,
    required this.category,
    this.description = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  FinanceTransaction copyWith({
    String? id,
    double? amount,
    String? accountId,
    String? accountName,
    String? type,
    String? category,
    String? description,
    DateTime? date,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'accountId': accountId,
    'accountName': accountName,
    'type': type,
    'category': category,
    'description': description,
    'date': date.toIso8601String(),
  };

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) =>
      FinanceTransaction(
        id: json['id'],
        amount: (json['amount'] as num).toDouble(),
        accountId: json['accountId'],
        accountName: json['accountName'] ?? '',
        type: json['type'],
        category: json['category'],
        description: json['description'] ?? '',
        date: DateTime.parse(json['date']),
      );

  /// Returns true if this is an income transaction
  bool get isIncome => type == 'INCOME';

  /// Returns true if this is an expense transaction
  bool get isExpense => type == 'EXPENSE';
}
