file_path = 'lib/services/bai_assistant.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Add new BaiSteps if they don't exist
if 'awaitingScheduledName' not in content:
    content = content.replace(
        "  awaitingClarification,",
        "  awaitingClarification,\n  awaitingScheduledName,\n  awaitingScheduledAmount,\n  awaitingScheduledDate,"
    )

# Replace the state variables block
state_vars = """
  // Clarification
  String? _unclearRawInput;

  // Track pending scheduled entries
  String? _pendingScheduledName;
  double? _pendingScheduledAmount;
  String? _pendingScheduledDate;
  String? _pendingScheduledType; // "bill" or "income"
"""

content = content.replace(
    """  // Clarification
  String? _unclearRawInput;""",
    state_vars
)

methods_to_add = """
  // ---------------------------------------------------------
  // SCHEDULED ENTRIES FLOW (BILLS & FUTURE INCOME)
  // ---------------------------------------------------------
  Future<BaiReply> _handleScheduledEntryFlow(String input) async {
    final n = input.toLowerCase();
    
    // 1. CANCEL OR NEW COMMAND
    if (n == 'cancel' || n == 'stop' || n == 'never mind' || n == 'forget it' || n == 'nevermind') {
      _resetState();
      return const BaiReply("Okay, I cancelled that. Nothing was saved.");
    }
    
    if (n.contains('update') && n.contains('budget') || n.contains('spent')) {
       _resetState();
       return handle(input); // Reroute as a fresh command
    }

    // 2. PARSE MISSING FIELDS
    if (_pendingScheduledName == null || _pendingScheduledName!.isEmpty) {
      String item = n.replaceAll(RegExp(r'\\d+(?:\\.\\d+)?'), '').replaceAll(RegExp(r'october|oct|november|nov|december|dec'), '').trim();
      if (item.isNotEmpty) _pendingScheduledName = item;
    }

    if (_pendingScheduledAmount == null) {
      double? amount = _extractAmountWithSlang(n);
      if (amount != null && amount > 0) _pendingScheduledAmount = amount;
    }

    if (_pendingScheduledDate == null || _pendingScheduledDate!.isEmpty) {
      final dateMatch = RegExp(r'(?:on|due|this|by)\\s+([a-z]+\\s+\\d+|\\d{1,2}/\\d{1,2}|\\d{1,2}(?:th|st|nd|rd)?|tomorrow|next\\s+[a-z]+)').firstMatch(n);
      if (dateMatch != null) {
        _pendingScheduledDate = dateMatch.group(1);
      } else {
        // Fallback for just typing a date like "October 15"
        final rawDateMatch = RegExp(r'([a-z]+\\s+\\d+|\\d{1,2}/\\d{1,2}|tomorrow|next\\s+[a-z]+)').firstMatch(n);
        if (rawDateMatch != null) _pendingScheduledDate = rawDateMatch.group(1);
      }
    }

    // 3. ASK FOR MISSING FIELDS
    if (_pendingScheduledName == null || _pendingScheduledName!.isEmpty) {
      _step = BaiStep.awaitingScheduledName;
      return BaiReply(_pendingScheduledType == 'bill' ? "What bill is this?" : "What kind of incoming money is this?");
    }
    
    if (_pendingScheduledAmount == null) {
      _step = BaiStep.awaitingScheduledAmount;
      return BaiReply(_pendingScheduledType == 'bill' ? "How much is the ${_pendingScheduledName}?" : "How much is your ${_pendingScheduledName}?");
    }
    
    if (_pendingScheduledDate == null || _pendingScheduledDate!.isEmpty) {
      _step = BaiStep.awaitingScheduledDate;
      return BaiReply(_pendingScheduledType == 'bill' ? "When is the ${_pendingScheduledName} due?" : "On what date will you receive your ${_pendingScheduledName}?");
    }

    // 4. CONFIRMATION
    final title = _pendingScheduledType == 'bill' ? '📅 Bill Added to Calendar!' : '💰 Incoming Transaction Added to Calendar!';
    final footer = _pendingScheduledType == 'bill' ? 'I will remind you on the due date.' : 'I will remind you on the day it arrives.';
    final sign = _pendingScheduledType == 'bill' ? 'P-' : 'P ';
    
    _resetState();
    return BaiReply("$title\\n${_pendingScheduledName}\\t\\t$sign${_pendingScheduledAmount!.toStringAsFixed(2)}\\nDate:\\t\\t\\t${_pendingScheduledDate}\\n\\n$footer",
      highlightColor: _pendingScheduledType == 'bill' ? 'red' : 'green');
  }

  Future<BaiReply?> _tryScheduledEntry(String n) async {
    final futureSignals = RegExp(r'(will have|will receive|will get|will be|am getting|expecting|incoming|due|coming on|need to pay|have to pay)');
    final pastSignals = RegExp(r'(spent|bought|paid|received|got|earned)');
    
    // DECISION ORDER 2: Future signals 
    if (futureSignals.hasMatch(n) && !pastSignals.hasMatch(n)) {
       final isBill = RegExp(r'(bill|rent|utilities|electricity|water|internet|wifi|phone|loan|credit card|subscription)').hasMatch(n);
       _pendingScheduledType = isBill ? 'bill' : 'income';
       _step = BaiStep.awaitingScheduledName;
       return await _handleScheduledEntryFlow(n);
    }
    return null;
  }
"""

if '_handleScheduledEntryFlow' not in content:
    content = content.rstrip()
    if content.endswith('}'):
        content = content[:-1] + methods_to_add + "\n}"
    
    # Wire up _tryScheduledEntry and states
    wire_up_code = """
    if (_step == BaiStep.awaitingScheduledName || 
        _step == BaiStep.awaitingScheduledAmount ||
        _step == BaiStep.awaitingScheduledDate) {
      return await _handleScheduledEntryFlow(n);
    }
    
    // Handle awaiting expense item/amount states"""
    content = content.replace("    // Handle awaiting expense item/amount states", wire_up_code)

    router_code = """
    // ─── 1. STATE MACHINE (mid-conversation flows take priority) ───
    final undoResult = await _tryUndo(n);
    if (undoResult != null &&
        _step != BaiStep.awaitingDuePaymentAction &&
        _step != BaiStep.awaitingDuePaymentAccount) {
      _resetState();
      return undoResult;
    }

    if (_step != BaiStep.idle) {
      return await _handleStateMachine(n);
    }
    
    // ─── 2. FUTURE INCOMING EVENTS ───
    final scheduledResult = await _tryScheduledEntry(n);
    if (scheduledResult != null) return scheduledResult;"""
    content = content.replace("    // ─── 2. FUTURE INCOMING EVENTS ───", router_code.split("    // ─── 2. FUTURE INCOMING EVENTS ───")[1])

    with open(file_path, 'w') as f:
        f.write(content)
    print("Added scheduled entries logic successfully!")
else:
    print("Logic already exists.")
