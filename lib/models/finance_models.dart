/// Predefined account types for quick creation
const List<String> accountTypes = [
  'Cash',
  'Bank',
  'Credit Card',
  'E-Wallet',
  'Investment',
  'Savings',
];

class WalletOption {
  final String name;
  final String category;
  final String assetPath;
  final int colorValue;

  const WalletOption({
    required this.name,
    required this.category,
    required this.assetPath,
    required this.colorValue,
  });
}

const List<WalletOption> walletOptions = [
  WalletOption(
    name: 'GCash',
    category: 'E-Wallet',
    assetPath: 'assets/images/gcash.png',
    colorValue: 0xFF007AFF,
  ),
  WalletOption(
    name: 'Maya',
    category: 'E-Wallet',
    assetPath: 'assets/images/paymaya.png',
    colorValue: 0xFF6C22A6,
  ),
  WalletOption(
    name: 'Cash',
    category: 'Cash',
    assetPath: 'assets/images/cash.png',
    colorValue: 0xFF10B981,
  ),
  WalletOption(
    name: 'BDO',
    category: 'Bank',
    assetPath: 'assets/images/bdo.png',
    colorValue: 0xFF1D4ED8,
  ),
  WalletOption(
    name: 'Landbank',
    category: 'Bank',
    assetPath: 'assets/images/landbank.png',
    colorValue: 0xFF15803D,
  ),
  WalletOption(
    name: 'PSBank',
    category: 'Bank',
    assetPath: 'assets/images/psbank.png',
    colorValue: 0xFFB91C1C,
  ),
];

WalletOption walletOptionByName(String name) {
  return walletOptions.firstWhere((wallet) => wallet.name == name);
}

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

const List<String> futureEventCategories = [
  'Salary',
  'Freelance',
  'Business',
  'Allowance',
  'Scholarship',
  'Investment',
  'Remittance',
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

/// Represents a single financial transaction.
class FinanceTransaction {
  final String id;
  final double amount;
  final String accountId; // links to Account.id
  final String accountName; // denormalized for easy display
  final String type; // "INCOME", "EXPENSE", or "TRANSFER"
  final String category;
  final String description;
  final DateTime date;
  final double? previousBalance;
  final String? destinationAccountId;
  final String? destinationAccountName;

  FinanceTransaction({
    required this.id,
    required this.amount,
    required this.accountId,
    required this.accountName,
    required this.type,
    required this.category,
    this.description = '',
    DateTime? date,
    this.previousBalance,
    this.destinationAccountId,
    this.destinationAccountName,
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
    double? previousBalance,
    String? destinationAccountId,
    String? destinationAccountName,
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
      previousBalance: previousBalance ?? this.previousBalance,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      destinationAccountName:
          destinationAccountName ?? this.destinationAccountName,
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
    'previousBalance': previousBalance,
    'destinationAccountId': destinationAccountId,
    'destinationAccountName': destinationAccountName,
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
        previousBalance: (json['previousBalance'] as num?)?.toDouble(),
        destinationAccountId: json['destinationAccountId'] as String?,
        destinationAccountName: json['destinationAccountName'] as String?,
      );

  bool get isTransfer =>
      type == 'TRANSFER' || category.trim().toLowerCase() == 'transfer';

  /// Returns true if this is an income transaction

  /// Returns true if this is an income transaction
  bool get isIncome => type == 'INCOME' && !isTransfer;

  /// Returns true if this is an expense transaction
  bool get isExpense => type == 'EXPENSE' && !isTransfer;
}

/// Represents a future scheduled financial event (not yet executed)
class FutureEvent {
  final String id;
  final double amount;
  final String
  category; // Salary, Freelance, Business, Allowance, Scholarship, Investment, Remittance
  final String description;
  final DateTime scheduledDate;
  final String frequency; // 'Once', 'Monthly', 'Weekly'
  final String?
  entity; // Optional: who is sending/receiving (e.g., "Lance", "Client")
  final bool isCompleted;
  final String type; // 'bill' or 'income'
  final String status; // 'pending', 'paid', or 'received'
  final int rescheduleCount;
  final String? wallet;
  final DateTime createdAt;

  FutureEvent({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.scheduledDate,
    String? type,
    String? status,
    this.rescheduleCount = 0,
    this.wallet,
    DateTime? createdAt,
    this.frequency = 'Once',
    this.entity,
    bool isCompleted = false,
  }) : type = type ?? _inferFutureEventType(category, description),
       status =
           status ??
           (isCompleted
               ? (_inferFutureEventType(category, description) == 'income'
                     ? 'received'
                     : 'paid')
               : 'pending'),
       createdAt = createdAt ?? DateTime.now(),
       isCompleted = isCompleted || (status != null && status != 'pending');

  FutureEvent copyWith({
    String? id,
    double? amount,
    String? category,
    String? description,
    DateTime? scheduledDate,
    String? frequency,
    String? entity,
    bool? isCompleted,
    String? type,
    String? status,
    int? rescheduleCount,
    String? wallet,
    DateTime? createdAt,
  }) {
    final nextType = type ?? this.type;
    final nextStatus =
        status ??
        (isCompleted == true
            ? (nextType == 'income' ? 'received' : 'paid')
            : this.status);
    return FutureEvent(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      frequency: frequency ?? this.frequency,
      entity: entity ?? this.entity,
      isCompleted: isCompleted ?? nextStatus != 'pending',
      type: nextType,
      status: nextStatus,
      rescheduleCount: rescheduleCount ?? this.rescheduleCount,
      wallet: wallet ?? this.wallet,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'category': category,
    'description': description,
    'scheduledDate': scheduledDate.toIso8601String(),
    'frequency': frequency,
    'entity': entity,
    'isCompleted': isCompleted,
    'type': type,
    'status': status,
    'rescheduleCount': rescheduleCount,
    'wallet': wallet,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FutureEvent.fromJson(Map<String, dynamic> json) => FutureEvent(
    id: json['id'],
    amount: (json['amount'] as num).toDouble(),
    category: json['category'],
    description: json['description'],
    scheduledDate: DateTime.parse(json['scheduledDate']),
    frequency: json['frequency'] ?? 'Once',
    entity: json['entity'],
    isCompleted: json['isCompleted'] ?? false,
    type: json['type'],
    status: json['status'],
    rescheduleCount: json['rescheduleCount'] ?? 0,
    wallet: json['wallet'],
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
  );

  /// Returns true if the event is due today or overdue.
  /// Triggers from 12:00 AM of the scheduled date onwards until completed.
  bool get isDue {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );
    return !todayStart.isBefore(eventDay);
  }

  /// Returns true if the event is scheduled for a future date (not today, not past).
  bool get isUpcoming {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );
    return eventDay.isAfter(todayStart);
  }
}

String _inferFutureEventType(String category, String description) {
  final searchable = '$category $description'.toLowerCase();
  if (RegExp(
    r'\b(?:salary|freelance|business|allowance|scholarship|investment|remittance|bonus|commission|pension|rental income|dividend|gift|refund|reimbursement|cashback)\b',
  ).hasMatch(searchable)) {
    return 'income';
  }
  return 'bill';
}
