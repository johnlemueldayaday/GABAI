import 'package:gabay/models/finance_models.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:gabay/services/gab_cooking_assistant.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/services/future_event_storage.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/services/bill_expense_classifier.dart';

/// Unified reply object for GAB
class GabReply {
  final String text;
  final List<String>? extraTexts;
  final List<String> quickReplies;
  final List<Account> walletChoices;
  final GabTransactionNotification? transactionNotification;
  final String? navigateTo;
  final String? highlightColor; // 'red' for expenses, 'green' for income

  const GabReply(
    this.text, {
    this.extraTexts,
    this.quickReplies = const [],
    this.walletChoices = const [],
    this.transactionNotification,
    this.navigateTo,
    this.highlightColor,
  });
}

class GabTransactionNotification {
  final String title;
  final String subtitle;

  const GabTransactionNotification({
    required this.title,
    required this.subtitle,
  });
}

/// GAB Step state machine for multi-turn cooking conversations
enum GabStep {
  idle,
  cravingPrompt,
  dishPrompt,
  cartPrompt,
  awaitingExpenseAccount,
  awaitingIncomeAccount,
  awaitingDuePaymentAction,
  awaitingDuePaymentAccount,
  awaitingDuePaymentAmountConfirmation,
  awaitingDuePaymentAmount,
  awaitingDueRescheduleDecision,
  awaitingDueRescheduleDate,
  awaitingExpenseAmount,
  awaitingExpenseItem,
  awaitingIncomeAmount,
  awaitingIncomeSource,
  awaitingAllocationPeriod,
  awaitingAllocationAmount,
  awaitingClarification,
  awaitingScheduledName,
  awaitingScheduledAmount,
  awaitingScheduledDate,
  awaitingScheduledWallet,
  awaitingScheduledDeleteConfirmation,
  awaitingScheduledSelection,
  awaitingScheduledMoveDate,
  awaitingScheduledAmountUpdate,
  awaitingTransferAmount,
  awaitingTransferSource,
  awaitingTransferDestination,
}

/// GAB - Unified smart assistant
class GabAssistant {
  final DateTime Function() _clock;
  final String _currency = SettingsService().currency;

  GabAssistant({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  // Cooking state (from Gab)
  final GabCookingAssistant _cookingEngine = GabCookingAssistant();
  GabStep _step = GabStep.idle;
  List<String> _undoTransactionIds = [];

  // Track last spending for breakdown follow-up
  bool _awaitingBreakdown = false;

  // Track pending expense details
  double? _pendingExpenseAmount;
  String? _pendingExpenseDescription;
  String? _pendingExpenseCategory;
  Account? _pendingExpenseAccount;

  // Track pending allocation details

  // Clarification
  String? _unclearRawInput;

  // Track pending scheduled entries
  String? _pendingScheduledName;
  double? _pendingScheduledAmount;
  String? _pendingScheduledDate;
  String? _pendingScheduledType; // "bill" or "income"
  String? _pendingAllocationPeriod;
  DateTime? _pendingScheduledDateTime;
  bool _pendingBillDateNeedsConfirmation = false;
  bool _pendingBillRequiresWallet = false;
  String? _pendingScheduledWallet;
  String? _pendingScheduledManagementAction;
  String? _pendingScheduledManagementInput;
  List<FutureEvent> _pendingScheduledMatches = [];
  FutureEvent? _pendingManagedEvent;

  // Track pending income details when waiting for account
  double? _pendingIncomeAmount;
  String? _pendingIncomeDescription;
  String? _pendingIncomeCategory;
  Account? _pendingIncomeAccount;

  double? _pendingTransferAmount;
  Account? _pendingTransferFrom;
  Account? _pendingTransferTo;

  // Track pending due event when processing past-due events
  FutureEvent? _pendingDueEvent;
  double? _pendingDueAmount;

  String _accountLabel(Account account) {
    final normalizedName = account.name.trim().toLowerCase();
    final hasAssetIcon =
        account.icon.startsWith('assets/images/') ||
        {
          'gcash',
          'maya',
          'paymaya',
          'cash',
          'bdo',
          'landbank',
          'psbank',
        }.contains(normalizedName);

    return hasAssetIcon ? account.name : '${account.icon} ${account.name}';
  }

  /// Returns an inline icon token like `{{icon:assets/images/gcash.png}}`
  /// that the chat bubble widget can parse and render as an inline image.
  String _accountIconToken(Account account) {
    final normalizedName = account.name.trim().toLowerCase();
    const iconMap = {
      'gcash': 'assets/images/gcash.png',
      'maya': 'assets/images/paymaya.png',
      'paymaya': 'assets/images/paymaya.png',
      'cash': 'assets/images/cash.png',
      'bdo': 'assets/images/bdo.png',
      'landbank': 'assets/images/landbank.png',
      'psbank': 'assets/images/psbank.png',
    };
    String? assetPath;
    if (account.icon.startsWith('assets/images/')) {
      assetPath = account.icon;
    } else {
      assetPath = iconMap[normalizedName];
    }
    if (assetPath != null) {
      return '{{icon:$assetPath}}';
    }
    return '${account.icon} ${account.name}';
  }

  GabReply get greeting {
    return const GabReply(
      "What can I do for you?",
      quickReplies: ['Expense', 'Income', 'Upcoming Bill'],
    );
  }

  /// Known income categories — anything the user RECEIVES.
  static const _incomeCategories = {
    'salary',
    'freelance',
    'business',
    'allowance',
    'scholarship',
    'investment',
    'remittance',
    'bonus',
    'commission',
    'pension',
    'rental income',
    'dividends',
    'gift',
    'refund',
    'reimbursement',
    'debt collection', // friend paying you back
  };

  /// Known outgoing categories for scheduled events.
  static const _outgoingCategories = {
    'car loan',
    'auto loan',
    'vehicle loan',
    'loan',
    'debt',
    'insurance',
    'meralco bill',
    'electricity bill',
    'electricity',
    'water',
    'internet',
    'rent',
    'netflix',
    'spotify',
    'subscription',
    'credit card',
    'home credit',
  };

  /// Returns true if the pending due event is an EXPENSE (outgoing money).
  /// Returns false if it is INCOME (incoming money like Salary, Allowance, etc.)
  bool _pendingEventIsOutgoing() {
    final event = _pendingDueEvent;
    if (event == null) return false;
    if (event.type == 'bill') return true;
    if (event.type == 'income') return false;
    // Check stored category first — most reliable
    final cat = event.category.toLowerCase().trim();
    if (_outgoingCategories.contains(cat)) return true;
    if (_incomeCategories.contains(cat)) return false;
    // Fallback: check description keywords
    return _isFutureOutgoingObligation(
      '${event.category} ${event.description}'.toLowerCase(),
    );
  }

  Future<GabReply> getAsyncGreeting() async {
    final dueEvents = await FutureEventStorage.getDueEvents();
    if (dueEvents.isNotEmpty) {
      _pendingDueEvent = dueEvents.first;
      _pendingDueAmount = _pendingDueEvent!.amount;
      _step = GabStep.awaitingDuePaymentAction;
      final amountStr = _formatNumberWithCommas(
        _pendingDueEvent!.amount.toStringAsFixed(2),
      );
      final isOutgoing = _pendingEventIsOutgoing();
      final name = _dueEventDisplayName(_pendingDueEvent!);
      final question = isOutgoing
          ? '📅 Reminder: $name Bill (P-$amountStr) is due today. Did you pay it?'
          : '💰 Reminder: $name (P $amountStr) is expected today. Did you receive it?';
      return GabReply(question, quickReplies: const ["Yes", "No"]);
    }
    return greeting;
  }

  void resetConversation() {
    _resetState();
    _cookingEngine.resetConversation();
    _undoTransactionIds = [];
  }

  String _dueEventDisplayName(FutureEvent event) {
    final description = event.description.trim();
    if (description.toLowerCase().endsWith(' bill')) {
      return cleanBillName(
        description.substring(0, description.length - 5).trim(),
      );
    }
    return cleanBillName(description);
  }

  bool _isScheduledManagementCommand(String input) {
    final normalized = input.toLowerCase();
    if (RegExp(
      r'\b(?:show|list)\b.*\b(?:upcoming\s+bills?|bills?\s+(?:are\s+)?due|incoming\s+money|upcoming\s+events?)\b|\bwhat\s+bills?\s+(?:are\s+)?due\b',
    ).hasMatch(normalized)) {
      return true;
    }
    final hasManagementVerb = RegExp(
      r'\b(?:cancel|delete|move|change)\b',
    ).hasMatch(normalized);
    final hasScheduledName = RegExp(
      r'\b(?:bill|payment|rent|utilities|electricity|water|internet|wifi|phone|loan|credit\s+card|insurance|tuition|subscription|mortgage|amortization|installment|salary|allowance|commission|bonus|13th\s+month|refund|freelance|pension|cashback|incoming\s+money|entry)\b',
    ).hasMatch(normalized);
    return hasManagementVerb && hasScheduledName;
  }

  Future<GabReply> _handleScheduledManagementCommand(String input) async {
    _resetState();
    final normalized = input.toLowerCase();
    final events =
        (await FutureEventStorage.loadEvents())
            .where((event) => event.status == 'pending' && !event.isCompleted)
            .toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    final listType = _scheduledListType(normalized);
    if (listType != null) {
      if (listType == 'bill') return await _billsSummaryReply();
      final matchingEvents = events.where((event) {
        if (listType == 'bill') return event.type == 'bill';
        if (listType == 'income') return event.type == 'income';
        return true;
      }).toList();
      return _scheduledEventsListReply(matchingEvents);
    }

    final action = _scheduledManagementAction(normalized);
    if (action == null) {
      return const GabReply("I couldn't find that entry.");
    }

    final target = _scheduledManagementTarget(input);
    final matches = events.where((event) {
      final searchable =
          '${event.description} ${event.category} ${event.entity ?? ''}'
              .toLowerCase();
      return target.isNotEmpty &&
          (searchable.contains(target) || target.contains(searchable.trim()));
    }).toList();
    if (matches.isEmpty) {
      return const GabReply("I couldn't find that entry.");
    }

    _pendingScheduledManagementAction = action;
    _pendingScheduledManagementInput = input;
    if (matches.length > 1) {
      _pendingScheduledMatches = matches;
      _step = GabStep.awaitingScheduledSelection;
      return GabReply(
        'Which one do you mean?\n${_formatScheduledEvents(matches, numbered: true)}',
      );
    }

    return _beginScheduledManagement(matches.single, action, input);
  }

  String? _scheduledListType(String input) {
    if (RegExp(
      r'\b(?:incoming\s+money|incoming\s+transactions?)\b',
    ).hasMatch(input)) {
      return 'income';
    }
    if (RegExp(
      r'\b(?:upcoming\s+bills?|bills?\s+(?:are\s+)?due)\b',
    ).hasMatch(input)) {
      return 'bill';
    }
    if (RegExp(r'\bupcoming\s+events?\b').hasMatch(input)) return 'all';
    if (RegExp(r'\bshow\s+my\s+incoming\s+money\b').hasMatch(input)) {
      return 'income';
    }
    return null;
  }

  String? _scheduledManagementAction(String input) {
    if (RegExp(r'\b(?:cancel|delete)\b').hasMatch(input)) return 'delete';
    if (RegExp(r'\bmove\b').hasMatch(input)) return 'move';
    if (RegExp(r'\bchange\b').hasMatch(input)) return 'amount';
    return null;
  }

  String _scheduledManagementTarget(String input) {
    var target = input.toLowerCase();
    target = target.replaceFirst(
      RegExp(r'\b(?:cancel|delete|move|change)\b'),
      ' ',
    );
    target = target.replaceAll(
      RegExp(r'\b(?:to|on|by|due|the|my|a|an|please)\b'),
      ' ',
    );
    target = _removeUpcomingBillDate(target);
    target = target.replaceAll(
      RegExp(r'(?<![\w/])\d+(?:,\d{3})*(?:\.\d+)?\s*[km]?\b'),
      ' ',
    );
    target = target.replaceAll(
      RegExp(r'\b(?:p|php|peso|pesos)\b|₱', caseSensitive: false),
      ' ',
    );
    target = target.replaceAll(
      RegExp(r'\b(?:bill|payment|entry|scheduled|incoming|money)\b'),
      ' ',
    );
    target = target.replaceAll(RegExp(r'[^\w\s-]'), ' ');
    return target.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<GabReply> _beginScheduledManagement(
    FutureEvent event,
    String action,
    String input,
  ) async {
    _pendingManagedEvent = event;
    _pendingScheduledManagementAction = action;
    final name = _scheduledManagementDisplayName(event);
    if (action == 'delete') {
      _step = GabStep.awaitingScheduledDeleteConfirmation;
      return GabReply(
        'Are you sure you want to delete $name?',
        quickReplies: const ['Yes', 'No'],
      );
    }
    if (action == 'move') {
      final date = _parseUpcomingBillDate(input, allowBareDay: true);
      if (date == null) {
        _step = GabStep.awaitingScheduledMoveDate;
        return GabReply('When should I move $name to?');
      }
      return _moveScheduledEvent(event, date);
    }
    final amount = _parseExpenseAmount(input);
    if (amount == null) {
      _step = GabStep.awaitingScheduledAmountUpdate;
      return GabReply('What amount should I set for $name?');
    }
    if (!amount.isFinite || amount <= 0) {
      _step = GabStep.awaitingScheduledAmountUpdate;
      return const GabReply('Please enter a valid amount, for example 250.00.');
    }
    return _updateScheduledEventAmount(event, amount);
  }

  GabReply _scheduledEventsListReply(List<FutureEvent> events) {
    if (events.isEmpty) {
      return const GabReply('You have no upcoming bills or incoming money.');
    }
    return GabReply('📅 Upcoming Events\n${_formatScheduledEvents(events)}');
  }

  String _formatScheduledEvents(
    List<FutureEvent> events, {
    bool numbered = false,
  }) {
    return events
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final event = entry.value;
          final name = event.type == 'bill'
              ? event.description
              : _dueEventDisplayName(event);
          final date =
              '${_getMonthAbbreviation(event.scheduledDate.month)} ${event.scheduledDate.day}';
          final emoji = _scheduledEventEmoji(event);
          final amount = _formatNumberWithCommas(
            event.amount.toStringAsFixed(2),
          );
          final formattedAmount = event.type == 'income'
              ? 'P +$amount'
              : 'P-$amount';
          final prefix = numbered ? '${index + 1}. ' : '';
          return '$prefix$date   $emoji $name   $formattedAmount';
        })
        .join('\n');
  }

  String _scheduledEventEmoji(FutureEvent event) {
    final text = '${event.category} ${event.description}'.toLowerCase();
    if (event.type == 'income') {
      if (text.contains('salary')) return '💰';
      if (text.contains('bonus') || text.contains('13th month')) return '🎁';
      if (text.contains('allowance')) return '💵';
      if (text.contains('commission') || text.contains('business')) return '📈';
      if (text.contains('refund') || text.contains('cashback')) return '🔁';
      return '💰';
    }
    if (text.contains('electric')) return '💡';
    if (text.contains('water')) return '💧';
    if (text.contains('internet') || text.contains('wifi')) return '🌐';
    if (text.contains('rent')) return '🏠';
    if (text.contains('phone') || text.contains('load')) return '📱';
    if (text.contains('credit card') || text.contains('loan')) return '💳';
    return '📅';
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }

  Future<GabReply> _handleScheduledManagementState(String input) async {
    final normalized = input.trim().toLowerCase();
    if (_step == GabStep.awaitingScheduledSelection) {
      final matches = _pendingScheduledMatches;
      FutureEvent? selected;
      final index = int.tryParse(normalized.replaceFirst(RegExp(r'\.$'), ''));
      if (index != null && index >= 1 && index <= matches.length) {
        selected = matches[index - 1];
      } else {
        final selectedDate = _parseUpcomingBillDate(input, allowBareDay: true);
        for (final event in matches) {
          final eventName =
              '${event.description} ${event.category} ${event.entity ?? ''}'
                  .toLowerCase();
          if (eventName.contains(normalized) ||
              (selectedDate != null &&
                  event.scheduledDate.year == selectedDate.year &&
                  event.scheduledDate.month == selectedDate.month &&
                  event.scheduledDate.day == selectedDate.day)) {
            selected = event;
            break;
          }
        }
      }
      if (selected == null) {
        return GabReply(
          'Which one do you mean?\n${_formatScheduledEvents(matches, numbered: true)}',
        );
      }
      final action = _pendingScheduledManagementAction!;
      final command = _pendingScheduledManagementInput ?? input;
      _pendingScheduledMatches = [];
      return _beginScheduledManagement(selected, action, command);
    }
    if (_step == GabStep.awaitingScheduledDeleteConfirmation) {
      if (RegExp(r'^(?:yes|y|yeah|yep|sure)\b').hasMatch(normalized)) {
        final event = _pendingManagedEvent!;
        try {
          await FutureEventStorage.removeEvent(event.id);
          final bills = await BillStorage.loadBills();
          bills.removeWhere((bill) => bill.id == 'future_${event.id}');
          await BillStorage.saveBills(bills);
          _resetState();
          return GabReply(
            'Done! I deleted ${_scheduledManagementDisplayName(event)}.',
          );
        } catch (error) {
          return GabReply('⚠️ Failed to delete scheduled entry: $error');
        }
      }
      if (RegExp(r'^(?:no|n|nope)\b').hasMatch(normalized)) {
        _resetState();
        return const GabReply('Okay, I kept that entry.');
      }
      return GabReply(
        'Are you sure you want to delete ${_scheduledManagementDisplayName(_pendingManagedEvent!)}?',
        quickReplies: const ['Yes', 'No'],
      );
    }
    if (_step == GabStep.awaitingScheduledMoveDate) {
      final date = _parseUpcomingBillDate(input, allowBareDay: true);
      if (date == null) {
        return GabReply(
          'When should I move ${_scheduledManagementDisplayName(_pendingManagedEvent!)} to?',
        );
      }
      return _moveScheduledEvent(_pendingManagedEvent!, date);
    }
    if (_step == GabStep.awaitingScheduledAmountUpdate) {
      final amount = _parseExpenseAmount(input);
      if (amount == null || !amount.isFinite || amount <= 0) {
        return const GabReply(
          'Please enter a valid amount, for example 250.00.',
        );
      }
      return _updateScheduledEventAmount(_pendingManagedEvent!, amount);
    }
    return const GabReply("I couldn't find that entry.");
  }

  Future<GabReply> _moveScheduledEvent(FutureEvent event, DateTime date) async {
    try {
      await FutureEventStorage.updateEvent(event.copyWith(scheduledDate: date));
      final bills = await BillStorage.loadBills();
      final index = bills.indexWhere((bill) => bill.id == 'future_${event.id}');
      if (index >= 0) {
        bills[index] = bills[index].copyWith(dueDate: date);
        await BillStorage.saveBills(bills);
      }
      final dateText = _formatBillDate(date);
      _resetState();
      return GabReply(
        'Done! I moved your ${_scheduledManagementDisplayName(event)} to $dateText.',
      );
    } catch (error) {
      return GabReply('⚠️ Failed to move scheduled entry: $error');
    }
  }

  Future<GabReply> _updateScheduledEventAmount(
    FutureEvent event,
    double amount,
  ) async {
    try {
      await FutureEventStorage.updateEvent(event.copyWith(amount: amount));
      final bills = await BillStorage.loadBills();
      final index = bills.indexWhere((bill) => bill.id == 'future_${event.id}');
      if (index >= 0) {
        bills[index] = bills[index].copyWith(amount: amount);
        await BillStorage.saveBills(bills);
      }
      final formattedAmount = _formatNumberWithCommas(
        amount.toStringAsFixed(2),
      );
      final name = _scheduledManagementDisplayName(event);
      _resetState();
      return GabReply('Done! Your $name is now P $formattedAmount.');
    } catch (error) {
      return GabReply('⚠️ Failed to update scheduled entry: $error');
    }
  }

  String _scheduledManagementDisplayName(FutureEvent event) =>
      event.type == 'bill' ? event.description : _dueEventDisplayName(event);

  /// Main intent router — the brain of GAB
  Future<GabReply> handle(String rawInput) async {
    final normalized = rawInput.trim().toLowerCase();
    final undoIds = _undoTransactionIds;
    _undoTransactionIds = [];

    if (_isUndoCommand(normalized)) {
      if (undoIds.isEmpty) {
        resetConversation();
        return const GabReply(
          'There is no recent transaction to undo.',
          quickReplies: ['What is my total balance?'],
        );
      }
      resetConversation();
      return await _undoTransactions(undoIds);
    }

    final transactionsBefore = await FinanceStorage.loadTransactions();
    final reply = await _handleMessage(rawInput);
    final existingIds = transactionsBefore
        .map((transaction) => transaction.id)
        .toSet();
    final transactionsAfter = await FinanceStorage.loadTransactions();
    final resultingIds = transactionsAfter
        .map((transaction) => transaction.id)
        .toSet();
    if (existingIds.every(resultingIds.contains)) {
      _undoTransactionIds = transactionsAfter
          .where((transaction) => !existingIds.contains(transaction.id))
          .map((transaction) => transaction.id)
          .toList();
    }
    return reply;
  }

  Future<GabReply> _handleMessage(String rawInput) async {
    final input = rawInput.trim();
    final n = input.toLowerCase(); // normalized

    // ─── 0. GREETING / HELP ───
    if (n == 'help' || n == 'commands' || n.contains('what can you do')) {
      resetConversation();
      return _helpReply();
    }
    if (n == 'start over' || n == 'reset') {
      resetConversation();
      return greeting;
    }

    final quickAction = n.replaceFirst(RegExp(r'^[^a-z]+'), '').trim();
    if (quickAction == 'do something else') {
      resetConversation();
      return const GabReply("Sure! What else can I help you with?");
    }
    if (quickAction == 'another expense') {
      resetConversation();
      _step = GabStep.awaitingExpenseAmount;
      return const GabReply(
        'How much did you spend?',
        quickReplies: ['❌ Cancel', '🔄'],
      );
    }
    if (quickAction == 'log income') {
      resetConversation();
      _step = GabStep.awaitingIncomeAmount;
      return const GabReply('How much did you receive?');
    }
    if (quickAction == 'check balance') {
      resetConversation();
      return (await _tryBalanceCheck('check balance'))!;
    }
    if (quickAction == 'done') {
      resetConversation();
      return const GabReply("Okay! Let me know if you need anything else.");
    }

    if (_isUpcomingBillsInquiry(n)) {
      resetConversation();
      return await _billsSummaryReply();
    }
    final freshBalanceReply = await _tryBalanceCheck(n);
    if (freshBalanceReply != null) {
      if (!_isExpenseFlowActive) resetConversation();
      return freshBalanceReply;
    }
    if (_step != GabStep.idle && _isFreshQuestion(n)) {
      resetConversation();
    }

    if (_isScheduledManagementCommand(n)) {
      return await _handleScheduledManagementCommand(input);
    }

    final transferResult = await _tryTransfer(n);
    if (transferResult != null) return transferResult;
    if (_isTransferStep) {
      return await _handlePendingTransfer(input);
    }

    if (_step == GabStep.awaitingScheduledDeleteConfirmation ||
        _step == GabStep.awaitingScheduledSelection ||
        _step == GabStep.awaitingScheduledMoveDate ||
        _step == GabStep.awaitingScheduledAmountUpdate) {
      if (_isCancellation(n)) {
        _resetState();
        return const GabReply('Okay, I cancelled that. Nothing was saved.');
      }
      if (!_isScheduledManagementCommand(n)) {
        return await _handleScheduledManagementState(input);
      }
    }
    if (_step == GabStep.awaitingDuePaymentAction ||
        _step == GabStep.awaitingDuePaymentAccount ||
        _step == GabStep.awaitingDuePaymentAmountConfirmation ||
        _step == GabStep.awaitingDuePaymentAmount ||
        _step == GabStep.awaitingDueRescheduleDecision ||
        _step == GabStep.awaitingDueRescheduleDate) {
      return await _handleStateMachine(n);
    }

    if (_isExpenseFlowActive) {
      if (_isCancellation(n)) {
        _resetState();
        return const GabReply("Okay, I cancelled that. Nothing was saved.");
      }
      final balanceReply = await _tryBalanceCheck(n);
      if (balanceReply != null) return balanceReply;
      if (!_isNewCommandDuringExpense(n)) {
        return await _handleOngoingExpenseFlow(input);
      }
      _resetState();
    }
    if (_isIncomeFlowActive) {
      if (_isCancellation(n)) {
        _resetState();
        return const GabReply("Okay, I cancelled that. Nothing was saved.");
      }
      if (!_isNewCommandDuringIncome(n)) {
        return await _handleOngoingIncomeFlow(input);
      }
      _resetState();
    }
    if (_isAllocationFlowActive) {
      if (_isCancellation(n)) {
        _resetState();
        return const GabReply("Okay, I cancelled that. Nothing was saved.");
      }
      if (!_isNewCommandDuringAllocation(n)) {
        return await _handleAllocationFlow(input);
      }
      _resetState();
    }
    if (_pendingScheduledType == 'bill' &&
        (_step == GabStep.awaitingScheduledName ||
            _step == GabStep.awaitingScheduledAmount ||
            _step == GabStep.awaitingScheduledDate ||
            _step == GabStep.awaitingScheduledWallet)) {
      if (_isCancellation(n)) {
        _resetState();
        return const GabReply('Okay, I cancelled that. Nothing was saved.');
      }
      if (RegExp(
            r'\b(?:spent|spend|bought|paid|purchase|purchased|cost\s+me|charged)\b',
          ).hasMatch(n) ||
          _isIncomeIntent(n) ||
          (_hasAllocationUpdateWord(n) && _hasAllocationBudgetWord(n))) {
        _resetState();
      } else {
        return await _handleUpcomingBillFlow(input);
      }
    }

    final budgetAsk = _tryBudgetValueAsk(n);
    if (budgetAsk != null) return budgetAsk;
    final budgetConcern = _tryBudgetConcernReply(n);
    if (budgetConcern != null) return budgetConcern;

    final allocationReply = await _trySetDailyAllocation(n);
    if (allocationReply != null) return allocationReply;

    final scheduledResult = await _tryScheduledEntry(n);
    if (scheduledResult != null) return scheduledResult;
    final futureEventResult = await _tryFutureEvent(n);
    if (futureEventResult != null) return futureEventResult;

    final expenseResult = await _tryLogExpense(n);
    if (expenseResult != null) return expenseResult;

    // ─── 1. STATE MACHINE (mid-conversation flows take priority) ───
    if (_step != GabStep.idle) {
      return await _handleStateMachine(n);
    }

    // ─── 5. FINANCE: income logging ───
    final incomeResult = await _tryLogIncome(n);
    if (incomeResult != null) return incomeResult;

    // ─── 5.5. AMBIGUOUS AMOUNT CHECK ───
    final ambiguousResult = _tryAmbiguousAmount(n);
    if (ambiguousResult != null) return ambiguousResult;

    // ─── 6. FINANCE: total balance / balance checks ───
    final balanceResult = await _tryBalanceCheck(n);
    if (balanceResult != null) return balanceResult;

    // ─── 7. BILLS ───
    if (_isWeeklyBillAsk(n)) return await _weeklyBillsReply();
    if (_isBillAsk(n)) return await _billsSummaryReply();

    // ─── 7. GROCERY SPENDING HISTORY ───
    if (_awaitingBreakdown && _isBreakdownAsk(n)) {
      _awaitingBreakdown = false;
      final reply = _cookingEngine.handle(input);
      return _fromGab(reply);
    }
    if (_isSpendingAsk(n)) {
      _awaitingBreakdown = true;
      final reply = _cookingEngine.handle(input);
      return _fromGab(reply);
    }

    // ─── 8. GROCERY BUDGET ───
    if (_isBudgetAsk(n)) {
      final reply = _cookingEngine.handle(input);
      return _fromGab(reply);
    }

    // ─── 9. ANALYTICS ───
    if (_isAnalyticsAsk(n)) {
      final reply = _cookingEngine.handle(input);
      return _fromGab(reply);
    }

    // ─── 10. COOKING: direct recipe request ───
    if (_isCookingAsk(n)) {
      return _delegateToCooking(input);
    }

    // ─── 11. MEAL PLAN ───
    if (_isMealPlanAsk(n)) {
      final reply = _cookingEngine.handle(input);
      return _fromGab(reply);
    }

    // ─── 12. BILL NOTIFICATIONS ───
    if (n.contains('notify me')) {
      return const GabReply(
        "Got it! I've set a reminder for you. I'll make sure to notify you 3 days before the due date so you never miss a payment! 🔔",
        quickReplies: [
          'What is my total balance?',
          'What can I cook for dinner?',
        ],
      );
    }

    // ─── 13. CRAVING KEYWORDS (e.g. "healthy", "soupy", "spicy") ───
    if (_isCravingKeyword(n)) {
      return _delegateToCooking(input);
    }

    // ─── FALLBACK ───
    return _fallbackReply();
  }

  // ═══════════════════════════════════════════════
  //  STATE MACHINE (multi-turn cooking flows)
  // ═══════════════════════════════════════════════

  Future<GabReply> _handleStateMachine(String n) async {
    if (_isTransferStep) return await _handlePendingTransfer(n);

    if (_step == GabStep.awaitingScheduledName ||
        _step == GabStep.awaitingScheduledAmount ||
        _step == GabStep.awaitingScheduledDate ||
        _step == GabStep.awaitingScheduledWallet) {
      return await _handleScheduledEntryFlow(n);
    }
    if (_step == GabStep.awaitingScheduledDeleteConfirmation ||
        _step == GabStep.awaitingScheduledSelection ||
        _step == GabStep.awaitingScheduledMoveDate ||
        _step == GabStep.awaitingScheduledAmountUpdate) {
      return await _handleScheduledManagementState(n);
    }

    // Handle awaiting expense item/amount states
    if (_step == GabStep.awaitingExpenseItem ||
        _step == GabStep.awaitingExpenseAmount ||
        _step == GabStep.awaitingExpenseAccount) {
      return await _handleOngoingExpenseFlow(n);
    }

    // Handle clarification state
    if (_step == GabStep.awaitingClarification) {
      return await _handleClarification(n);
    }

    if (_step == GabStep.awaitingIncomeAmount ||
        _step == GabStep.awaitingIncomeSource ||
        _step == GabStep.awaitingIncomeAccount) {
      return await _handleOngoingIncomeFlow(n);
    }

    if (_step == GabStep.awaitingDuePaymentAction) {
      return await _handleDuePaymentActionResponse(n);
    }

    if (_step == GabStep.awaitingDuePaymentAccount) {
      return await _handleDuePaymentAccountResponse(n);
    }
    if (_step == GabStep.awaitingDuePaymentAmountConfirmation) {
      return _handleDuePaymentAmountConfirmation(n);
    }
    if (_step == GabStep.awaitingDuePaymentAmount) {
      return await _handleDuePaymentAmountResponse(n);
    }
    if (_step == GabStep.awaitingDueRescheduleDecision) {
      return _handleDueRescheduleDecision(n);
    }
    if (_step == GabStep.awaitingDueRescheduleDate) {
      return await _handleDueRescheduleDate(n);
    }

    // Allow finance commands to break out of cooking flow
    final transferResult = await _tryTransfer(n);
    if (transferResult != null) {
      _resetState();
      return transferResult;
    }
    final futureEventResult = await _tryFutureEvent(n);
    if (futureEventResult != null) {
      _resetState();
      return futureEventResult;
    }
    final multiResult = await _tryMultiTransaction(n);
    if (multiResult != null) {
      _resetState();
      return multiResult;
    }
    final expenseResult = await _tryLogExpense(n);
    if (expenseResult != null) {
      _resetState();
      return expenseResult;
    }
    final incomeResult = await _tryLogIncome(n);
    if (incomeResult != null) {
      _resetState();
      return incomeResult;
    }
    final correctionResult = await _tryCorrection(n);
    if (correctionResult != null) {
      _resetState();
      return correctionResult;
    }
    final balanceResult = await _tryBalanceCheck(n);
    if (balanceResult != null) {
      _resetState();
      return balanceResult;
    }

    // Otherwise delegate to Gab's state machine
    final reply = _cookingEngine.handle(n);
    _syncStep();
    return _fromGab(reply);
  }

  void _syncStep() {
    // Mirror the cooking engine state to GAB.s step
    switch (_cookingEngine.stepForGab) {
      case GabCookingStep.mealPrompt:
        _step = GabStep.idle;
        break;
      case GabCookingStep.cravingPrompt:
        _step = GabStep.cravingPrompt;
        break;
      case GabCookingStep.dishPrompt:
        _step = GabStep.dishPrompt;
        break;
      case GabCookingStep.cartPrompt:
        _step = GabStep.cartPrompt;
        break;
    }
  }

  GabReply _delegateToCooking(String input) {
    final reply = _cookingEngine.handle(input);
    _syncStep();
    return _fromGab(reply);
  }

  void _resetState() {
    _step = GabStep.idle;
    _awaitingBreakdown = false;
    _pendingExpenseAmount = null;
    _pendingExpenseDescription = null;
    _pendingExpenseCategory = null;
    _pendingExpenseAccount = null;
    _pendingIncomeAmount = null;
    _pendingIncomeDescription = null;
    _pendingIncomeCategory = null;
    _pendingIncomeAccount = null;
    _pendingTransferAmount = null;
    _pendingTransferFrom = null;
    _pendingTransferTo = null;
    _pendingDueEvent = null;
    _pendingDueAmount = null;
    _pendingScheduledName = null;
    _pendingScheduledAmount = null;
    _pendingScheduledDate = null;
    _pendingScheduledType = null;
    _pendingAllocationPeriod = null;
    _pendingScheduledDateTime = null;
    _pendingBillDateNeedsConfirmation = false;
    _pendingBillRequiresWallet = false;
    _pendingScheduledWallet = null;
    _pendingScheduledManagementAction = null;
    _pendingScheduledManagementInput = null;
    _pendingScheduledMatches = [];
    _pendingManagedEvent = null;
  }

  bool get _isExpenseFlowActive =>
      _step == GabStep.awaitingExpenseAmount ||
      _step == GabStep.awaitingExpenseItem ||
      _step == GabStep.awaitingExpenseAccount;

  bool get _isTransferStep =>
      _step == GabStep.awaitingTransferAmount ||
      _step == GabStep.awaitingTransferSource ||
      _step == GabStep.awaitingTransferDestination;

  bool get _isIncomeFlowActive =>
      _step == GabStep.awaitingIncomeAmount ||
      _step == GabStep.awaitingIncomeSource ||
      _step == GabStep.awaitingIncomeAccount;

  bool get _isAllocationFlowActive =>
      _step == GabStep.awaitingAllocationPeriod ||
      _step == GabStep.awaitingAllocationAmount;

  bool _isCancellation(String input) =>
      const {'cancel', 'stop', 'never mind', 'nevermind', 'forget it'}.contains(
        input.trim().toLowerCase().replaceFirst(RegExp(r'^[^a-z]+'), '').trim(),
      );

  bool _isNewCommandDuringExpense(String input) {
    final n = input.toLowerCase().trim();
    if (_hasFutureExpenseSignal(n) ||
        _isExpenseIntent(n) ||
        _isIncomeIntent(n)) {
      return true;
    }
    final hasBudgetWord = RegExp(
      r'\b(?:budget|allocation|allowance|limit|cap)\b',
    ).hasMatch(n);
    final hasUpdateWord = RegExp(
      r'\b(?:update|change|set|adjust|edit|revise|modify|reset|raise|lower|increase|decrease)\b',
    ).hasMatch(n);
    return (hasBudgetWord && hasUpdateWord) ||
        RegExp(
          r'\bmy\s+(?:daily|weekly|monthly)\s+(?:allocation|budget|spending|spend)\b',
        ).hasMatch(n) ||
        RegExp(r'\btransfer\b').hasMatch(n);
  }

  bool _isNewCommandDuringIncome(String input) {
    final n = input.toLowerCase().trim();
    return _isExpenseIntent(n) ||
        _hasFutureExpenseSignal(n) ||
        (_parseExpenseAmount(n) != null && _isIncomeIntent(n)) ||
        RegExp(
          r'\b(?:received|got paid|earned|just got|was paid)\b',
        ).hasMatch(n) ||
        RegExp(
          r'\b(?:update|change|set|adjust|edit|revise|modify|reset|raise|lower|increase|decrease)\b.*\b(?:budget|allocation|allowance|limit|cap)\b',
        ).hasMatch(n) ||
        RegExp(r'\btransfer\b').hasMatch(n);
  }

  bool _isNewCommandDuringAllocation(String input) {
    final n = input.toLowerCase().trim();
    if (_isExpenseIntent(n) ||
        _isIncomeIntent(n) ||
        _hasFutureExpenseSignal(n) ||
        RegExp(r'\btransfer\b').hasMatch(n)) {
      return true;
    }
    final period = _allocationPeriodFromText(n);
    final isAcceptedBudgetStatement =
        _hasAllocationBudgetWord(n) &&
        period != null &&
        _parseExpenseAmount(n) != null &&
        RegExp(r'\b(?:is|will\s+be)\b').hasMatch(n);
    final isRuleB =
        RegExp(
          r'\bmy\s+(?:(?:daily|weekly|monthly)\s+)?(?:allocation|budget|allowance)\b',
        ).hasMatch(n) &&
        period != null;
    return (_hasAllocationUpdateWord(n) && _hasAllocationBudgetWord(n)) ||
        isAcceptedBudgetStatement ||
        isRuleB ||
        _tryBudgetValueAsk(n) != null ||
        _tryBudgetConcernReply(n) != null;
  }

  bool _hasFutureExpenseSignal(String input) => RegExp(
    r'\b(?:will|due|due on|is due|expecting|incoming|tomorrow|next week|next month|by\s+\d{1,2}|on\s+(?:the\s+)?\d{1,2}|this\s+(?:month|the\s+\d{1,2}))\b',
  ).hasMatch(input);

  double? _parseExpenseAmount(String input) {
    final match = RegExp(
      r'(?<![\w/])-?\d+(?:,\d{3})*(?:\.\d+)?\s*[km]?\b',
      caseSensitive: false,
    ).firstMatch(input);
    if (match == null) return null;

    final value = match
        .group(0)!
        .replaceAll(',', '')
        .replaceAll(RegExp(r'\s+'), '');
    final suffix = value[value.length - 1].toLowerCase();
    final hasSuffix = suffix == 'k' || suffix == 'm';
    final parsed = double.tryParse(
      hasSuffix ? value.substring(0, value.length - 1) : value,
    );
    if (parsed == null) return null;
    return switch (suffix) {
      'k' => parsed * 1000,
      'm' => parsed * 1000000,
      _ => parsed,
    };
  }

  Account? _findExpenseWallet(String text, List<Account> accounts) =>
      _findMentionedAccount(text, accounts);

  Account? _findMentionedAccount(String text, List<Account> accounts) {
    final normalized = text.toLowerCase();
    final orderedAccounts = [...accounts]
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final account in orderedAccounts) {
      if (RegExp(
        r'\b' + RegExp.escape(account.name.trim().toLowerCase()) + r'\b',
      ).hasMatch(normalized)) {
        return account;
      }
    }
    return null;
  }

  List<Account> _walletsInPromptOrder(List<Account> accounts) {
    final ordered = [...accounts];
    ordered.sort((a, b) {
      final aIsCash = a.name.trim().toLowerCase() == 'cash';
      final bIsCash = b.name.trim().toLowerCase() == 'cash';
      if (aIsCash != bIsCash) return aIsCash ? -1 : 1;
      return accounts.indexOf(a).compareTo(accounts.indexOf(b));
    });
    return ordered;
  }

  List<String> _walletNames(List<Account> accounts) =>
      _walletsInPromptOrder(accounts).map((account) => account.name).toList();

  GabReply _walletSelectionReply(
    String prompt,
    List<Account> accounts, {
    List<String> extraQuickReplies = const [],
  }) {
    final wallets = _walletsInPromptOrder(accounts);
    if (wallets.isEmpty) {
      return GabReply(
        '$prompt ${_availableWalletsText(accounts)}',
        quickReplies: extraQuickReplies,
      );
    }

    return GabReply(
      prompt,
      quickReplies: [
        ...wallets.map((wallet) => wallet.name),
        ...extraQuickReplies,
      ],
      walletChoices: wallets,
    );
  }

  GabTransactionNotification _transactionNotification({
    required bool isIncome,
    required double amount,
    required String walletName,
    required double balance,
  }) {
    final amountText = _formatNumberWithCommas(amount.toStringAsFixed(2));
    final balanceText = _formatNumberWithCommas(balance.toStringAsFixed(2));
    return GabTransactionNotification(
      title:
          '${isIncome ? 'Added' : 'Spent'} ₱$amountText ${isIncome ? 'to' : 'from'} $walletName',
      subtitle: 'Your wallet balance is now ₱$balanceText',
    );
  }

  String _availableWalletsText(List<Account> accounts) {
    final names = _walletNames(accounts);
    return names.isEmpty
        ? 'No wallets are set up yet. Please add one in Account.'
        : 'Available wallets: ${names.join(', ')}.';
  }

  String _formatExpenseAmount(double amount) {
    final formatted = _formatNumberWithCommas(amount.abs().toStringAsFixed(2));
    return amount < 0 ? '-$formatted' : formatted;
  }

  String _extractIncomeSource(String input, List<Account> accounts) {
    final isDebtRepayment =
        RegExp(
          r'\b(?:debt|loan|utang)\b',
          caseSensitive: false,
        ).hasMatch(input) ||
        RegExp(
          r'\b(?:paid|pay|repaid|repay|settled)\s+(?:me\s+)?back\b',
          caseSensitive: false,
        ).hasMatch(input);
    var source = input.toLowerCase();
    source = source.replaceAll(
      RegExp(r'(?<![\w/])-?\d+(?:,\d{3})*(?:\.\d+)?\s*[km]?\b'),
      ' ',
    );
    for (final wallet in _walletNames(accounts)) {
      source = source.replaceAll(
        RegExp(r'\b' + RegExp.escape(wallet.toLowerCase()) + r'\b'),
        ' ',
      );
    }
    source = source.replaceAll(
      RegExp(
        r'\b(?:received|recieved|got\s+paid|earned|just\s+got|was\s+paid|got|paid|income|money|from|to|in|into|through|with|via|my|me|his|i|as|the|a|an|deposit(?:ed)?)\b',
      ),
      ' ',
    );
    source = source.replaceAll(RegExp(r'[^\w\s-]'), ' ');
    source = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (isDebtRepayment) {
      const debtTerms = {
        'back',
        'debt',
        'loan',
        'utang',
        'reimbursement',
        'repayment',
        'repayments',
        'payment',
        'payments',
        'paid',
        'pay',
        'repaid',
        'settled',
      };
      final person = source
          .split(' ')
          .where((word) => word.isNotEmpty && !debtTerms.contains(word))
          .join(' ');
      return person.isEmpty ? 'Debt Repayment' : '${_titleCase(person)} Debt';
    }
    return _titleCase(source);
  }

  Future<GabReply?> _tryLogIncome(String n) async {
    if (_hasFutureExpenseSignal(n) || !_isIncomeIntent(n)) return null;

    _pendingIncomeAmount = _parseExpenseAmount(n);
    final accounts = await FinanceStorage.loadAccounts();
    _pendingIncomeDescription = _extractIncomeSource(n, accounts);
    _pendingIncomeCategory = _categorizeIncome(_pendingIncomeDescription ?? '');

    _pendingIncomeAccount = _findIncomeWallet(n, accounts);

    if (_pendingIncomeAmount != null &&
        (!_pendingIncomeAmount!.isFinite || _pendingIncomeAmount! <= 0)) {
      _step = GabStep.awaitingIncomeAmount;
      return const GabReply(
        'Please enter a valid amount, for example 8,000.00.',
      );
    }
    if (_pendingIncomeAmount == null) {
      _step = GabStep.awaitingIncomeAmount;
      return const GabReply('How much did you receive?');
    }
    if (_pendingIncomeDescription == null ||
        _pendingIncomeDescription!.isEmpty) {
      _step = GabStep.awaitingIncomeSource;
      return const GabReply('What was this income from?');
    }
    return await _continueIncomeFlow();
  }

  Account? _findIncomeWallet(String text, List<Account> accounts) {
    return _findMentionedAccount(text, accounts);
  }

  Future<GabReply> _handleOngoingIncomeFlow(String input) async {
    final accounts = await FinanceStorage.loadAccounts();
    if (_step == GabStep.awaitingIncomeAmount) {
      final amount = _parseExpenseAmount(input);
      if (amount == null || !amount.isFinite || amount <= 0) {
        return const GabReply(
          'Please enter a valid amount, for example 8,000.00.',
        );
      }
      _pendingIncomeAmount = amount;
    } else if (_step == GabStep.awaitingIncomeSource) {
      final source = _extractIncomeSource(input, accounts);
      if (source.isNotEmpty) {
        _pendingIncomeDescription = source;
        _pendingIncomeCategory = _categorizeIncome(source);
      }
    } else if (_step == GabStep.awaitingIncomeAccount) {
      final wallet = _findIncomeWallet(input, accounts);
      if (wallet == null) {
        return _walletSelectionReply(
          "I couldn't find that wallet. Which one would you like to use?",
          accounts,
        );
      }
      _pendingIncomeAccount = wallet;
    }

    return await _continueIncomeFlow();
  }

  Future<GabReply> _continueIncomeFlow() async {
    if (_pendingIncomeAmount == null) {
      _step = GabStep.awaitingIncomeAmount;
      return const GabReply('How much did you receive?');
    }
    if (_pendingIncomeDescription == null ||
        _pendingIncomeDescription!.isEmpty) {
      _step = GabStep.awaitingIncomeSource;
      return const GabReply('What was this income from?');
    }
    if (_pendingIncomeAccount == null) {
      final accounts = await FinanceStorage.loadAccounts();
      _step = GabStep.awaitingIncomeAccount;
      return _walletSelectionReply(
        'Which wallet did you deposit it to?',
        accounts,
      );
    }

    final amount = _pendingIncomeAmount!;
    final source = _pendingIncomeDescription!;
    final wallet = _pendingIncomeAccount!;
    final transaction = FinanceTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      accountId: wallet.id,
      accountName: wallet.name,
      type: 'INCOME',
      category: _pendingIncomeCategory ?? _categorizeIncome(source),
      description: source,
      date: DateTime.now(),
    );

    try {
      await FinanceStorage.addTransaction(transaction);
      final updatedWallet = (await FinanceStorage.loadAccounts()).firstWhere(
        (account) => account.id == wallet.id,
      );
      final amountText = _formatExpenseAmount(amount);
      final balanceText = _formatExpenseAmount(updatedWallet.balance);
      _resetState();
      return GabReply(
        '💵 Income logged!\n$source  +₱$amountText\nNew ${wallet.name} balance: ₱$balanceText',
        quickReplies: const ['What is my total balance?', 'Help'],
        transactionNotification: _transactionNotification(
          isIncome: true,
          amount: amount,
          walletName: wallet.name,
          balance: updatedWallet.balance,
        ),
        highlightColor: 'green',
      );
    } catch (error) {
      return GabReply(
        '⚠️ Failed to log income: $error',
        quickReplies: const ['Cancel'],
      );
    }
  }

  Future<GabReply> _handleDuePaymentActionResponse(String n) async {
    final isOutgoing = _pendingEventIsOutgoing();
    if (isOutgoing &&
        RegExp(r'\bpaid\b').hasMatch(n) &&
        !RegExp(r'\b(?:yes|yeah|yep|done|sure)\b').hasMatch(n)) {
      _step = GabStep.awaitingDuePaymentAccount;
      final accounts = await FinanceStorage.loadAccounts();
      return _walletSelectionReply(
        'Which wallet did you use to pay for it?',
        accounts,
      );
    }
    if (!isOutgoing &&
        RegExp(r'\breceived\b').hasMatch(n) &&
        !RegExp(r'\b(?:yes|yeah|yep|got it|yup|sure|done)\b').hasMatch(n)) {
      _step = GabStep.awaitingDuePaymentAccount;
      final accounts = await FinanceStorage.loadAccounts();
      return _walletSelectionReply(
        'Which wallet did you deposit or transfer it to?',
        accounts,
      );
    }
    final confirmed = isOutgoing
        ? RegExp(r'\b(?:yes|yeah|yep|paid|done|sure)\b').hasMatch(n)
        : RegExp(
            r'\b(?:yes|yeah|yep|received|got it|yup|sure|done)\b',
          ).hasMatch(n);

    if (confirmed) {
      _step = GabStep.awaitingDuePaymentAccount;
      final accounts = await FinanceStorage.loadAccounts();
      final prompt = isOutgoing
          ? 'Which wallet did you use to pay for it?'
          : 'Which wallet did you deposit or transfer it to?';
      return _walletSelectionReply(prompt, accounts);
    }

    final denied = RegExp(
      r'\b(?:no|nope|not yet|haven.t|havent|not paid|not received|nah|reschedule)\b',
    ).hasMatch(n);

    if (denied) {
      final event = _pendingDueEvent!;
      final newDate = DateTime(
        event.scheduledDate.year,
        event.scheduledDate.month,
        event.scheduledDate.day + 1,
      );
      final rescheduleCount = event.rescheduleCount + 1;
      await _rescheduleDueEvent(event, newDate, rescheduleCount);

      final dateStr = _formatBillDate(newDate);
      if (rescheduleCount >= 3) {
        _pendingDueEvent = event.copyWith(
          scheduledDate: newDate,
          rescheduleCount: rescheduleCount,
          status: 'pending',
          isCompleted: false,
        );
        _step = GabStep.awaitingDueRescheduleDecision;
        return const GabReply(
          'This has been moved 3 times. Would you like to set a new date?',
          quickReplies: ['Yes', 'No'],
        );
      }
      final message = isOutgoing
          ? 'Okay, I moved your ${_dueEventDisplayName(event)} Bill to $dateStr. I will remind you again tomorrow.'
          : 'Okay, I moved your ${_dueEventDisplayName(event)} to $dateStr. I will ask you again tomorrow.';
      _resetState();
      return GabReply(message, highlightColor: isOutgoing ? 'red' : 'green');
    }

    final event = _pendingDueEvent!;
    final amount = _formatNumberWithCommas(event.amount.toStringAsFixed(2));
    final name = _dueEventDisplayName(event);
    final question = isOutgoing
        ? '📅 Reminder: $name Bill (P-$amount) is due today. Did you pay it?'
        : '💰 Reminder: $name (P $amount) is expected today. Did you receive it?';
    return GabReply(question, quickReplies: const ['Yes', 'No']);
  }

  Future<GabReply> _handleDuePaymentAccountResponse(String n) async {
    if (_isCancellation(n)) {
      _step = GabStep.awaitingDuePaymentAction;
      return _duePaymentReminder();
    }

    final accounts = await FinanceStorage.loadAccounts();
    final event = _pendingDueEvent!;
    final amountMentioned = _extractAmountWithSlang(n);
    if (amountMentioned != null &&
        amountMentioned != (_pendingDueAmount ?? event.amount)) {
      _step = GabStep.awaitingDuePaymentAmountConfirmation;
      final scheduledAmount = _formatNumberWithCommas(
        (_pendingDueAmount ?? event.amount).toStringAsFixed(2),
      );
      return GabReply(
        'Would you like to change the amount? The scheduled amount is P-$scheduledAmount.',
        quickReplies: const ['Yes', 'No'],
      );
    }

    final acc = _findIncomeWallet(n, accounts);
    if (acc == null) {
      return _walletSelectionReply(
        "I couldn't find that wallet. Which one would you like to use?",
        accounts,
      );
    }

    final amount = _pendingDueAmount ?? event.amount;
    final isOutgoing = _pendingEventIsOutgoing();

    if (isOutgoing && acc.balance < amount) {
      final hasStr = _formatNumberWithCommas(acc.balance.toStringAsFixed(2));
      return GabReply(
        'Your ${acc.name} balance is P$hasStr, which is lower than this bill. Would you like to use another wallet?',
        quickReplies: _walletNames(accounts),
        walletChoices: _walletsInPromptOrder(accounts),
      );
    }

    try {
      final cleanName = _dueEventDisplayName(event);
      final txn = FinanceTransaction(
        id: 'bill_future_${event.id}_${event.scheduledDate.year}${event.scheduledDate.month}${event.scheduledDate.day}',
        amount: amount,
        accountId: acc.id,
        accountName: acc.name,
        type: isOutgoing ? 'EXPENSE' : 'INCOME',
        category: isOutgoing
            ? (billLabelForExpense(cleanName) ?? 'Bills')
            : event.category,
        description: isOutgoing ? 'Paid: $cleanName' : event.description,
      );
      final existingTransactions = await FinanceStorage.loadTransactions();
      final alreadyLogged = existingTransactions.any(
        (existing) =>
            existing.id == txn.id ||
            (existing.type == txn.type &&
                existing.accountId == txn.accountId &&
                existing.amount == txn.amount &&
                existing.description == txn.description),
      );
      if (!alreadyLogged) {
        await FinanceStorage.addTransaction(txn);
      }
      final updatedWallet = (await FinanceStorage.loadAccounts()).firstWhere(
        (account) => account.id == acc.id,
      );

      final updatedEvent = event.copyWith(
        isCompleted: true,
        status: isOutgoing ? 'paid' : 'received',
        wallet: acc.name,
        amount: amount,
      );
      await FutureEventStorage.updateEvent(updatedEvent);

      // also clear from bills if it's there
      final bills = await BillStorage.loadBills();
      bills.removeWhere((b) => b.id == 'future_${event.id}');
      await BillStorage.saveBills(bills);

      final amountStr = _formatNumberWithCommas(amount.toStringAsFixed(2));
      final newBalance = updatedWallet.balance;
      final newBalanceStr = _formatNumberWithCommas(
        newBalance.toStringAsFixed(2),
      );
      final balanceLine = '${acc.name} balance: P $newBalanceStr';

      _resetState();
      if (isOutgoing) {
        return GabReply(
          '✅ Payment recorded!\n${_dueEventDisplayName(event)} Bill  P-$amountStr was paid from ${acc.name}.\n$balanceLine',
          transactionNotification: _transactionNotification(
            isIncome: false,
            amount: amount,
            walletName: acc.name,
            balance: newBalance,
          ),
          highlightColor: 'red',
        );
      } else {
        return GabReply(
          '✅ ${_dueEventDisplayName(event)} received!\nP $amountStr was added to your ${acc.name} wallet.\n$balanceLine',
          transactionNotification: _transactionNotification(
            isIncome: true,
            amount: amount,
            walletName: acc.name,
            balance: newBalance,
          ),
          highlightColor: 'green',
        );
      }
    } catch (e) {
      return GabReply("⚠️ ${e.toString()}");
    }
  }

  GabReply _duePaymentReminder() {
    final event = _pendingDueEvent!;
    final isOutgoing = _pendingEventIsOutgoing();
    final amount = _formatNumberWithCommas(event.amount.toStringAsFixed(2));
    final name = _dueEventDisplayName(event);
    return GabReply(
      isOutgoing
          ? '📅 Reminder: $name Bill (P-$amount) is due today. Did you pay it?'
          : '💰 Reminder: $name (P $amount) is expected today. Did you receive it?',
      quickReplies: const ['Yes', 'No'],
    );
  }

  Future<GabReply> _handleDuePaymentAmountConfirmation(String input) async {
    final normalized = input.trim().toLowerCase();
    if (RegExp(r'^(?:yes|y|yeah|yep|sure)\b').hasMatch(normalized)) {
      _step = GabStep.awaitingDuePaymentAmount;
      return const GabReply('What is the new amount?');
    }
    if (RegExp(r'^(?:no|n|nope)\b').hasMatch(normalized)) {
      _step = GabStep.awaitingDuePaymentAccount;
      final accounts = await FinanceStorage.loadAccounts();
      return GabReply(
        'Which wallet would you like to use?',
        quickReplies: _walletNames(accounts),
        walletChoices: _walletsInPromptOrder(accounts),
      );
    }
    return const GabReply(
      'Would you like to change the amount? Please answer yes or no.',
      quickReplies: ['Yes', 'No'],
    );
  }

  Future<GabReply> _handleDuePaymentAmountResponse(String input) async {
    final amount = _parseExpenseAmount(input);
    if (amount == null || !amount.isFinite || amount <= 0) {
      return const GabReply('Please enter a valid amount, for example 250.00.');
    }
    _pendingDueAmount = amount;
    _step = GabStep.awaitingDuePaymentAccount;
    final accounts = await FinanceStorage.loadAccounts();
    return GabReply(
      'Which wallet would you like to use?',
      quickReplies: _walletNames(accounts),
      walletChoices: _walletsInPromptOrder(accounts),
    );
  }

  Future<void> _rescheduleDueEvent(
    FutureEvent event,
    DateTime date,
    int rescheduleCount,
  ) async {
    await FutureEventStorage.updateEvent(
      event.copyWith(
        scheduledDate: date,
        rescheduleCount: rescheduleCount,
        status: 'pending',
        isCompleted: false,
      ),
    );
    final bills = await BillStorage.loadBills();
    final index = bills.indexWhere((bill) => bill.id == 'future_${event.id}');
    if (index >= 0) {
      bills[index] = bills[index].copyWith(dueDate: date);
      await BillStorage.saveBills(bills);
    }
  }

  GabReply _handleDueRescheduleDecision(String input) {
    final normalized = input.trim().toLowerCase();
    if (RegExp(r'^(?:yes|y|yeah|yep|sure)\b').hasMatch(normalized)) {
      _step = GabStep.awaitingDueRescheduleDate;
      return const GabReply('What new date would you like to set?');
    }
    if (RegExp(r'^(?:no|n|nope)\b').hasMatch(normalized)) {
      _resetState();
      return const GabReply('Okay, I will keep reminding you on the due date.');
    }
    return const GabReply(
      'Would you like to set a new date? Please answer yes or no.',
      quickReplies: ['Yes', 'No'],
    );
  }

  Future<GabReply> _handleDueRescheduleDate(String input) async {
    final date = _parseUpcomingBillDate(input, allowBareDay: true);
    if (date == null) {
      return const GabReply('What new date would you like to set?');
    }
    final event = _pendingDueEvent!;
    await _rescheduleDueEvent(event, date, 0);
    final dateText = _formatBillDate(date);
    _resetState();
    return GabReply('Okay, I moved it to $dateText. I will remind you then.');
  }

  // ═══════════════════════════════════════════════
  //  FINANCE HANDLERS (from Gab)
  // ═══════════════════════════════════════════════

  Future<GabReply?> _tryTransfer(String n) async {
    final transferKeyword = RegExp(
      r'\b(?:transfer|transmit(?:ted)?|move|moved|send|sent|cash[\s-]*out)\b',
      caseSensitive: false,
    );
    final isExplicit = transferKeyword.hasMatch(n);
    final amountMatch = RegExp(
      r'\d[\d,]*(?:\.\d+)?(?:\s*[km]\b)?',
      caseSensitive: false,
    ).firstMatch(n);
    final hasToSeparator = RegExp(
      r'\s+to\s+',
      caseSensitive: false,
    ).hasMatch(n);
    if (!isExplicit && (!hasToSeparator || amountMatch == null)) return null;

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    final amountToken = amountMatch?.group(0);
    final amount = amountToken == null
        ? null
        : _extractAmountWithSlang(amountToken);
    final cleanedText = n
        .replaceFirst(amountToken ?? '', ' ')
        .replaceAll(transferKeyword, ' ')
        .replaceAll(
          RegExp(
            r'\b(?:from|account|wallet|pesos|php)\b|₱',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final splitParts = cleanedText.split(
      RegExp(r'\s+to\s+', caseSensitive: false),
    );
    final leftSide = splitParts.first.trim();
    final rightSide = splitParts.length > 1
        ? splitParts.sublist(1).join(' to ').trim()
        : '';
    final from =
        _findAccount(leftSide, accounts) ??
        _detectAccountFromText(leftSide, accounts);
    final to = rightSide.isEmpty
        ? null
        : _findAccount(rightSide, accounts) ??
              _detectAccountFromText(rightSide, accounts);

    if (!isExplicit && (from == null || to == null)) return null;
    if (amount != null && (!amount.isFinite || amount <= 0)) {
      return const GabReply(
        'Please enter a transfer amount greater than zero.',
      );
    }

    _resetState();
    _pendingTransferAmount = amount;
    _pendingTransferFrom = from;
    _pendingTransferTo = to;

    if (amount == null) {
      _step = GabStep.awaitingTransferAmount;
      return const GabReply(
        'How much would you like to transfer?',
        quickReplies: ['❌ Cancel'],
      );
    }
    if (from == null) {
      _step = GabStep.awaitingTransferSource;
      return _transferAccountPrompt(
        'Which account should I transfer from?',
        accounts,
      );
    }
    if (to == null) {
      _step = GabStep.awaitingTransferDestination;
      return _transferAccountPrompt(
        'Which account should I transfer to?',
        accounts.where((account) => account.id != from.id).toList(),
      );
    }
    if (from.id == to.id) {
      _resetState();
      return const GabReply(
        '⚠️ Choose two different accounts to transfer between.',
      );
    }

    return await _completeTransfer(from, to, amount);
  }

  GabReply _transferAccountPrompt(String prompt, List<Account> accounts) =>
      GabReply(
        prompt,
        quickReplies: accounts.map((account) => account.name).toList(),
      );

  Future<GabReply> _handlePendingTransfer(String input) async {
    if (_isCancellation(input.toLowerCase().trim())) {
      _resetState();
      return const GabReply(
        'Okay, I cancelled the transfer. Nothing was saved.',
      );
    }

    final accounts = await FinanceStorage.loadAccounts();
    if (_step == GabStep.awaitingTransferAmount) {
      final amount = _extractAmountWithSlang(input);
      if (amount == null || !amount.isFinite || amount <= 0) {
        return const GabReply('Enter a valid transfer amount.');
      }
      _pendingTransferAmount = amount;
      if (_pendingTransferFrom == null) {
        _step = GabStep.awaitingTransferSource;
        return _transferAccountPrompt(
          'Which account should I transfer from?',
          accounts,
        );
      }
      if (_pendingTransferTo == null) {
        _step = GabStep.awaitingTransferDestination;
        return _transferAccountPrompt(
          'Which account should I transfer to?',
          accounts
              .where((account) => account.id != _pendingTransferFrom!.id)
              .toList(),
        );
      }
    } else if (_step == GabStep.awaitingTransferSource) {
      final account =
          _findAccount(input, accounts) ??
          _detectAccountFromText(input, accounts);
      if (account == null) {
        return _transferAccountPrompt(
          'Choose one of your accounts as the source.',
          accounts,
        );
      }
      if (_pendingTransferTo?.id == account.id) {
        return const GabReply('Choose a different source account.');
      }
      _pendingTransferFrom = account;
      _step = _pendingTransferTo == null
          ? GabStep.awaitingTransferDestination
          : GabStep.awaitingTransferAmount;
      if (_pendingTransferAmount != null && _pendingTransferTo != null) {
        return await _completeTransfer(
          _pendingTransferFrom!,
          _pendingTransferTo!,
          _pendingTransferAmount!,
        );
      }
      if (_pendingTransferAmount != null) {
        return _transferAccountPrompt(
          'Which account should I transfer to?',
          accounts.where((item) => item.id != account.id).toList(),
        );
      }
      return const GabReply('How much would you like to transfer?');
    } else if (_step == GabStep.awaitingTransferDestination) {
      final account =
          _findAccount(input, accounts) ??
          _detectAccountFromText(input, accounts);
      if (account == null) {
        return _transferAccountPrompt(
          'Choose one of your accounts as the destination.',
          accounts
              .where((item) => item.id != _pendingTransferFrom?.id)
              .toList(),
        );
      }
      if (_pendingTransferFrom?.id == account.id) {
        return const GabReply('Choose a different destination account.');
      }
      _pendingTransferTo = account;
      if (_pendingTransferAmount == null) {
        _step = GabStep.awaitingTransferAmount;
        return const GabReply('How much would you like to transfer?');
      }
      return await _completeTransfer(
        _pendingTransferFrom!,
        account,
        _pendingTransferAmount!,
      );
    }

    return const GabReply('Tell me the amount and accounts for the transfer.');
  }

  Future<GabReply> _completeTransfer(
    Account from,
    Account to,
    double amount,
  ) async {
    if (from.id == to.id) {
      _resetState();
      return const GabReply(
        '⚠️ Choose two different accounts to transfer between.',
      );
    }

    try {
      await FinanceStorage.transferMoney(
        fromAccount: from,
        toAccount: to,
        amount: amount,
      );
      final accounts = await FinanceStorage.loadAccounts();
      final updatedFrom = accounts.firstWhere(
        (account) => account.id == from.id,
      );
      final updatedTo = accounts.firstWhere((account) => account.id == to.id);
      final formattedAmount = _formatNumberWithCommas(
        amount.toStringAsFixed(2),
      );
      final fromIcon = _accountIconToken(updatedFrom);
      final toIcon = _accountIconToken(updatedTo);
      _resetState();
      return GabReply(
        '🏦 Transfer Logged!\n'
        'Transferred $_currency$formattedAmount from $fromIcon ${updatedFrom.name} to $toIcon ${updatedTo.name}.\n'
        'New ${updatedFrom.name} balance: $_currency${_formatNumberWithCommas(updatedFrom.balance.toStringAsFixed(2))}\n'
        'New ${updatedTo.name} balance: $_currency${_formatNumberWithCommas(updatedTo.balance.toStringAsFixed(2))}',
        quickReplies: const [
          'What is my total balance?',
          'Check account balances',
        ],
      );
    } catch (error) {
      _resetState();
      return GabReply(
        '⚠️ $error',
        quickReplies: const ['What is my total balance?'],
      );
    }
  }

  Future<GabReply?> _tryLogExpense(String n) async {
    if (_hasFutureExpenseSignal(n) || !_isExpenseIntent(n)) return null;

    final accounts = await FinanceStorage.loadAccounts();
    _pendingExpenseAccount = _findExpenseWallet(n, accounts);
    var item = _extractExpenseItemFragment(n, _pendingExpenseAccount);
    if (_isUserDebtRepayment(n)) {
      item = _extractDebtRepaymentDescription(n);
    }
    if (item.isNotEmpty) {
      _pendingExpenseDescription = _titleCase(item);
      _pendingExpenseCategory = _categorizeExpense(item);
    }
    _pendingExpenseAmount = _parseExpenseAmount(n);

    if (_pendingExpenseAmount != null &&
        (!_pendingExpenseAmount!.isFinite || _pendingExpenseAmount! <= 0)) {
      _step = GabStep.awaitingExpenseAmount;
      return const GabReply('Please enter a valid amount, for example 250.00.');
    }
    if (_pendingExpenseAmount == null ||
        _pendingExpenseDescription == null ||
        _pendingExpenseDescription!.isEmpty) {
      return await _continueExpenseFlow();
    }
    return await _continueExpenseFlow();
  }

  Future<GabReply?> _tryMultiTransaction(String n) async {
    // Check if input contains "and" which might indicate multiple transactions
    final l = n.toLowerCase();

    // Look for patterns like "received X and spent Y" or "got X and paid Y"
    final multiPattern = RegExp(
      r'(?:received|got|earned|income)\s+(\d+(?:\.\d+)?)\s*(?:k)?\s*(?:pesos|php|₱)?\s*(?:and|&)\s*(?:spent|paid|expense|bought)\s+(\d+(?:\.\d+)?)\s*(?:k)?',
      caseSensitive: false,
    );

    final match = multiPattern.firstMatch(l);
    if (match == null) return null;

    // Extract amounts with slang support
    final incomeAmountStr = match.group(1)!;
    final expenseAmountStr = match.group(2)!;

    double? incomeAmount = _parseAmountWithSlang(incomeAmountStr, l);
    double? expenseAmount = _parseAmountWithSlang(expenseAmountStr, l);

    if (incomeAmount == null || expenseAmount == null) return null;

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    // Use first account for both transactions (could enhance to ask for accounts)
    final account = accounts.first;

    final results = <String>[];

    // Extract expense category from input
    String expenseCategory = 'Others';
    if (l.contains('internet') || l.contains('wifi')) {
      expenseCategory = 'Utilities';
    } else if (l.contains('electric') || l.contains('power')) {
      expenseCategory = 'Utilities';
    } else if (l.contains('water')) {
      expenseCategory = 'Utilities';
    } else if (l.contains('rent')) {
      expenseCategory = 'Housing';
    } else if (l.contains('food') || l.contains('grocery')) {
      expenseCategory = 'Food & Drinks';
    }

    // Log income
    try {
      final incomeCleanTitle = _cleanTransactionTitle(
        'Salary',
        amount: incomeAmount,
      );
      final incomeTxn = FinanceTransaction(
        id: '${DateTime.now().millisecondsSinceEpoch}_income',
        amount: incomeAmount,
        accountId: account.id,
        accountName: account.name,
        type: 'INCOME',
        category: 'Salary',
        description: incomeCleanTitle,
      );
      await FinanceStorage.addTransaction(incomeTxn);
      results.add("Salary +$_currency${incomeAmount.toStringAsFixed(2)}");
    } catch (e) {
      results.add("Failed to log income: $e");
    }

    // Log expense
    try {
      final expenseCleanTitle = _cleanTransactionTitle(
        expenseCategory,
        amount: expenseAmount,
      );
      final expenseTxn = FinanceTransaction(
        id: '${DateTime.now().millisecondsSinceEpoch}_expense',
        amount: expenseAmount,
        accountId: account.id,
        accountName: account.name,
        type: 'EXPENSE',
        category: expenseCategory,
        description: expenseCleanTitle,
      );
      await FinanceStorage.addTransaction(expenseTxn);
      results.add(
        "$expenseCategory -$_currency${expenseAmount.toStringAsFixed(2)}",
      );
    } catch (e) {
      results.add("Failed to log expense: $e");
    }

    return GabReply(
      results.join('\n\n'),
      quickReplies: const [
        "What is my total balance?",
        "Check account balances",
      ],
    );
  }

  double? _parseAmountWithSlang(String amountStr, String fullText) {
    // Check if the amount has "k" suffix in the full text
    final idx = fullText.toLowerCase().indexOf(amountStr.toLowerCase());
    if (idx != -1) {
      final afterAmount = fullText
          .substring(idx + amountStr.length)
          .toLowerCase()
          .trim();
      if (afterAmount.startsWith('k')) {
        final value = double.tryParse(amountStr);
        if (value != null) return value * 1000;
      }
    }
    return double.tryParse(amountStr);
  }

  Future<GabReply?> _tryBalanceCheck(String n) async {
    // Total balance
    if (n == 'total balance' ||
        n.contains('totalbalance') ||
        n.contains('what is my total balance') ||
        n.contains('how much money do i have') ||
        n.contains('total balance') ||
        n.contains('financial status') ||
        n == 'balance' ||
        n == 'check balance' ||
        n == 'check balances' ||
        n == 'check account balances') {
      final accounts = await FinanceStorage.loadAccounts();
      if (accounts.isEmpty) return _noAccountsReply();
      final netWorth = await FinanceStorage.getNetWorth();
      final lines = accounts
          .map(
            (a) =>
                "${_accountLabel(a)}: $_currency${_formatNumberWithCommas(a.balance.toStringAsFixed(2))}",
          )
          .toList();
      return GabReply(
        "💰 Your Total Balance: $_currency${_formatNumberWithCommas(netWorth.toStringAsFixed(2))}\n\n${lines.join('\n')}",
        quickReplies: const ["Check Cash balance", "What can I cook?"],
      );
    }

    // Individual account
    final accounts = await FinanceStorage.loadAccounts();
    for (final a in accounts) {
      final name = a.name.toLowerCase().trim();
      if (n == '$name balance' ||
          n == 'balance of $name' ||
          n == 'check $name' ||
          n == 'check $name balance' ||
          (n.contains('how much') && n.contains(name))) {
        return GabReply(
          "${_accountLabel(a)} balance: $_currency${_formatNumberWithCommas(a.balance.toStringAsFixed(2))}",
          quickReplies: const ["What is my total balance?"],
        );
      }
    }
    return null;
  }

  bool _isUndoCommand(String input) => RegExp(
    r'^(?:please\s+)?(?:undo(?:\s+(?:that|last(?:\s+transaction)?|previous(?:\s+transaction)?))?|revert(?:\s+(?:that|last transaction|previous transaction))?|delete last transaction|remove last transaction|erase that|mali|wrong)$',
  ).hasMatch(input.trim());

  Future<GabReply> _undoTransactions(List<String> transactionIds) async {
    final deletedTransactions = <FinanceTransaction>[];
    for (final id in transactionIds.reversed) {
      final transaction = await FinanceStorage.deleteTransaction(id);
      if (transaction != null) deletedTransactions.add(transaction);
    }
    if (deletedTransactions.isEmpty) {
      return const GabReply(
        'There is no recent transaction to undo.',
        quickReplies: ['What is my total balance?'],
      );
    }

    final accounts = await FinanceStorage.loadAccounts();
    final details = deletedTransactions
        .map((transaction) {
          if (transaction.isTransfer &&
              transaction.destinationAccountId != null) {
            final source = accounts.firstWhere(
              (item) => item.id == transaction.accountId,
            );
            final destination = accounts.firstWhere(
              (item) => item.id == transaction.destinationAccountId,
            );
            return '${transaction.description} transfer reversed.\n'
                '${_accountLabel(source)} balance: $_currency${_formatNumberWithCommas(source.balance.toStringAsFixed(2))}\n'
                '${_accountLabel(destination)} balance: $_currency${_formatNumberWithCommas(destination.balance.toStringAsFixed(2))}';
          }
          final account = accounts.where(
            (item) => item.id == transaction.accountId,
          );
          final accountLabel = account.isEmpty
              ? transaction.accountName
              : _accountLabel(account.first);
          final balanceLine = account.isEmpty
              ? ''
              : '\nNew balance: $_currency${_formatNumberWithCommas(account.first.balance.toStringAsFixed(2))}';
          return '${transaction.description} removed.\n$accountLabel balance restored.$balanceLine';
        })
        .join('\n\n');

    return GabReply(
      '\u{1F504} Transaction Undo!\n\n$details',
      quickReplies: const [
        'What is my total balance?',
        'Check account balances',
      ],
    );
  }

  Future<GabReply?> _tryCorrection(String n) async {
    final l = n.toLowerCase();

    // Check for correction keywords
    final correctionKeywords = [
      'change that',
      'actually',
      'correct that',
      'wait',
      'no wait',
      'not really',
      'mistake',
      'wrong',
    ];

    if (!correctionKeywords.any((k) => l.contains(k))) {
      return null;
    }

    // Try to extract the new amount
    final newAmount = _extractAmountWithSlang(n);
    if (newAmount == null) {
      return GabReply(
        "⚠️ I couldn't find the new amount. Please specify the correct amount.",
        quickReplies: const ["What is my total balance?"],
      );
    }

    // Get the last transaction
    final transactions = await FinanceStorage.loadTransactions();
    if (transactions.isEmpty) {
      return GabReply(
        "⚠️ No transactions to correct.",
        quickReplies: const ["What is my total balance?"],
      );
    }

    final lastTxn = transactions.last;
    if (lastTxn.isTransfer) {
      return const GabReply(
        '⚠️ Transfers cannot be corrected as income or expenses. Undo the transfer and record it again with the correct details.',
        quickReplies: ['What is my total balance?'],
      );
    }

    // Calculate the difference
    final oldAmount = lastTxn.amount;
    final difference = newAmount - oldAmount;

    // Delete the old transaction
    await FinanceStorage.deleteLastTransaction();

    // Create a new transaction with the corrected amount
    final accounts = await FinanceStorage.loadAccounts();
    final account = accounts.firstWhere(
      (a) => a.id == lastTxn.accountId,
      orElse: () => accounts.first,
    );

    final correctedTxn = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: newAmount,
      accountId: account.id,
      accountName: account.name,
      type: lastTxn.type,
      category: lastTxn.category,
      description: lastTxn.description,
    );

    try {
      await FinanceStorage.addTransaction(correctedTxn);

      final type = lastTxn.type == 'INCOME' ? 'income' : 'expense';
      final diffText = difference > 0
          ? '+$_currency${difference.toStringAsFixed(2)}'
          : '-$_currency${difference.abs().toStringAsFixed(2)}';

      return GabReply(
        "✅ Corrected!\n\nUpdated $type from $_currency${oldAmount.toStringAsFixed(2)} to $_currency${newAmount.toStringAsFixed(2)}\nAdjustment: $diffText\nAccount: ${account.name}",
        quickReplies: const [
          "What is my total balance?",
          "Check account balances",
        ],
      );
    } catch (e) {
      return GabReply(
        "⚠️ Failed to correct transaction: $e",
        quickReplies: const ["What is my total balance?"],
      );
    }
  }

  // ═══════════════════════════════════════════════
  //  BILLS HANDLERS
  // ═══════════════════════════════════════════════

  Future<GabReply> _weeklyBillsReply() async {
    final bills = await BillStorage.loadBills();
    _cookingEngine.updateBills(bills);
    final reply = _cookingEngine.handle('total bills this week');
    return _fromGab(reply);
  }

  Future<GabReply> _billsSummaryReply() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bills = (await BillStorage.loadBills())
        .where(
          (bill) =>
              !bill.isIncome &&
              !bill.isPaid &&
              !DateTime(
                bill.dueDate.year,
                bill.dueDate.month,
                bill.dueDate.day,
              ).isBefore(today),
        )
        .toList();
    final billIds = bills.map((bill) => bill.id).toSet();
    final events = (await FutureEventStorage.loadEvents())
        .where(
          (event) =>
              event.type == 'bill' &&
              event.status == 'pending' &&
              !event.isCompleted &&
              !DateTime(
                event.scheduledDate.year,
                event.scheduledDate.month,
                event.scheduledDate.day,
              ).isBefore(today) &&
              !billIds.contains('future_${event.id}'),
        )
        .toList();
    final upcoming = [
      ...bills.map(
        (bill) => FutureEvent(
          id: bill.id,
          amount: bill.amount,
          category: bill.type,
          description: bill.type,
          scheduledDate: bill.dueDate,
          type: 'bill',
          status: 'pending',
          frequency: bill.frequency,
        ),
      ),
      ...events,
    ]..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    if (upcoming.isEmpty) {
      return const GabReply('You have no upcoming bills.');
    }
    return GabReply('📅 Upcoming Events\n${_formatScheduledEvents(upcoming)}');
  }

  // ═══════════════════════════════════════════════
  //  INTENT DETECTION HELPERS
  // ═══════════════════════════════════════════════

  bool _hasAllocationUpdateWord(String text) => RegExp(
    r'\b(?:update|change|set|adjust|edit|revise|make|modify|reset|raise|lower|increase|decrease)\b',
  ).hasMatch(text);

  bool _hasAllocationBudgetWord(String text) => RegExp(
    r'\b(?:budget|allocation|allowance)\b|\bspending\s+(?:limit|cap)\b',
  ).hasMatch(text);

  String? _allocationPeriodFromText(String text) {
    if (RegExp(r'\b(?:week|weekly)\b').hasMatch(text)) return 'weekly';
    if (RegExp(r'\b(?:month|monthly)\b').hasMatch(text)) return 'monthly';
    if (RegExp(r'\b(?:day|daily)\b').hasMatch(text)) return 'daily';
    return null;
  }

  Future<GabReply?> _trySetDailyAllocation(String input) async {
    final normalized = input
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (RegExp(
      r'\b(?:spent|spend|bought|paid|purchased|charged)\b',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return null;
    }

    final period = _allocationPeriodFromText(normalized);
    final amount = _parseExpenseAmount(normalized);
    final matchesRuleA =
        _hasAllocationUpdateWord(normalized) &&
        _hasAllocationBudgetWord(normalized);
    final matchesRuleB =
        RegExp(
          r'\bmy\s+(?:(?:daily|weekly|monthly)\s+)?(?:allocation|budget|allowance)\b',
        ).hasMatch(normalized) &&
        period != null;
    final acceptedBudgetStatement =
        _hasAllocationBudgetWord(normalized) &&
        period != null &&
        amount != null &&
        RegExp(r'\b(?:is|will\s+be)\b').hasMatch(normalized);

    if (!matchesRuleA && !matchesRuleB && !acceptedBudgetStatement) {
      return null;
    }

    if (period == null) {
      _pendingAllocationPeriod = null;
      _step = GabStep.awaitingAllocationPeriod;
      return const GabReply(
        'Which budget would you like to update: daily, weekly, or monthly?',
      );
    }
    _pendingAllocationPeriod = period;
    if (amount == null || !amount.isFinite || amount <= 0) {
      _step = GabStep.awaitingAllocationAmount;
      return const GabReply('What amount would you like to set?');
    }

    return await _saveAllocation(period, amount);
  }

  Future<GabReply> _handleAllocationFlow(String input) async {
    if (_step == GabStep.awaitingAllocationPeriod) {
      final period = _allocationPeriodFromText(input.toLowerCase().trim());
      if (period == null) {
        return const GabReply(
          'Which budget would you like to update: daily, weekly, or monthly?',
        );
      }
      _pendingAllocationPeriod = period;
      _step = GabStep.awaitingAllocationAmount;
      return const GabReply('What amount would you like to set?');
    }

    final amount = _parseExpenseAmount(input);
    if (amount == null || !amount.isFinite || amount <= 0) {
      return const GabReply('What amount would you like to set?');
    }
    return await _saveAllocation(_pendingAllocationPeriod ?? 'daily', amount);
  }

  Future<GabReply> _saveAllocation(String period, double amount) async {
    final dailyAmount = switch (period) {
      'weekly' => amount / 7,
      'monthly' => amount / 30,
      _ => amount,
    };
    await SettingsService().setDailySpendingAllocation(dailyAmount);
    _resetState();
    final formattedAmount = _formatNumberWithCommas(amount.toStringAsFixed(2));
    return GabReply(
      '✅ Done! Your $period budget is now P $formattedAmount.',
      quickReplies: const ['Show my budget', 'What is my total balance?'],
    );
  }

  GabReply? _tryBudgetValueAsk(String input) {
    final n = input.toLowerCase();
    if (_hasAllocationUpdateWord(n) ||
        !_hasAllocationBudgetWord(n) ||
        !RegExp(r'\b(?:what|how\s+much|show|tell\s+me)\b').hasMatch(n)) {
      return null;
    }
    final period = _allocationPeriodFromText(n) ?? 'daily';
    final dailyAmount = SettingsService().dailySpendingAllocation;
    final amount = switch (period) {
      'weekly' => dailyAmount * 7,
      'monthly' => dailyAmount * 30,
      _ => dailyAmount,
    };
    final formattedAmount = _formatNumberWithCommas(amount.toStringAsFixed(2));
    return GabReply('Your $period budget is P $formattedAmount.');
  }

  GabReply? _tryBudgetConcernReply(String input) {
    final n = input.toLowerCase();
    if (_hasAllocationBudgetWord(n) &&
        RegExp(r'\b(?:too\s+small|too\s+low|not\s+enough)\b').hasMatch(n) &&
        !_hasAllocationUpdateWord(n)) {
      return const GabReply('I hear you. Would you like to update it?');
    }
    return null;
  }

  GabReply? _tryAmbiguousAmount(String n) {
    // If the message has an amount but slipped past expense, income, and allocation rules,
    // we should explicitly ask the user rather than guessing or letting the fallback catch it.
    final amount = _extractAmountWithSlang(n);
    if (amount != null && amount > 0) {
      return const GabReply(
        "Do you want to log this as an expense, or update your daily allocation?",
        quickReplies: ["Log as expense", "Update allocation"],
      );
    }
    return null;
  }

  bool _isWeeklyBillAsk(String n) =>
      (n.contains('how much') && n.contains('bill')) ||
      n.contains('total bills this week') ||
      n.contains('bills this week');

  bool _isBillAsk(String n) =>
      n.contains('upcoming bills') ||
      n.contains('do i have bills') ||
      n.contains('any bills') ||
      n.contains('bayad') ||
      n.contains('overdue');

  bool _isUpcomingBillsInquiry(String n) => RegExp(
    r'\b(?:upcoming\s+bills?|do i have (?:any )?bills?|any bills|what bills are due)\b',
  ).hasMatch(n);

  bool _isFreshQuestion(String input) =>
      input.contains('?') ||
      RegExp(
        r'^(?:what|why|how|where|when|who|which|do|does|did|can|could|would|is|are|show|list|check|tell me)\b',
      ).hasMatch(input) ||
      _isCookingAsk(input) ||
      _isMealPlanAsk(input) ||
      _isSpendingAsk(input) ||
      _isBudgetAsk(input) ||
      _isAnalyticsAsk(input) ||
      _isWeeklyBillAsk(input) ||
      _isBillAsk(input);

  bool _isSpendingAsk(String n) =>
      n.contains('spend') ||
      n.contains('spending') ||
      n.contains('gastos') ||
      n.contains('purchase') ||
      n.contains('how much did i');

  bool _isBreakdownAsk(String n) =>
      n == 'yes' || n == 'oo' || n.contains('breakdown') || n.contains('show');

  bool _isBudgetAsk(String n) =>
      n.contains('budget') ||
      n.contains('limit') ||
      n.contains('magkano nalang');

  bool _isAnalyticsAsk(String n) =>
      n.contains('analytics') ||
      n.contains('insight') ||
      n.contains('habit') ||
      n.contains('chart') ||
      n.contains('summary');

  bool _isMealPlanAsk(String n) =>
      n.contains('meal plan') ||
      n.contains('plan my meals') ||
      n.contains('meal prep');

  bool _isCookingAsk(String n) =>
      n.contains('cook') ||
      n.contains('recipe') ||
      n.contains('dish') ||
      n.contains('ulam') ||
      n.contains('luto') ||
      n.contains('kain') ||
      n.contains('suggest') ||
      n.contains('breakfast') ||
      n.contains('lunch') ||
      n.contains('dinner') ||
      n.contains('snack') ||
      n.contains('merienda') ||
      n.contains('hapunan') ||
      n.contains('almusal') ||
      n.contains('tanghalian') ||
      n.contains('what can i') ||
      n.contains('midnight');

  bool _isCravingKeyword(String n) =>
      n == 'healthy' ||
      n == 'soupy' ||
      n == 'spicy' ||
      n == 'anything' ||
      n == 'sabaw' ||
      n == 'maanghang' ||
      n == 'kahit ano' ||
      n.contains('fridge') ||
      n.contains('ref');

  // ═══════════════════════════════════════════════
  //  FINANCE CATEGORY CLASSIFIERS
  // ═══════════════════════════════════════════════

  String _categorizeExpense(String desc) {
    final l = desc.toLowerCase();
    final billLabel = billLabelForExpense(desc);
    if (billLabel != null) return billLabel;
    if (_matchAny(l, [
      'coffee',
      'food',
      'drinks',
      'dinner',
      'lunch',
      'breakfast',
      'snack',
      'restaurant',
      'milk',
      'grocery',
      'groceries',
      'burger',
      'starbucks',
      'milktea',
      'milk tea',
    ])) {
      return 'Food & Drinks';
    }
    if (_matchAny(l, [
      'gas',
      'transport',
      'taxi',
      'grab',
      'fare',
      'bus',
      'jeep',
      'jeepney',
      'train',
      'ride',
      'toll',
    ])) {
      return 'Transportation';
    }
    if (_matchAny(l, [
      'rent',
      'electricity',
      'water',
      'internet',
      'wifi',
      'load',
      'bill',
      'utility',
      'utilities',
      'power',
    ])) {
      return 'Bills & Utilities';
    }
    if (_matchAny(l, [
      'movie',
      'netflix',
      'game',
      'gaming',
      'cinema',
      'concert',
      'steam',
      'spotify',
      'arcade',
    ])) {
      return 'Entertainment';
    }
    if (_matchAny(l, [
      'shirt',
      'clothes',
      'shoes',
      'shopping',
      'mall',
      'lazada',
      'shopee',
    ])) {
      return 'Shopping';
    }
    return 'Others';
  }

  String _categorizeIncome(String desc) {
    final l = desc.toLowerCase();
    if (_matchAny(l, ['gave me', 'gift', 'regalo'])) {
      return 'Gift';
    }
    if (_matchAny(l, ['salary', 'sweldo', 'paycheck'])) {
      return 'Salary';
    }
    if (_matchAny(l, ['freelance', 'sideline', 'gig', 'project'])) {
      return 'Freelance';
    }
    if (_matchAny(l, [
      'invest',
      'investment',
      'stocks',
      'crypto',
      'dividend',
    ])) {
      return 'Investment';
    }
    if (_matchAny(l, ['allowance', 'baon', 'padala'])) {
      return 'Allowance';
    }
    if (_matchAny(l, [
      'reimburse',
      'refund',
      'paid back',
      'pay back',
      'debt',
      'utang',
    ])) {
      return 'Reimbursement';
    }
    if (_matchAny(l, ['interest', 'dividend', 'payout'])) {
      return 'Passive Income';
    }
    return 'Others';
  }

  bool _matchAny(String input, List<String> keywords) =>
      keywords.any(input.contains);

  // ═══════════════════════════════════════════════
  //  ACCOUNT MATCHING
  // ═══════════════════════════════════════════════

  Account? _findAccount(String name, List<Account> accounts) {
    final l = name.toLowerCase().trim();
    if (l.isEmpty) return null;
    for (final a in accounts) {
      if (a.name.toLowerCase().trim() == l) return a;
    }
    for (final a in accounts) {
      final al = a.name.toLowerCase();
      if (al.contains(l) || l.contains(al)) return a;
    }
    return null;
  }

  Account? _detectAccountFromText(String text, List<Account> accounts) {
    final l = text.toLowerCase();
    // Try to match exact account names first (e.g. "Bank", "GCash", "Cash")
    for (final a in accounts) {
      final name = a.name.toLowerCase().trim();
      if (l.contains(name)) return a;
    }
    // Try to match common patterns
    if (l.contains('gcash')) {
      for (final a in accounts) {
        if (a.name.toLowerCase().contains('gcash')) return a;
      }
    }
    if (l.contains('maya')) {
      for (final a in accounts) {
        if (a.name.toLowerCase().contains('maya')) return a;
      }
    }
    if (l.contains('cash')) {
      for (final a in accounts) {
        if (a.name.toLowerCase().contains('cash')) return a;
      }
    }
    if (l.contains('psbank') || l.contains('ps bank')) {
      for (final a in accounts) {
        if (a.name.toLowerCase().contains('psbank')) return a;
      }
    }
    if (l.contains('bank') || l.contains('bdo') || l.contains('landbank')) {
      for (final a in accounts) {
        final name = a.name.toLowerCase();
        if (name.contains('bank') ||
            name.contains('bdo') ||
            name.contains('landbank')) {
          return a;
        }
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════
  //  SLANG & AMOUNT EXTRACTION
  // ═══════════════════════════════════════════════

  double? _extractAmountWithSlang(String text) {
    final l = text.toLowerCase();

    // Handle "m" for millions (e.g., "1m", "1.5m", "10m")
    final mMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d+)?)\s*m\b').firstMatch(l);
    if (mMatch != null) {
      final value = double.tryParse(mMatch.group(1)!.replaceAll(',', ''));
      if (value != null) return value * 1000000;
    }

    // Handle "k" for thousands (e.g., "2k", "5k", "10k")
    final kMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d+)?)\s*k\b').firstMatch(l);
    if (kMatch != null) {
      final value = double.tryParse(kMatch.group(1)!.replaceAll(',', ''));
      if (value != null) return value * 1000;
    }

    // Handle regular amounts
    final amountMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d+)?)').firstMatch(l);
    if (amountMatch != null) {
      return double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    }

    return null;
  }

  String _extractEntity(String text) {
    final l = text.toLowerCase();

    // Common Filipino entities/relationships
    final entities = [
      'papi',
      'daddy',
      'dad',
      'father',
      'tatay',
      'ama',
      'mom',
      'mommy',
      'mother',
      'momma',
      'nanay',
      'ina',
      'brother',
      'bro',
      'kuya',
      'bunso',
      'sister',
      'sis',
      'ate',
      'friend',
      'bestfriend',
      'bestie',
      'boss',
      'manager',
      'supervisor',
    ];

    for (final entity in entities) {
      if (l.contains(entity)) {
        return entity[0].toUpperCase() + entity.substring(1);
      }
    }

    // Try to extract proper names (capitalized words)
    final nameMatch = RegExp(r'\b[A-Z][a-z]+\b').firstMatch(text);
    if (nameMatch != null) {
      return nameMatch.group(0)!;
    }

    return '';
  }

  String _extractExpenseItemFragment(String text, Account? account) {
    var item = text.toLowerCase();

    item = item.replaceAll(
      RegExp(r'\b\d+(?:,\d{3})*(?:\.\d+)?\s*[km]?\b', caseSensitive: false),
      ' ',
    );
    item = item.replaceAll(
      RegExp(r'\b(?:pesos|peso|php|bucks|dollars?)\b', caseSensitive: false),
      ' ',
    );

    if (account != null) {
      item = item.replaceAll(
        RegExp(RegExp.escape(account.name), caseSensitive: false),
        ' ',
      );
    }

    final accountWords = [
      'gcash',
      'maya',
      'paymaya',
      'cash',
      'bank',
      'bdo',
      'landbank',
      'psbank',
      'wallet',
      'card',
      'account',
    ];
    for (final word in accountWords) {
      item = item.replaceAll(
        RegExp(r'\b' + word + r'\b', caseSensitive: false),
        ' ',
      );
    }

    item = item.replaceAll(
      RegExp(
        r'\b(?:spend|spent|paid|cost|buy|bought|purchase|purchased|charge|charged|gastos|expense|bumili|add|log|logged|minus|deduct|spending|from|using|in|through|with|via|on|for|my|me|i|today|yesterday|budget|allocation)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    item = item.replaceAll(RegExp(r'[^\w\s]'), ' ');
    item = item.replaceAll(RegExp(r'\s+'), ' ').trim();
    return item;
  }

  bool _looksLikeExpenseFragment(String text) {
    final l = text.toLowerCase().trim();
    if (l.isEmpty || _isIncomeIntent(l)) return false;

    final amount = _extractAmountWithSlang(l);
    final itemAfterAmount = _extractExpenseItemFragment(l, null);
    if (amount != null && itemAfterAmount.isNotEmpty) return true;

    final mentionsAccount = RegExp(
      r'\b(?:gcash|maya|paymaya|cash|bank|bdo|landbank|psbank|wallet|card)\b',
      caseSensitive: false,
    ).hasMatch(l);
    return mentionsAccount && itemAfterAmount.isNotEmpty;
  }

  String _titleCase(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    return words
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  String _extractDebtRepaymentDescription(String text) {
    final lower = text.toLowerCase();
    final toMatch = RegExp(
      r"\b(?:to|for)\s+([a-z][\w'-]*)",
      caseSensitive: false,
    ).firstMatch(lower);
    final backMatch = RegExp(
      r"\b(?:paid|pay|repaid|repay)\s+([a-z][\w'-]*)",
      caseSensitive: false,
    ).firstMatch(lower);
    final name = toMatch?.group(1) ?? backMatch?.group(1);
    if (name != null) {
      final blocked = {'the', 'my', 'a', 'an', 'back'};
      if (!blocked.contains(name)) return '${_titleCase(name)} Debt';
    }
    return 'Debt Repayment';
  }

  bool _isUserDebtRepayment(String text) {
    final l = text.toLowerCase();
    if (RegExp(
      r'\b(?:paid|pay|repaid|repay|settled)\s+(?:me|his|her|their)\b',
    ).hasMatch(l)) {
      return false;
    }
    final hasDebtTerm = RegExp(
      r'\b(?:debt|loan|utang)\b',
      caseSensitive: false,
    ).hasMatch(l);
    final hasRepaymentVerb = RegExp(
      r'\b(?:paid|pay|repaid|repay|settled)\b',
      caseSensitive: false,
    ).hasMatch(l);
    if (!hasRepaymentVerb) return false;
    if (hasDebtTerm &&
        RegExp(r'\b(?:i|my|mine)\b', caseSensitive: false).hasMatch(l)) {
      return true;
    }
    return RegExp(
      r'\b(?:paid|pay|repaid|repay)\b.{0,30}\b(?:back|settled|to)\b',
      caseSensitive: false,
    ).hasMatch(l);
  }

  bool _isIncomeIntent(String text) {
    final l = text.toLowerCase();
    if (_isUserDebtRepayment(l)) return false;

    // Strongly classified income indicators
    final List<String> strongIncomeKeywords = [
      'received',
      'recieved',
      'got paid',
      'get paid',
      'earned',
      'just got',
      'was paid',
      'allowance',
      'salary',
      'sweldo',
      'sahod',
      'payroll',
      'bonus',
      'refund',
      'tax refund',
      'sold',
      'sale',
      'preloved',
      'inflow',
      'interest',
      'deposit',
      'deposits',
      'freelance',
      'sideline',
      'gig',
    ];

    if (strongIncomeKeywords.any((k) => l.contains(k))) return true;

    // Phrase structures for incoming money:
    // e.g. "Dad gave me 500", "Kuya sent 200", "Mark paid me back"
    if (l.contains('gave me') ||
        l.contains('handed me') ||
        l.contains('donated to me') ||
        l.contains('sent me') ||
        l.contains('paid me') ||
        l.contains('paid his') ||
        l.contains('paid her') ||
        l.contains('paid their') ||
        l.contains('sent his') ||
        l.contains('sent her') ||
        l.contains('debt') ||
        l.contains('utang') ||
        l.contains('bayad') && l.contains('utang') ||
        l.contains('pay back') ||
        l.contains('paid back') ||
        l.contains('na-receive') ||
        l.contains('pumasok') ||
        l.contains('dumating') ||
        l.contains('pax me') ||
        l.contains('added') && l.contains('to my') ||
        l.contains('got') && !l.contains('spent') && !l.contains('paid')) {
      return true;
    }

    return false;
  }

  bool _isExpenseIntent(String text) {
    // If it's classified as income, it's not expense
    if (_isIncomeIntent(text)) return false;

    final l = text.toLowerCase();
    final hasTransactionVerb = RegExp(
      r'\b(?:spent|bought|paid|purchase|purchased|charged|cost\s+me)\b',
    ).hasMatch(l);
    if (RegExp(r'\b(?:budget|allocation|allowance|limit|cap)\b').hasMatch(l) &&
        !hasTransactionVerb) {
      return false;
    }
    if (RegExp(
          r'\b(?:daily|weekly|monthly)\s+(?:spend|spending|budget|allocation)\b',
        ).hasMatch(l) &&
        !hasTransactionVerb) {
      return false;
    }
    final List<String> expenseKeywords = [
      'spend',
      'spent',
      'paid',
      'cost',
      'buy',
      'bought',
      'gastos',
      'expense',
      'bumili',
      'add',
      'log',
      'logged',
      'minus',
      'deduct',
      'donated',
      'gave',
      'give',
      'pay',
      'sent',
      'lost',
      'given',
      'purchase',
      'got',
      'charged',
    ];

    if (expenseKeywords.any(
      (keyword) => RegExp(r'\b' + RegExp.escape(keyword) + r'\b').hasMatch(l),
    )) {
      return true;
    }
    if (RegExp(r'\bcost\s+me\b').hasMatch(l) ||
        (RegExp(r'\bfor\s+\w+').hasMatch(l) &&
            (_parseExpenseAmount(l) != null ||
                RegExp(r'^\s*for\s+\w+').hasMatch(l)))) {
      return true;
    }

    // If it lacks explicit expense keywords but looks like an amount + item
    if (_looksLikeExpenseFragment(text)) {
      final item = _extractExpenseItemFragment(text, null).toLowerCase();
      // Ensure we don't accidentally treat "Budget 500" as an expense item "budget"
      final budgetWords = ['budget', 'allocation', 'allowance', 'limit', 'cap'];
      if (budgetWords.contains(item)) return false;
      return true;
    }

    return false;
  }

  // ═══════════════════════════════════════════════
  //  FUTURE EVENT DETECTION & PARSING
  // ═══════════════════════════════════════════════

  bool _isFutureTense(String text) {
    final l = _normalizeFutureText(text);

    // GUARD: if the text contains past-tense markers, it is NOT a future event
    final pastMarkers = [
      'yesterday',
      'earlier',
      'just now',
      'already',
      'last night',
      'last week',
      'this morning',
      'this afternoon',
      'ago',
      'kanina',
      'kahapon',
    ];
    if (pastMarkers.any((k) => l.contains(k))) return false;

    final futureKeywords = [
      'is going to',
      'going to pay',
      'going to send',
      'going to transfer',
      'need to pay',
      'needs to pay',
      'have a loan',
      'has a loan',
      'due on',
      'due this',
      'bill drops',
      'will pay',
      'will transfer',
      'will send',
      'drops on',
      'expect on',
      'expecting',
      'scheduled for',
      'this coming',
      'next month',
      'next week',
      'upcoming',
      'future',
      'tomorrow',
      'tom ', // slang for tomorrow (space prevents matching 'tomato' etc.)
      ' tom', // end-of-phrase variant
      "i'm paying",
      "i will pay",
      "i'll pay",
      "i'm going to pay",
      'paying next',
      'paying this',
      'paying on',
    ];
    if (futureKeywords.any((k) => l.contains(k))) return true;

    final hasFutureDateMarker = _hasFutureDateReference(l);
    final hasIncomingAction = RegExp(
      r'\b(?:pay(?:\s+me)?(?:\s+back)?|send|transfer|clear|drop|receive|expect|incoming|salary|allowance|remittance|freelance)\b',
    ).hasMatch(l);
    final hasOutgoingObligation = _isFutureOutgoingObligation(l);

    return hasFutureDateMarker && (hasIncomingAction || hasOutgoingObligation);
  }

  String _normalizeFutureText(String text) {
    var normalized = text.toLowerCase().trim();
    final replacements = <String, String>{
      'tomorow': 'tomorrow',
      'tommorow': 'tomorrow',
      'tmrw': 'tomorrow',
      'tmr': 'tomorrow',
      'electrcity': 'electricity',
      'electricty': 'electricity',
      'eletricity': 'electricity',
      'elctricity': 'electricity',
      'bil ': 'bill ',
      'bll ': 'bill ',
      'homecredit': 'home credit',
      'net flix': 'netflix',
      'netfilx': 'netflix',
      'netfix': 'netflix',
    };

    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _hasFutureDateReference(String text) {
    final l = _normalizeFutureText(text);
    return l.contains('tomorrow') ||
        RegExp(r'\btom\b').hasMatch(l) ||
        l.contains('next week') ||
        l.contains('next month') ||
        RegExp(
          r'\b(?:on|this|next|by|due)\s+(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b',
        ).hasMatch(l) ||
        RegExp(
          r'\bnext\s+month\s+(?:on\s+)?(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b',
        ).hasMatch(l) ||
        RegExp(
          r'\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        ).hasMatch(l);
  }

  DateTime? _parseDateFromText(String text) {
    var l = _normalizeFutureText(text);
    final now = DateTime.now();

    // Normalize 'tom' slang → 'tomorrow' (as a whole word, not part of other words)
    l = l.replaceAllMapped(RegExp(r'\btom\b'), (_) => 'tomorrow');

    // Parse "tomorrow"
    if (l.contains('tomorrow')) {
      return now.add(const Duration(days: 1));
    }

    // Parse "next week"
    if (l.contains('next week')) {
      return now.add(const Duration(days: 7));
    }

    // Parse "next month 12th", "next month on the 12th", etc.
    final nextMonthDayMatch = RegExp(
      r'\bnext\s+month\s+(?:on\s+)?(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?\b',
    ).firstMatch(l);
    if (nextMonthDayMatch != null) {
      final day = int.tryParse(nextMonthDayMatch.group(1)!);
      if (day != null && day >= 1 && day <= 31) {
        return DateTime(now.year, now.month + 1, day);
      }
    }

    // Parse "this 30th", "on the 15th", "on 30th", etc.
    final dayMatch = RegExp(
      r'(?:this|on|by|due)\s+(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?\b',
    ).firstMatch(l);
    if (dayMatch != null) {
      final day = int.tryParse(dayMatch.group(1)!);
      if (day != null && day >= 1 && day <= 31) {
        DateTime date = DateTime(now.year, now.month, day);
        if (date.isBefore(now)) {
          date = DateTime(now.year, now.month + 1, day);
        }
        return date;
      }
    }

    // Parse "Friday", "Sunday", etc.
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    for (int i = 0; i < days.length; i++) {
      if (l.contains(days[i])) {
        int targetDay = i + 1;
        int currentDay = now.weekday;
        int daysUntil = (targetDay - currentDay + 7) % 7;
        if (daysUntil == 0) daysUntil = 7;
        return now.add(Duration(days: daysUntil));
      }
    }

    // Parse "5th of the month"
    final nthMatch = RegExp(
      r'(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(?:the\s+)?month',
    ).firstMatch(l);
    if (nthMatch != null) {
      final day = int.tryParse(nthMatch.group(1)!);
      if (day != null && day >= 1 && day <= 31) {
        DateTime date = DateTime(now.year, now.month, day);
        if (date.isBefore(now)) {
          date = DateTime(now.year, now.month + 1, day);
        }
        return date;
      }
    }

    // Parse "next month"
    if (l.contains('next month')) {
      return DateTime(now.year, now.month + 1, 1);
    }

    // If future keywords detected but no specific date, default to tomorrow
    if (l.contains('tomorrow') ||
        l.contains("i'm paying") ||
        l.contains('i will pay') ||
        l.contains("i'll pay")) {
      return now.add(const Duration(days: 1));
    }

    // Also normalize standalone 'tom' (caught by futureKeywords but needs a date)
    if (RegExp(r'\btom\b').hasMatch(l)) {
      return now.add(const Duration(days: 1));
    }

    return null;
  }

  String _parseFrequency(String text) {
    final l = text.toLowerCase();
    if (l.contains('one time') ||
        l.contains('one-time') ||
        l.contains('once')) {
      return 'Once';
    }
    if (l.contains('every') ||
        l.contains('monthly') ||
        l.contains('each month')) {
      return 'Monthly';
    }
    if (l.contains('weekly') || l.contains('every week')) {
      return 'Weekly';
    }
    return 'Once';
  }

  String _defaultFutureFrequency(String text) {
    final explicit = _parseFrequency(text);
    if (explicit != 'Once' ||
        RegExp(r'\b(?:once|one-time|one time)\b').hasMatch(text)) {
      return explicit;
    }

    return explicit;
  }

  bool _isFutureOutgoingObligation(String text) {
    final l = _normalizeFutureText(text);
    final hasDueLanguage =
        _hasFutureDateReference(l) ||
        RegExp(r'\b(?:due|deadline|drops|coming up|by)\b').hasMatch(l);
    final hasObligation = RegExp(
      r'\b(?:need(?:s)?\s+to\s+pay|have\s+(?:a\s+)?(?:loan|bill|debt)|has\s+(?:a\s+)?(?:loan|bill|debt)|loan|bill|debt|insurance|rent|meralco|electricity|electric|power|water|internet|wifi|subscription|netflix|spotify|credit card|home credit|payment)\b',
    ).hasMatch(l);
    final payOut =
        RegExp(r'\b(?:pay|paying|paid)\b').hasMatch(l) &&
        !RegExp(r'\bpay(?:s|ing|ed)?\s+me\s+back\b').hasMatch(l);

    return (hasObligation || payOut) && hasDueLanguage;
  }

  double? _extractFutureAmount(String text) {
    var scrubbed = _normalizeFutureText(text);

    final datePatterns = [
      RegExp(r'\b(?:this|on|by|due)\s+(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b'),
      RegExp(
        r'\bnext\s+month\s+(?:on\s+)?(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b',
      ),
      RegExp(r'\b\d{1,2}(?:st|nd|rd|th)?\s+(?:of\s+)?(?:the\s+)?month\b'),
      RegExp(
        r'\b(?:next|this)\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month)\b',
      ),
      RegExp(
        r'\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
      ),
    ];

    for (final pattern in datePatterns) {
      scrubbed = scrubbed.replaceAll(pattern, ' ');
    }

    final currencyMatch = RegExp(
      r'(?:₱|php|peso|pesos)\s*(\d+(?:,\d{3})*(?:\.\d+)?)(\s*[km])?\b|(\d+(?:,\d{3})*(?:\.\d+)?)(\s*[km])?\s*(?:₱|php|peso|pesos)\b',
      caseSensitive: false,
    ).firstMatch(scrubbed);
    if (currencyMatch != null) {
      final raw = currencyMatch.group(1) ?? currencyMatch.group(3);
      final suffix = (currencyMatch.group(2) ?? currencyMatch.group(4))
          ?.trim()
          .toLowerCase();
      final parsed = double.tryParse(raw!.replaceAll(',', ''));
      if (parsed != null) {
        if (suffix == 'k') return parsed * 1000;
        if (suffix == 'm') return parsed * 1000000;
        return parsed;
      }
    }

    final actionAmountMatch = RegExp(
      r'\b(?:pay(?:\s+me)?(?:\s+back)?|send|transfer|clear|receive|expect|expecting|salary|allowance|remittance|freelance|incoming|income|payout)\D{0,30}?(\d+(?:,\d{3})*(?:\.\d+)?)(\s*[km])?\b',
      caseSensitive: false,
    ).firstMatch(scrubbed);
    if (actionAmountMatch != null) {
      final parsed = double.tryParse(
        actionAmountMatch.group(1)!.replaceAll(',', ''),
      );
      if (parsed != null) {
        final suffix = actionAmountMatch.group(2)?.trim().toLowerCase();
        if (suffix == 'k') return parsed * 1000;
        if (suffix == 'm') return parsed * 1000000;
        return parsed;
      }
    }

    final amountMatch = RegExp(
      r'\b(\d+(?:,\d{3})*(?:\.\d+)?)(\s*[km])?\b',
      caseSensitive: false,
    ).firstMatch(scrubbed);
    if (amountMatch == null) return null;

    final parsed = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (parsed == null) return null;

    final suffix = amountMatch.group(2)?.trim().toLowerCase();
    if (suffix == 'k') return parsed * 1000;
    if (suffix == 'm') return parsed * 1000000;
    return parsed;
  }

  String _categorizeFutureEvent(String text) {
    final l = text.toLowerCase();

    // Map to allowed categories
    if (_matchAny(l, ['salary', 'sweldo', 'paycheck', 'payday'])) {
      return 'Salary';
    }
    if (_matchAny(l, [
      'freelance',
      'sideline',
      'gig',
      'project',
      'client',
      'milestone',
    ])) {
      return 'Freelance';
    }
    if (_matchAny(l, [
      'business',
      'customer',
      'order',
      'invoice',
      'delivery',
    ])) {
      return 'Business';
    }
    if (_matchAny(l, ['allowance', 'baon', 'padala'])) {
      return 'Allowance';
    }
    if (_matchAny(l, ['scholarship', 'grant'])) {
      return 'Scholarship';
    }
    if (_matchAny(l, [
      'invest',
      'investment',
      'stocks',
      'crypto',
      'debt',
      'pay back',
      'reimburse',
    ])) {
      return 'Investment';
    }
    if (_matchAny(l, ['remittance', 'send money', 'transfer'])) {
      return 'Remittance';
    }

    return 'Salary'; // Default
  }

  String _categorizeFutureOutgoingEvent(String text) {
    final l = _normalizeFutureText(text);

    if (_matchAny(l, ['car loan', 'auto loan', 'vehicle loan'])) {
      return 'car loan';
    }
    if (_matchAny(l, ['debt'])) {
      return 'debt';
    }
    if (_matchAny(l, ['loan'])) {
      return 'loan';
    }
    if (_matchAny(l, ['insurance'])) {
      return 'insurance';
    }
    if (_matchAny(l, ['meralco'])) {
      return 'meralco bill';
    }
    if (_matchAny(l, ['aneco'])) {
      return 'ANECO Electricity';
    }
    if (_matchAny(l, ['cepalco'])) {
      return 'CEPALCO Electricity';
    }
    if (_matchAny(l, ['electric', 'electricity', 'power'])) {
      return 'electricity Bill';
    }
    if (_matchAny(l, ['water'])) {
      return 'water bill';
    }
    if (_matchAny(l, ['internet', 'wifi'])) {
      return 'internet bill';
    }
    if (_matchAny(l, ['rent'])) {
      return 'Rent';
    }
    if (_matchAny(l, ['netflix'])) {
      return 'Netflix';
    }
    if (_matchAny(l, ['spotify'])) {
      return 'Spotify';
    }
    if (_matchAny(l, ['subscription'])) {
      return 'Subscription';
    }
    if (_matchAny(l, ['credit card'])) {
      return 'credit card';
    }
    if (_matchAny(l, ['home credit'])) {
      return 'home credit';
    }

    return _cleanFutureOutgoingTitle(text);
  }

  String _cleanFutureOutgoingTitle(String text) {
    var title = _normalizeFutureText(text);
    final amount = _extractFutureAmount(text);
    title = _removeMappedAmountFromTitle(title, amount);

    // Strip contractions first (i'm, i'll, i've, he's, she's, they're)
    title = title.replaceAll(
      RegExp(r"\bi'[a-z]+\b", caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r"\bhe'[a-z]+\b", caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r"\bshe'[a-z]+\b", caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r"\bwe'[a-z]+\b", caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r"\bthey'[a-z]+\b", caseSensitive: false),
      ' ',
    );

    title = title.replaceAll(
      RegExp(r'\b(?:this|on|by|due)\s+(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b'),
      ' ',
    );
    title = title.replaceAll(
      RegExp(
        r'\b(?:i|my|have|has|a|an|the|need|needs|to|pay|paying|worth|around|about|bill|payment|due|drops|coming|up|for|on|by|tomorrow|next|week|month|going|will|gonna|am|is|are)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) return 'Bill';

    return title
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Future<GabReply?> _tryFutureEvent(String n) async {
    final normalized = _normalizeFutureText(n);
    if (!_isFutureTense(normalized)) return null;

    // Extract the money amount after date markers have been removed, so
    // ordinals like "30th" never become the amount.
    final amount = _extractFutureAmount(normalized);
    if (amount == null || amount <= 0) return null;

    // Parse date
    final scheduledDate = _parseDateFromText(normalized);
    if (scheduledDate == null) {
      return GabReply(
        "⚠️ I couldn't determine the date. Please specify when this event will occur (e.g., 'this 30th', 'on Friday', 'on the 15th').",
        quickReplies: const ["What is my total balance?"],
      );
    }

    final isOutgoing = _isFutureOutgoingObligation(normalized);

    // Parse frequency
    final frequency = _defaultFutureFrequency(normalized);

    // Parse category
    final category = isOutgoing
        ? _categorizeFutureOutgoingEvent(normalized)
        : _categorizeFutureEvent(normalized);

    // Extract entity
    final entity = _extractEntity(normalized);

    // Create description
    String description = category;
    if (entity.isNotEmpty) {
      description = '$entity ($category)';
    }

    // Clean the transaction title
    final cleanTitle = _cleanTransactionTitle(description, amount: amount);

    // Create future event
    final event = FutureEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      category: category,
      description: cleanTitle,
      scheduledDate: scheduledDate,
      type: isOutgoing ? 'bill' : 'income',
      status: 'pending',
      frequency: frequency,
      entity: entity.isNotEmpty ? entity : null,
    );

    try {
      await FutureEventStorage.addEvent(event);

      final bills = await BillStorage.loadBills();
      bills.add(
        Bill(
          id: 'future_${event.id}',
          type: category,
          amount: amount,
          dueDate: scheduledDate,
          isIncome: !isOutgoing,
          frequency: frequency,
        ),
      );
      await BillStorage.saveBills(bills);

      // Load accounts to show current balance of detected account
      final accounts = await FinanceStorage.loadAccounts();
      final detectedAcc = _detectAccountFromText(normalized, accounts);
      final amountStr = _formatNumberWithCommas(amount.toStringAsFixed(2));
      final dateStr = _formatDate(scheduledDate);

      if (isOutgoing) {
        // Outgoing: show current balance, and projected balance after execution
        final accLine = detectedAcc != null
            ? '${_accountLabel(detectedAcc)} (Current Balance: $_currency${_formatNumberWithCommas(detectedAcc.balance.toStringAsFixed(2))})'
            : 'Account not specified';
        final projectedBalance = detectedAcc != null
            ? _formatNumberWithCommas(
                (detectedAcc.balance - amount).toStringAsFixed(2),
              )
            : 'N/A';
        final frequencyNote = frequency == 'Once'
            ? ''
            : '\nFrequency: $frequency';

        return GabReply(
          '📅 Bill Scheduled!\n\n$cleanTitle                                      -$_currency$amountStr\n$accLine\nScheduled for: $dateStr$frequencyNote\n\nNew Balance after execution: $_currency$projectedBalance',
          quickReplies: const [
            "Show upcoming events",
            "What is my total balance?",
          ],
          highlightColor: 'red',
        );
      } else {
        // Incoming: show current balance, and projected balance after execution
        final accLine = detectedAcc != null
            ? '${_accountLabel(detectedAcc)} (Current Balance: $_currency${_formatNumberWithCommas(detectedAcc.balance.toStringAsFixed(2))})'
            : 'Account not specified';
        final projectedBalance = detectedAcc != null
            ? _formatNumberWithCommas(
                (detectedAcc.balance + amount).toStringAsFixed(2),
              )
            : 'N/A';
        final frequencyNote = frequency == 'Once'
            ? ''
            : '\nFrequency: $frequency';

        return GabReply(
          '📅 Income Scheduled!\n\n$cleanTitle                                   +$_currency$amountStr\n$accLine\nScheduled for: $dateStr$frequencyNote\n\nNew Balance after execution: $_currency$projectedBalance',
          quickReplies: const [
            "What is my total balance?",
            "Show upcoming events",
          ],
          highlightColor: 'green',
        );
      }
    } catch (e) {
      return GabReply(
        "⚠️ Failed to schedule future event: $e",
        quickReplies: const ["What is my total balance?"],
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    final daysDiff = targetDate.difference(today).inDays;

    if (daysDiff == 0) return 'today';
    if (daysDiff == 1) return 'tomorrow';
    if (daysDiff < 7) return 'this ${_getDayName(date.weekday)}';
    if (daysDiff < 14) return 'next ${_getDayName(date.weekday)}';

    return '${date.day}${_getOrdinalSuffix(date.day)} of ${_getMonthName(date.month)}';
  }

  String _getDayName(int weekday) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday];
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month];
  }

  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  // ═══════════════════════════════════════════════
  //  TRANSACTION TITLE CLEANING
  // ═══════════════════════════════════════════════

  String _cleanTransactionTitle(String rawText, {double? amount}) {
    String title = rawText.trim();

    // clean_ui_title rule: once a number is mapped to Amount, it must be
    // deleted from the title. Keep only the entity, category, or source noun.
    //
    // Few-shot mappings:
    // "my wife gave me 300" -> amount 300 -> "Wife"
    // "i paid 2000 from rent" -> amount 2000 -> "Rent"
    // "John paid me back 500" -> amount 500 -> "John"
    // "got my 15k sa sweldo" -> amount 15000 -> "Salary"
    title = _removeMappedAmountFromTitle(title, amount);

    // Remove pronouns
    final pronouns = [
      'i',
      'my',
      'me',
      'mine',
      'he',
      'him',
      'his',
      'she',
      'her',
      'hers',
      'they',
      'them',
      'their',
      'we',
      'us',
      'our',
    ];
    for (final pronoun in pronouns) {
      title = title.replaceAll(
        RegExp(r'\b' + pronoun + r'\b', caseSensitive: false),
        '',
      );
    }

    // Remove transaction action verbs
    final actionVerbs = [
      'paid',
      'pay',
      'sent',
      'send',
      'received',
      'receive',
      'got',
      'get',
      'transferred',
      'transfer',
      'spent',
      'spend',
      'bought',
      'buy',
      'purchased',
      'purchase',
      'gave',
      'give',
      'handed',
      'hand',
      'donated',
      'donate',
    ];
    for (final verb in actionVerbs) {
      title = title.replaceAll(
        RegExp(r'\b' + verb + r'\b', caseSensitive: false),
        '',
      );
    }

    // Remove structural prepositions (English and Filipino)
    final prepositions = [
      'from',
      'for',
      'to',
      'with',
      'by',
      'at',
      'on',
      'in',
      'of',
      'sa',
      'galing',
      'para',
      'kay',
      'mula',
      'upang',
    ];
    for (final prep in prepositions) {
      title = title.replaceAll(
        RegExp(r'\b' + prep + r'\b', caseSensitive: false),
        '',
      );
    }

    // Remove time/date words
    final timeWords = [
      'yesterday',
      'today',
      'tomorrow',
      'ago',
      'now',
      'earlier',
      'later',
      'last',
      'next',
      'recently',
    ];
    for (final timeWord in timeWords) {
      title = title.replaceAll(
        RegExp(r'\b' + timeWord + r'\b', caseSensitive: false),
        '',
      );
    }

    // Remove currency symbols and amounts
    title = title.replaceAll(RegExp(r'[₱$€£¥]'), '');
    title = title.replaceAll(
      RegExp(r'\b\d+(?:,\d+)*(?:\.\d+)?\s*[km]?\b', caseSensitive: false),
      '',
    );

    // Clean up extra spaces and punctuation
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    title = title.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '');

    // Capitalize first letter of each word
    final words = title.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();
    title = capitalizedWords.join(' ');

    // Truncate to max 25 characters
    if (title.length > 25) {
      title = title.substring(0, 25).trim();
      // Don't cut in the middle of a word
      final lastSpace = title.lastIndexOf(' ');
      if (lastSpace > 10) {
        title = title.substring(0, lastSpace);
      }
    }

    // Fallback if title is empty after cleaning
    if (title.isEmpty) {
      title = 'Transaction';
    }

    return title;
  }

  String _removeMappedAmountFromTitle(String rawText, double? amount) {
    var title = rawText;
    if (amount == null || amount <= 0) return title;

    final wholeAmount = amount == amount.roundToDouble();
    final normalized = wholeAmount
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    final candidates = <String>{
      normalized,
      amount.toStringAsFixed(2),
      amount.toStringAsFixed(1),
      _formatNumberWithCommas(normalized),
    };

    if (amount >= 1000 && amount % 1000 == 0) {
      candidates.add('${(amount / 1000).toStringAsFixed(0)}k');
    } else if (amount >= 1000) {
      candidates.add(
        '${(amount / 1000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}k',
      );
    }

    for (final candidate in candidates.where((c) => c.isNotEmpty)) {
      title = title.replaceAll(
        RegExp(
          r'(?<!\w)(?:â‚±|php|peso|pesos)?\s*' +
              RegExp.escape(candidate) +
              r'\s*(?:â‚±|php|peso|pesos)?(?!\w)',
          caseSensitive: false,
        ),
        ' ',
      );
    }

    return title;
  }

  String _formatNumberWithCommas(String value) {
    final parts = value.split('.');
    final whole = parts.first;
    final buffer = StringBuffer();

    for (int i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    if (parts.length > 1) {
      buffer.write('.');
      buffer.write(parts.last);
    }

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════
  //  REPLY HELPERS
  // ═══════════════════════════════════════════════

  GabReply _fromGab(GabCookingReply r) => GabReply(
    r.text,
    extraTexts: r.extraTexts,
    quickReplies: r.quickReplies,
    navigateTo: r.navigateTo,
  );

  GabReply _noAccountsReply() => const GabReply(
    "You don't have any financial accounts set up yet. Visit the Wallet page to create one first!",
    quickReplies: ["What can I cook?"],
  );

  GabReply _helpReply() => const GabReply(
    "Here's everything I can help you with:\n\n"
    "🍳 Cooking\n"
    "'I wanna cook pansit'\n"
    "'Recipe for adobo'\n\n"
    "💰 Finance & Wallet\n"
    "'What is my total balance?'\n"
    "'Spent 150 on coffee from Cash'\n"
    "'Received 25000 salary to Bank Account'\n"
    "'Transfer 500 from Bank to GCash'\n"
    "'Move 300 BDO to Cash'\n"
    "'Transmit 300 GCash' then choose a destination\n"
    "'Cashout 300 GCash to Cash'\n\n"
    "📅 Future Events\n"
    "'I have an upcoming rent this 28'\n"
    "'Expect my 25k salary on the 15th'\n"
    "'I have upcoming shopee this Friday'\n",
  );

  GabReply _fallbackReply() => const GabReply(
    "I'm here to help! Just ask me anything. Type 'help' to see all my commands. 😊",
    quickReplies: ["Help", "What can I cook?", "What is my total balance?"],
  );

  // ---------------------------------------------------------
  // NEW ROBUST EXPENSE FLOW
  // ---------------------------------------------------------
  Future<GabReply> _handleOngoingExpenseFlow(String input) async {
    final n = input.toLowerCase();

    if (_isCancellation(n)) {
      _resetState();
      return const GabReply("Okay, I cancelled that. Nothing was saved.");
    }

    final accounts = await FinanceStorage.loadAccounts();
    if (_step == GabStep.awaitingExpenseAmount) {
      final amount = _parseExpenseAmount(input);
      if (amount == null || !amount.isFinite || amount <= 0) {
        return const GabReply(
          'Please enter a valid amount, for example 250.00.',
        );
      }
      _pendingExpenseAmount = amount;
    } else if (_step == GabStep.awaitingExpenseItem) {
      final item = _extractExpenseItemFragment(input, null);
      if (item.isNotEmpty) {
        _pendingExpenseDescription = _titleCase(item);
        _pendingExpenseCategory = _categorizeExpense(item);
      }
    } else if (_step == GabStep.awaitingExpenseAccount) {
      if (const {
        'ok',
        'okay',
        'sure',
        'kk',
        'ge',
        'aight',
        'sge',
        'g',
        'oks',
      }.contains(n.trim())) {
        return _continueExpenseFlow();
      }
      final wallet = _findExpenseWallet(input, accounts);
      if (wallet == null) {
        return _walletSelectionReply(
          "I couldn't find that wallet. Which one would you like to use?",
          accounts,
        );
      }
      _pendingExpenseAccount = wallet;
    }

    return await _continueExpenseFlow();
  }

  Future<GabReply> _continueExpenseFlow() async {
    if (_pendingExpenseAmount == null) {
      _step = GabStep.awaitingExpenseAmount;
      return const GabReply(
        'How much did you spend from your wallet?',
        quickReplies: ['❌ Cancel', '🔄 Do Something Else'],
      );
    }
    if (_pendingExpenseDescription == null ||
        _pendingExpenseDescription!.trim().isEmpty) {
      _step = GabStep.awaitingExpenseItem;
      return const GabReply(
        'What did you spend it on?',
        quickReplies: ['❌ Cancel', '🔄 Do Something Else'],
      );
    }
    if (_pendingExpenseAccount == null) {
      final accounts = await FinanceStorage.loadAccounts();
      _step = GabStep.awaitingExpenseAccount;
      return _walletSelectionReply(
        'Which wallet did you spend it from?',
        accounts,
        extraQuickReplies: const ['🔄 Do Something Else'],
      );
    }

    final amount = _pendingExpenseAmount!;
    final item = _pendingExpenseDescription!;
    final wallet = _pendingExpenseAccount!;
    final transaction = FinanceTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: amount,
      accountId: wallet.id,
      accountName: wallet.name,
      type: 'EXPENSE',
      category: _pendingExpenseCategory ?? _categorizeExpense(item),
      description: item,
    );

    _step = GabStep.awaitingExpenseAccount;
    try {
      await FinanceStorage.addTransaction(transaction);
      final updatedWallet = (await FinanceStorage.loadAccounts()).firstWhere(
        (account) => account.id == wallet.id,
      );
      final transactions = await FinanceStorage.loadTransactions();
      final now = DateTime.now();
      final spentToday = transactions
          .where(
            (entry) =>
                entry.isExpense &&
                !entry.isTransfer &&
                entry.date.year == now.year &&
                entry.date.month == now.month &&
                entry.date.day == now.day,
          )
          .fold<double>(0, (total, entry) => total + entry.amount);
      final remaining = SettingsService().dailySpendingAllocation - spentToday;
      final amountText = _formatExpenseAmount(amount);
      final remainingText = _formatExpenseAmount(remaining);

      _resetState();
      return GabReply(
        '💸 Expense logged!\n$item  -₱ $amountText\nNew ${wallet.name} Balance: ₱ ${_formatExpenseAmount(updatedWallet.balance)}\nRemaining today: ₱ $remainingText\nAnything else?',
        quickReplies: const [
          '➕ Another Expense',
          '💰 Log Income',
          '💼 Check Balance',
          '👍 Done',
        ],
        transactionNotification: _transactionNotification(
          isIncome: false,
          amount: amount,
          walletName: wallet.name,
          balance: updatedWallet.balance,
        ),
        highlightColor: 'red',
      );
    } catch (error) {
      if (error.toString().contains('Insufficient funds')) {
        _pendingExpenseAccount = null;
        _step = GabStep.awaitingExpenseAccount;
        final accounts = await FinanceStorage.loadAccounts();
        final alternatives = accounts.where(
          (account) => account.id != wallet.id,
        );
        return GabReply(
          '⚠️ ${error.toString()}\nPlease choose another wallet.',
          quickReplies: [
            ..._walletNames(alternatives.toList()),
            '🔄 Do Something Else',
          ],
        );
      }
      return GabReply("⚠️ ${error.toString()}", quickReplies: const ['Cancel']);
    }
  }

  Future<GabReply> _handleClarification(String n) async {
    // Uses the raw input for later context
    final raw = _unclearRawInput ?? n;

    if (n.contains('expense') || n.contains('spend')) {
      _step = GabStep.idle;
      return const GabReply("Okay, tracking expense.");
    } else if (n.contains('budget') || n.contains('update')) {
      _step = GabStep.idle;
      return const GabReply("Okay, updating budget.");
    }

    _unclearRawInput = raw;
    _step = GabStep.awaitingClarification;
    return const GabReply(
      "Would you like to log this as an expense, or update your budget?",
      quickReplies: ['Log Expense', 'Update Budget'],
    );
  }

  // ---------------------------------------------------------
  // SCHEDULED ENTRIES FLOW (BILLS & FUTURE INCOME)
  // ---------------------------------------------------------
  Future<GabReply> _handleScheduledEntryFlow(String input) async {
    if (_pendingScheduledType == 'bill') {
      return await _handleUpcomingBillFlow(input);
    }
    if (_pendingScheduledType == 'income') {
      return await _handleUpcomingIncomeFlow(input);
    }

    final n = input.toLowerCase();

    // 1. CANCEL OR NEW COMMAND
    if (n == 'cancel' ||
        n == 'stop' ||
        n == 'never mind' ||
        n == 'forget it' ||
        n == 'nevermind') {
      _resetState();
      return const GabReply("Okay, I cancelled that. Nothing was saved.");
    }

    if (n.contains('update') && n.contains('budget') || n.contains('spent')) {
      _resetState();
      return _handleMessage(input); // Reroute as a fresh command
    }

    // 2. PARSE MISSING FIELDS
    String nWithoutDate = n;

    if (_pendingScheduledDate == null || _pendingScheduledDate!.isEmpty) {
      final dateMatch = RegExp(
        r'(?:on|due|this|by)\s+([a-z]+\s+\d+|\d{1,2}/\d{1,2}|\d{1,2}(?:th|st|nd|rd)?|\d{1,2}|tomorrow|next\s+[a-z]+)',
      ).firstMatch(n);
      if (dateMatch != null) {
        _pendingScheduledDate = dateMatch.group(1);
        nWithoutDate = n.replaceFirst(dateMatch.group(0)!, '');
      } else {
        // Fallback for just typing a date like "October 15"
        final rawDateMatch = RegExp(
          r'([a-z]+\s+\d+|\d{1,2}/\d{1,2}|tomorrow|next\s+[a-z]+)',
        ).firstMatch(n);
        if (rawDateMatch != null) {
          _pendingScheduledDate = rawDateMatch.group(1);
          nWithoutDate = n.replaceFirst(rawDateMatch.group(0)!, '');
        }
      }
    }

    if (_pendingScheduledAmount == null) {
      double? amount = _extractAmountWithSlang(nWithoutDate);
      if (amount != null && amount > 0) _pendingScheduledAmount = amount;
    }

    if (_pendingScheduledName == null || _pendingScheduledName!.isEmpty) {
      String item = nWithoutDate
          .replaceAll(RegExp(r'\d+(?:\.\d+)?'), '')
          .replaceAll(RegExp(r'october|oct|november|nov|december|dec'), '');
      item = item
          .replaceAll(
            RegExp(
              r'\b(will have|will receive|will get|will be|am getting|expecting|incoming|due|coming|need to pay|have to pay|on|this|by|remind me|i have|my|the|is|a)\b',
            ),
            '',
          )
          .trim();
      if (item.isNotEmpty) _pendingScheduledName = item;
    }

    // 3. ASK FOR MISSING FIELDS
    if (_pendingScheduledName == null || _pendingScheduledName!.isEmpty) {
      _step = GabStep.awaitingScheduledName;
      return GabReply(
        _pendingScheduledType == 'bill'
            ? "What bill is this?"
            : "What kind of incoming money is this?",
      );
    }

    if (_pendingScheduledAmount == null) {
      _step = GabStep.awaitingScheduledAmount;
      return GabReply(
        _pendingScheduledType == 'bill'
            ? "How much is the $_pendingScheduledName?"
            : "How much is your $_pendingScheduledName?",
      );
    }

    if (_pendingScheduledDate == null || _pendingScheduledDate!.isEmpty) {
      _step = GabStep.awaitingScheduledDate;
      return GabReply(
        _pendingScheduledType == 'bill'
            ? "When is the $_pendingScheduledName due?"
            : "On what date will you receive your $_pendingScheduledName?",
      );
    }

    // 4. CONFIRMATION
    final title = _pendingScheduledType == 'bill'
        ? '📅 Bill Added to Calendar!'
        : '💰 Incoming Transaction Added to Calendar!';
    final footer = _pendingScheduledType == 'bill'
        ? 'I will remind you on the due date.'
        : 'I will remind you on the day it arrives.';
    final sign = _pendingScheduledType == 'bill' ? '-₱' : '+₱';

    _resetState();
    return GabReply(
      "$title\n$_pendingScheduledName\t\t$sign${_pendingScheduledAmount!.toStringAsFixed(2)}\nDate:\t\t\t$_pendingScheduledDate\n\n$footer",
      highlightColor: _pendingScheduledType == 'bill' ? 'red' : 'green',
    );
  }

  Future<GabReply> _handleUpcomingBillFlow(String input) async {
    final normalized = _normalizeFutureText(input);
    if (_isCancellation(normalized)) {
      _resetState();
      return const GabReply('Okay, I cancelled that. Nothing was saved.');
    }

    if (_pendingBillDateNeedsConfirmation) {
      if (RegExp(
        r'^(?:yes|yeah|yep|correct|that works|oo)\b',
      ).hasMatch(normalized)) {
        _pendingBillDateNeedsConfirmation = false;
        return await _saveUpcomingBill();
      }
      if (RegExp(r'^(?:no|nope|not that|hindi)\b').hasMatch(normalized)) {
        _pendingBillDateNeedsConfirmation = false;
        _pendingScheduledDateTime = null;
        _pendingScheduledDate = null;
        _step = GabStep.awaitingScheduledDate;
        return GabReply('When is the ${_pendingScheduledName!} bill due?');
      }
      return GabReply(
        'Do you mean ${_formatBillDate(_pendingScheduledDateTime!)}?',
      );
    }

    if (_step == GabStep.awaitingScheduledWallet) {
      final accounts = await FinanceStorage.loadAccounts();
      final wallet = _findMentionedAccount(normalized, accounts);
      if (wallet == null) {
        return _walletSelectionReply(
          "I couldn't find that wallet. Which wallet are you going to use?",
          accounts,
        );
      }
      _pendingScheduledWallet = wallet.name;
      return await _saveUpcomingBill();
    }

    if (input.trim().isNotEmpty &&
        (_step == GabStep.awaitingScheduledName ||
            _step == GabStep.awaitingScheduledAmount ||
            _step == GabStep.awaitingScheduledDate)) {
      final name = _extractUpcomingBillName(normalized);
      if ((_pendingScheduledName == null || _pendingScheduledName!.isEmpty) &&
          name.isNotEmpty) {
        _pendingScheduledName = name;
      }

      if (_pendingScheduledAmount == null) {
        final amount = _extractUpcomingBillAmount(normalized);
        if (amount != null && amount.isFinite && amount > 0) {
          _pendingScheduledAmount = amount;
        }
      }

      if (_pendingScheduledDateTime == null) {
        final date = _parseUpcomingBillDate(
          normalized,
          allowBareDay: _step == GabStep.awaitingScheduledDate,
        );
        if (date != null) {
          if (_isUpcomingBillDayOnly(normalized) && _isDateBeforeToday(date)) {
            final nextMonthStart = DateTime(date.year, date.month + 1, 1);
            final lastDayOfNextMonth = DateTime(
              nextMonthStart.year,
              nextMonthStart.month + 1,
              0,
            ).day;
            final nextMonth = DateTime(
              nextMonthStart.year,
              nextMonthStart.month,
              date.day.clamp(1, lastDayOfNextMonth).toInt(),
            );
            _pendingScheduledDateTime = nextMonth;
            _pendingScheduledDate = _formatBillDate(nextMonth);
            _pendingBillDateNeedsConfirmation = true;
            _step = GabStep.awaitingScheduledDate;
            return GabReply('Do you mean ${_formatBillDate(nextMonth)}?');
          }
          _pendingScheduledDateTime = date;
          _pendingScheduledDate = _formatBillDate(date);
        }
      }
    }

    if (_pendingScheduledName == null || _pendingScheduledName!.isEmpty) {
      _step = GabStep.awaitingScheduledName;
      return const GabReply('What bill is this?');
    }
    if (_pendingScheduledAmount == null) {
      _step = GabStep.awaitingScheduledAmount;
      return GabReply('How much is the ${_pendingScheduledName!} bill?');
    }
    if (_pendingBillRequiresWallet && _pendingScheduledWallet == null) {
      _step = GabStep.awaitingScheduledWallet;
      final accounts = await FinanceStorage.loadAccounts();
      return _walletSelectionReply(
        'Which wallet are you going to use?',
        accounts,
      );
    }
    if (_pendingScheduledDateTime == null) {
      _step = GabStep.awaitingScheduledDate;
      return GabReply('When is the ${_pendingScheduledName!} bill due?');
    }
    return await _saveUpcomingBill();
  }

  String _extractUpcomingBillName(String text) {
    var name = text;
    name = _removeUpcomingBillDate(name);
    name = name.replaceAll(
      RegExp(r'(?<![\w/])\d+(?:,\d{3})*(?:\.\d+)?\s*[km]?\b'),
      ' ',
    );
    name = name.replaceAll(
      RegExp(r'\b(?:p|php|peso|pesos)\b|₱', caseSensitive: false),
      ' ',
    );
    name = name.replaceAll(
      RegExp(
        r'\b(?:i\s+have|my|need\s+to\s+pay|have\s+to\s+pay|remind\s+me(?:\s+to\s+pay)?|pay|is|are|will\s+be|due|on|by|this|the|a|an|of|upcoming|bill|payment)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    name = name.replaceAll(RegExp(r'[^\w\s-]'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return name.toLowerCase();
  }

  double? _extractUpcomingIncomeAmount(String text) {
    final withoutNameNumber = text.replaceAll(
      RegExp(r'\b13th\s+month(?:\s+pay)?\b', caseSensitive: false),
      ' ',
    );
    return _extractUpcomingBillAmount(withoutNameNumber);
  }

  double? _extractUpcomingBillAmount(String text) {
    var amountText = _removeUpcomingBillDate(text);
    final match = RegExp(
      r'(?<![\w/])(\d+(?:,\d{3})*(?:\.\d+)?)(\s*[km])?\b',
      caseSensitive: false,
    ).firstMatch(amountText);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (value == null) return null;
    return switch (match.group(2)?.trim().toLowerCase()) {
      'k' => value * 1000,
      'm' => value * 1000000,
      _ => value,
    };
  }

  DateTime? _parseUpcomingBillDate(String text, {bool allowBareDay = false}) {
    final normalized = _normalizeFutureText(text);
    final now = _clock();
    final monthNames = {
      'january': 1,
      'jan': 1,
      'february': 2,
      'feb': 2,
      'march': 3,
      'mar': 3,
      'april': 4,
      'apr': 4,
      'may': 5,
      'june': 6,
      'jun': 6,
      'july': 7,
      'jul': 7,
      'august': 8,
      'aug': 8,
      'september': 9,
      'sep': 9,
      'sept': 9,
      'october': 10,
      'oct': 10,
      'november': 11,
      'nov': 11,
      'december': 12,
      'dec': 12,
    };

    for (final entry in monthNames.entries) {
      final match = RegExp(
        r'\b' + entry.key + r'\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?\b',
      ).firstMatch(normalized);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final year = int.tryParse(match.group(2) ?? '') ?? now.year;
        return _validCalendarDate(year, entry.value, day);
      }

      final dayFirstMatch = RegExp(
        r'\b(\d{1,2})(?:st|nd|rd|th)?\s+of\s+' +
            entry.key +
            r'(?:,?\s+(\d{4}))?\b',
      ).firstMatch(normalized);
      if (dayFirstMatch != null) {
        final day = int.parse(dayFirstMatch.group(1)!);
        final year = int.tryParse(dayFirstMatch.group(2) ?? '') ?? now.year;
        return _validCalendarDate(year, entry.value, day);
      }
    }

    final numericDate = RegExp(
      r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b',
    ).firstMatch(normalized);
    if (numericDate != null) {
      final month = int.parse(numericDate.group(1)!);
      final day = int.parse(numericDate.group(2)!);
      var year = int.tryParse(numericDate.group(3) ?? '') ?? now.year;
      if (year < 100) year += 2000;
      return _validCalendarDate(year, month, day);
    }

    if (normalized.contains('tomorrow')) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    if (normalized.contains('next week') ||
        RegExp(
          r'\bnext\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        ).hasMatch(normalized)) {
      return _parseDateFromText(normalized);
    }

    final weekdayMatch = RegExp(
      r'\b(?:(?:on|by|this|the|next)\s+)?(?:the\s+)?(mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b',
    ).firstMatch(normalized);
    if (weekdayMatch != null) {
      const weekdayPrefixes = {
        'mon': DateTime.monday,
        'tue': DateTime.tuesday,
        'wed': DateTime.wednesday,
        'thu': DateTime.thursday,
        'fri': DateTime.friday,
        'sat': DateTime.saturday,
        'sun': DateTime.sunday,
      };
      final token = weekdayMatch.group(1)!;
      final target = weekdayPrefixes[token.substring(0, 3)]!;
      var daysUntil = (target - now.weekday + 7) % 7;
      if (daysUntil == 0 &&
          weekdayMatch.group(0)!.trimLeft().startsWith('next ')) {
        daysUntil += 7;
      }
      return DateTime(now.year, now.month, now.day + daysUntil);
    }

    final markedDay = RegExp(
      r'\b(?:on|due|by|this|the)\s+(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?\b',
    ).firstMatch(normalized);
    final bareDay = allowBareDay
        ? RegExp(r'^\s*(\d{1,2})(?:st|nd|rd|th)?\s*$').firstMatch(normalized)
        : null;
    final day = int.tryParse(markedDay?.group(1) ?? bareDay?.group(1) ?? '');
    if (day != null && day >= 1 && day <= 31) {
      return _resolveUpcomingDay(day, now);
    }
    return null;
  }

  DateTime _resolveUpcomingDay(int day, DateTime now) {
    var year = now.year;
    var month = now.month;
    final currentMonthLength = DateTime(year, month + 1, 0).day;
    if (day < now.day || day > currentMonthLength) {
      final nextMonth = DateTime(year, month + 1, 1);
      year = nextMonth.year;
      month = nextMonth.month;
    }

    final targetMonthLength = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, targetMonthLength));
  }

  DateTime? _validCalendarDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  bool _isUpcomingBillDayOnly(String text) {
    if (RegExp(r'\b\d{1,2}/\d{1,2}\b').hasMatch(text) ||
        RegExp(
          r'\b(?:january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)\b',
        ).hasMatch(text) ||
        RegExp(r'\b(?:tomorrow|next\s+week|next\s+\w+day)\b').hasMatch(text)) {
      return false;
    }
    return RegExp(
      r'^\s*(?:(?:on|due|by|this|the)\s+(?:the\s+)?)?\d{1,2}(?:st|nd|rd|th)?\s*$',
    ).hasMatch(text);
  }

  bool _isDateBeforeToday(DateTime date) {
    final now = _clock();
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }

  String _removeUpcomingBillDate(String text) {
    var result = text;
    final monthPattern =
        r'\b(?:january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)\s+\d{1,2}(?:st|nd|rd|th)?(?:,?\s+\d{4})?\b';
    result = result.replaceAll(RegExp(monthPattern, caseSensitive: false), ' ');
    result = result.replaceAll(
      RegExp(
        r'\b\d{1,2}(?:st|nd|rd|th)?\s+of\s+(?:january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)(?:,?\s+\d{4})?\b',
        caseSensitive: false,
      ),
      ' ',
    );
    result = result.replaceAll(
      RegExp(r'\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b'),
      ' ',
    );
    result = result.replaceAll(
      RegExp(
        r'\b(?:next\s+week|next\s+(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)|(?:(?:on|by|this|the|next)\s+)?(?:the\s+)?(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)|tomorrow)\b',
      ),
      ' ',
    );
    result = result.replaceAll(
      RegExp(
        r'\b(?:on|due|by|this|the)\s+(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b',
      ),
      ' ',
    );
    return result;
  }

  String _formatBillDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _billEmoji(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('electric')) return '💡';
    if (normalized.contains('water')) return '💧';
    if (normalized.contains('internet') || normalized.contains('wifi')) {
      return '🌐';
    }
    if (normalized.contains('rent')) return '🏠';
    if (normalized.contains('phone') || normalized.contains('load')) {
      return '📱';
    }
    if (normalized.contains('credit card') || normalized.contains('loan')) {
      return '💳';
    }
    return '📅';
  }

  Future<GabReply> _saveUpcomingBill() async {
    final baseName = _pendingScheduledName!;
    final displayName = cleanBillName(baseName);
    final amount = _pendingScheduledAmount!;
    final date = _pendingScheduledDateTime!;
    final billId = DateTime.now().microsecondsSinceEpoch.toString();
    final category = _categorizeFutureOutgoingEvent(displayName);
    final event = FutureEvent(
      id: billId,
      amount: amount,
      category: category,
      description: displayName,
      scheduledDate: date,
      type: 'bill',
      status: 'pending',
      frequency: 'Once',
      wallet: _pendingScheduledWallet,
    );

    await FutureEventStorage.addEvent(event);
    final bills = await BillStorage.loadBills();
    bills.add(
      Bill(
        id: 'future_$billId',
        type: displayName,
        amount: amount,
        dueDate: date,
        isIncome: false,
        frequency: 'Once',
      ),
    );
    await BillStorage.saveBills(bills);

    final formattedAmount = _formatNumberWithCommas(amount.toStringAsFixed(2));
    final walletLine = _pendingScheduledWallet == null
        ? ''
        : '\nWallet: $_pendingScheduledWallet';
    final confirmation =
        '${_billEmoji(displayName)} Bill Added to Calendar!\n'
        '$displayName\n'
        'Amount: -₱ $formattedAmount\n'
        'Date: ${_formatBillDate(date)}'
        '$walletLine'
        '\n\n'
        'I will remind you on the due date.';
    _resetState();
    return GabReply(confirmation, highlightColor: 'red');
  }

  Future<GabReply?> _tryScheduledEntry(String n) async {
    final incomeNamePattern = RegExp(
      r'\b(?:salary|allowance|commission|bonus|13th\s+month(?:\s+pay)?|refund|freelance\s+payment|business\s+income|rental\s+income|pension|cashback)\b',
    );
    final hasUpcomingMerchant = RegExp(
      r'\bi\s+have\s+(?:an?\s+)?upcoming\s+\w+',
    ).hasMatch(n);
    if (hasUpcomingMerchant && !incomeNamePattern.hasMatch(n)) {
      final name = _extractUpcomingBillName(n);
      if (name.isNotEmpty) {
        _resetState();
        _pendingScheduledType = 'bill';
        _pendingScheduledName = name;
        _pendingBillRequiresWallet = true;
        final now = DateTime.now();
        // "Upcoming" without a due date defaults to tomorrow.
        final dueDate =
            _parseUpcomingBillDate(n) ??
            DateTime(now.year, now.month, now.day + 1);
        _pendingScheduledDateTime = dueDate;
        _pendingScheduledDate = _formatBillDate(dueDate);
        _step = GabStep.awaitingScheduledAmount;
        return await _handleUpcomingBillFlow(n);
      }
    }

    final hasBillWord = RegExp(
      r'\b(?:bill|due|payment|rent|utilities|electricity|water|internet|wifi|phone|load|loan|credit\s+card|insurance|tuition|subscription|mortgage|amortization|installment)\b',
    ).hasMatch(n);
    final hasFutureSignal = RegExp(
      r'\b(?:due|on|this|by|need\s+to\s+pay|have\s+to\s+pay|remind\s+me|i\s+have|tomorrow|next\s+week|next\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday))\b|'
      r'\b(?:january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)\s+\d{1,2}\b|\b\d{1,2}/\d{1,2}\b',
    ).hasMatch(n);
    final billPayOnDate =
        RegExp(r'\bpay\b').hasMatch(n) && RegExp(r'\b(?:on|by)\s+').hasMatch(n);
    final pastPayment = RegExp(
      r'\b(?:paid|spent|bought|charged)\b',
    ).hasMatch(n);

    if (hasBillWord && (hasFutureSignal || billPayOnDate) && !pastPayment) {
      _resetState();
      _pendingScheduledType = 'bill';
      _step = GabStep.awaitingScheduledName;
      return await _handleUpcomingBillFlow(n);
    }

    final incomeFuturePattern = RegExp(
      r'\b(?:will\s+have|will\s+receive|will\s+get|will\s+be\s+paid|expect(?:ing)?|incoming|coming\s+on|on|by)\b',
    );
    final hasIncomeName = incomeNamePattern.hasMatch(n);
    final hasIncomeFutureSignal =
        incomeFuturePattern.hasMatch(n) &&
        RegExp(
          r'\b(?:tomorrow|next\s+week|next\s+(?:mon|tue|wed|thu|fri|sat|sun)\w*|(?:on|by|this)\s+(?:the\s+)?\d{1,2}|(?:on|by)\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|january|february|march|april|june|july|august|september|october|november|december)|(?:on|by)\s+(?:the\s+)?(?:mon|tue|wed|thu|fri|sat|sun)\w*)\b|'
          r'\b(?:january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)\s+\d{1,2}\b|\b\d{1,2}/\d{1,2}\b',
        ).hasMatch(n);
    final isPastIncome = RegExp(
      r'\b(?:received|earned|got\s+paid|just\s+got|was\s+paid)\b',
    ).hasMatch(n);
    final unnamedIncomingPayment =
        RegExp(r'\bwill\s+be\s+paid\b').hasMatch(n) &&
        RegExp(
          r'\b(?:on|by)\s+(?:the\s+)?(?:\d{1,2}|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|mon|tue|wed|thu|fri|sat|sun)\w*)\b',
        ).hasMatch(n);
    if ((hasIncomeName || unnamedIncomingPayment) &&
        hasIncomeFutureSignal &&
        !isPastIncome) {
      _resetState();
      _pendingScheduledType = 'income';
      _step = GabStep.awaitingScheduledName;
      return await _handleUpcomingIncomeFlow(n);
    }

    final futureSignals = RegExp(
      r'(will have|will receive|will get|will be|am getting|expecting|incoming|due|coming on|need to pay|have to pay|on \d+|this \w+|by \d+|remind me)',
      caseSensitive: false,
    );
    final pastSignals = RegExp(r'(spent|bought|paid|received|got|earned)');
    if (futureSignals.hasMatch(n) && !pastSignals.hasMatch(n)) {
      _pendingScheduledType = 'income';
      _step = GabStep.awaitingScheduledName;
      return await _handleScheduledEntryFlow(n);
    }
    return null;
  }

  Future<GabReply> _handleUpcomingIncomeFlow(String input) async {
    final normalized = _normalizeFutureText(input);
    if (_isCancellation(normalized)) {
      _resetState();
      return const GabReply('Okay, I cancelled that. Nothing was saved.');
    }

    if (input.trim().isNotEmpty &&
        (_step == GabStep.awaitingScheduledName ||
            _step == GabStep.awaitingScheduledAmount ||
            _step == GabStep.awaitingScheduledDate)) {
      if (_pendingScheduledName == null || _pendingScheduledName!.isEmpty) {
        final name = _extractUpcomingIncomeName(normalized);
        if (name.isNotEmpty) _pendingScheduledName = name;
      }

      if (_pendingScheduledAmount == null) {
        final amount = _extractUpcomingIncomeAmount(normalized);
        if (amount != null && amount.isFinite && amount > 0) {
          _pendingScheduledAmount = amount;
        }
      }

      if (_pendingScheduledDateTime == null) {
        final date = _parseUpcomingBillDate(
          normalized,
          allowBareDay: _step == GabStep.awaitingScheduledDate,
        );
        if (date != null) {
          _pendingScheduledDateTime = date;
          _pendingScheduledDate = _formatBillDate(date);
        }
      }
    }

    if (_pendingScheduledName == null || _pendingScheduledName!.isEmpty) {
      _step = GabStep.awaitingScheduledName;
      return const GabReply('What kind of incoming money is this?');
    }
    if (_pendingScheduledAmount == null) {
      _step = GabStep.awaitingScheduledAmount;
      return GabReply('How much is your ${_pendingScheduledName!}?');
    }
    if (_pendingScheduledDateTime == null) {
      _step = GabStep.awaitingScheduledDate;
      return GabReply(
        'On what date will you receive your ${_pendingScheduledName!}?',
      );
    }
    return await _saveUpcomingIncome();
  }

  String _extractUpcomingIncomeName(String text) {
    final knownName = RegExp(
      r'\b(?:13th\s+month(?:\s+pay)?|freelance\s+payment|business\s+income|rental\s+income|salary|allowance|commission|bonus|refund|pension|cashback)\b',
    ).firstMatch(text);
    if (knownName != null) return _titleCase(knownName.group(0)!);

    var name = _removeUpcomingBillDate(text);
    name = name.replaceAll(
      RegExp(r'(?<![\w/])\d+(?:,\d{3})*(?:\.\d+)?\s*[km]?\b'),
      ' ',
    );
    name = name.replaceAll(
      RegExp(r'\b(?:p|php|peso|pesos)\b|₱', caseSensitive: false),
      ' ',
    );
    name = name.replaceAll(
      RegExp(
        r'\b(?:i|my|will|have|receive|received|get|got|be|paid|expect|expecting|incoming|coming|on|by|this|the|a|an|of|is|arrive|arrives|arriving|money|income)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    name = name.replaceAll(RegExp(r'[^\w\s-]'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _titleCase(name);
  }

  Future<GabReply> _saveUpcomingIncome() async {
    final name = _titleCase(_pendingScheduledName!);
    final amount = _pendingScheduledAmount!;
    final date = _pendingScheduledDateTime!;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final event = FutureEvent(
      id: id,
      amount: amount,
      category: name,
      description: name,
      scheduledDate: date,
      type: 'income',
      status: 'pending',
      frequency: 'Once',
    );

    await FutureEventStorage.addEvent(event);
    final bills = await BillStorage.loadBills();
    bills.add(
      Bill(
        id: 'future_$id',
        type: name,
        amount: amount,
        dueDate: date,
        isIncome: true,
        frequency: 'Once',
      ),
    );
    await BillStorage.saveBills(bills);

    final formattedAmount = _formatNumberWithCommas(amount.toStringAsFixed(2));
    final confirmation =
        '${_incomeEmoji(name)} Incoming Transaction Added to Calendar!\n'
        '$name             +₱ $formattedAmount\n'
        'Date:             ${_formatBillDate(date)}\n'
        'I will remind you on the day it arrives.';
    _resetState();
    return GabReply(confirmation, highlightColor: 'green');
  }

  String _incomeEmoji(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('bonus') || normalized.contains('13th month')) {
      return '🎁';
    }
    if (normalized.contains('allowance')) return '💵';
    if (normalized.contains('commission') ||
        normalized.contains('business') ||
        normalized.contains('freelance')) {
      return '📈';
    }
    if (normalized.contains('refund') || normalized.contains('cashback')) {
      return '🔁';
    }
    return '💰';
  }
}
