# BAI Income Detection Enhancement Guide

## Current System Analysis

Your BAI system is well-structured with the following income detection workflow:

```
User Input 
    ↓
Intent Router (handle method)
    ↓
_tryLogIncome() → _isIncomeIntent() 
    ↓
Amount Extraction (Regex)
    ↓
Account Detection (Fuzzy Matching)
    ↓
Description Cleaning & Categorization
    ↓
Transaction Logging & Response
```

---

## Recommended Enhancements

### 1. **Enhanced Income Intent Detection**
**File**: `lib/services/bai_assistant.dart`

**Current Implementation** (Lines ~1055-1130):
```dart
bool _isIncomeIntent(String text) {
  final l = text.toLowerCase();
  final List<String> strongIncomeKeywords = [
    'received', 'recieved', 'got paid', 'allowance', 'salary',
    'sweldo', 'sahod', 'payroll', 'bonus', ...
  ];
  if (strongIncomeKeywords.any((k) => l.contains(k))) return true;
  // ... more checks
}
```

**Enhanced Version - Add These Patterns**:
```dart
// Add to the strongIncomeKeywords list:
'inflow',          // Financial term
'side gig',        // Freelance variations
'consulting',      // Professional income
'dividend',        // Investment returns
'crypto',          // Digital assets
'investment',      // General investments

// Add phrase structures:
if (RegExp(r'\b(?:from|got)\b.*\b(?:mom|dad|kuya|lola|sister|cousin|friend)\b')
    .hasMatch(l)) return true;  // Family money patterns

if (RegExp(r'(\d+).*(?:to|in)\s+(?:bank|gcash|cash|maya)')
    .hasMatch(l)) return true;  // Amount + account patterns

if (RegExp(r'(?:sold|selling|sale).*(\d+)')
    .hasMatch(l)) return true;  // Sales patterns
```

### 2. **Better Amount Extraction**
**Current**:
```dart
final amountReg = RegExp(r'(\d+(?:\.\d+)?)');
```

**Enhanced**:
```dart
// Handle various formats: "500", "500.50", "5k", "5000 pesos"
final amountReg = RegExp(
  r'(?:^|\s)(\d+(?:[.,]\d{1,2})?)\s*(?:k|pesos|php|₱)?|'
  r'(?:of\s+)?(\d+(?:[.,]\d{1,2})?)(?:\s+(?:pesos|php|₱))?',
  caseSensitive: false,
);

// Handle "k" suffix (5k = 5000)
String amountStr = amountMatch.group(1) ?? amountMatch.group(2) ?? '';
if (amountStr.toLowerCase().endsWith('k')) {
  amountStr = amountStr.substring(0, amountStr.length - 1);
  final baseAmount = double.tryParse(amountStr);
  amount = (baseAmount ?? 0) * 1000;
}
```

### 3. **Smarter Account Detection**
**Add Context-Aware Matching**:
```dart
// In _detectAccountFromText(), add:
// Look for account mentions in context
if (l.contains('my bank') || l.contains('bank account')) {
  for (final a in accounts) {
    if (a.name.toLowerCase().contains('bank')) return a;
  }
}

if (l.contains('my wallet') || l.contains('cash wallet')) {
  for (final a in accounts) {
    if (a.name.toLowerCase().contains('cash')) return a;
  }
}

// Tagalog support
if (l.contains('sa cash') || l.contains('sa bank')) {
  final accountType = l.split('sa ').last.trim().split(RegExp(r'\s+'))[0];
  return _findAccount(accountType, accounts);
}
```

### 4. **Improved Description Cleaning**
**Add Income-Specific Cleanup**:
```dart
// In _tryLogIncome(), enhance description cleaning:
final incomeCleanupPatterns = [
  r'\b(?:received|recieved|got|received)\b',
  r'\b(?:from|to|in|into|sa)\b',
  r'\bmy\b',
  r'\bpesos|php|₱\b',
  r'\b(?:bank|gcash|cash|maya|wallet)\b',
];

String cleanedDesc = descStr;
for (final pattern in incomeCleanupPatterns) {
  cleanedDesc = cleanedDesc.replaceAll(
    RegExp(pattern, caseSensitive: false), ''
  );
}

// Remove person names and replace with source
if (RegExp(r'\b(?:mom|dad|kuya|lola|sister|cousin|friend|mark|john)\b')
    .hasMatch(descStr)) {
  cleanedDesc = 'Gift - Family';
}
```

### 5. **Multi-Language Support Enhancement**
**Add Tagalog Patterns**:
```dart
// Tagalog keywords for income
if (l.contains('nabigyan ako') ||        // "I was given"
    l.contains('binigyan ako') ||        // "I was given"
    l.contains('nakatanggap') ||         // "I received"
    l.contains('sahod') ||               // "salary"
    l.contains('sweldo') ||              // "salary"
    l.contains('allowance')) {
  return true;
}

// Tagalog account references
if (l.contains('sa gcash') || l.contains('sa bank') || l.contains('sa cash')) {
  return true;
}
```

### 6. **Response Customization**
**Make Responses More Dynamic**:
```dart
// Instead of generic "Income logged!"
// Generate contextual messages:

String generateIncomeResponse(String source, double amount, String account, String desc) {
  final sourcePrefix = source.contains('Freelance') 
    ? '💼 Freelance' 
    : source.contains('Investment') 
    ? '📈 Investment' 
    : '💵';
  
  final emoji = desc.contains('Gift') ? '🎁 ' : '';
  
  return """$emoji$sourcePrefix Income logged!

+ ₱${amount.toStringAsFixed(2)} to $account
• Description: $desc
• Category: $source
• New Balance: ₱${newBalance.toStringAsFixed(2)}""";
}
```

---

## Implementation Priority

### High Priority (Immediate Impact)
1. ✅ Add more income keywords (inflow, crypto, consulting, dividend)
2. ✅ Support Tagalog phrase patterns
3. ✅ Handle "k" suffix in amounts (5k = 5000)

### Medium Priority (Better UX)
4. Add context-aware account detection
5. Enhance description cleaning for different sources
6. Support more casual phrasings

### Low Priority (Nice-to-Have)
7. Add emojis based on income source
8. Support more currency formats
9. Add transaction notes/memos

---

## Testing Checklist

- [ ] Test "200 from mom" → Asks for account
- [ ] Test "got paid 15000 sweldo from boss to gcash" → Logs successfully
- [ ] Test "inflow of 4500 to my bank from consulting" → Recognizes as income
- [ ] Test "nabigyan ako ng 1800 from cousin sa cash" → Handles Tagalog
- [ ] Test "crypto gains 15000 to gcash" → Categorizes as Investment
- [ ] Test "5k from freelance to bank" → Converts 5k to 5000
- [ ] Test Casual: "john sent me 350 gcash" → Works with person name
- [ ] Test Edge Case: Amount with decimal "250.50 from dad"
- [ ] Test Bonus: "got bonus 12000 from company" → Asks for account
- [ ] Test Phrase: "mark paid me back 600 in cash" → Logs to Cash

---

## Code Template for Quick Implementation

If you want to implement the enhanced version quickly, here's the modification:

**File**: `lib/services/bai_assistant.dart` (Around line 1055)

```dart
bool _isIncomeIntent(String text) {
  final l = text.toLowerCase();
  
  // STRONG INCOME INDICATORS
  final List<String> strongIncomeKeywords = [
    'received', 'recieved', 'got paid', 'get paid',
    'allowance', 'salary', 'sweldo', 'sahod', 'payroll',
    'bonus', 'refund', 'tax refund', 'sold', 'sale', 'preloved',
    'inflow', 'interest', 'deposit', 'deposits', 'freelance',
    'sideline', 'gig', 'consulting', 'dividend', 'crypto',
  ];
  if (strongIncomeKeywords.any((k) => l.contains(k))) return true;

  // FAMILY/PERSON PATTERNS
  final familyPattern = RegExp(
    r'\b(?:gave|sent|paid|handed|donated)\s+(?:me|his|her)\b',
    caseSensitive: false,
  );
  if (familyPattern.hasMatch(text)) return true;

  // TAGALOG PATTERNS
  if (RegExp(r'\b(?:nabigyan|binigyan|nakatanggap|sa gcash|sa bank|sa cash)\b',
      caseSensitive: false).hasMatch(l)) return true;

  // CONTEXT PATTERNS
  if ((l.contains('added') && l.contains('to my')) ||
      (l.contains('got') && !l.contains('spent') && !l.contains('paid'))) {
    return true;
  }

  return false;
}
```

---

## Validation & Testing Data

Use the provided `income_training_samples.json` and `income_training_samples.md` files to validate the enhanced implementation.

**Quick Test Script** (Add to your test file):
```dart
void testIncomeDetection() {
  final bai = BaiAssistant();
  
  final testCases = [
    ('200 from mom', true),
    ('got paid 15000 sweldo to gcash', true),
    ('crypto gains 15000 to bank', true),
    ('spent 500 on coffee', false),
    ('transfer 1000 to gcash', false),
  ];
  
  for (final (input, expected) in testCases) {
    final result = bai.handle(input);
    print('Test: $input → ${result.text}');
  }
}
```

---

## Next Steps

1. **Test**: Run all 30 training samples through your current BAI system
2. **Identify Gaps**: Note which patterns fail or produce unexpected results
3. **Implement**: Apply the enhancements in priority order
4. **Validate**: Re-test with the complete dataset
5. **Deploy**: Release updated BAI with improved income handling

---

**Note**: These enhancements maintain backward compatibility with your current system while adding robust support for diverse income transaction variations.
