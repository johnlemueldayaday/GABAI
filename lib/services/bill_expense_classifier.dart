String? billLabelForExpense(String text) {
  final normalized = text.toLowerCase().trim();
  if (normalized.isEmpty) return null;

  if (normalized.contains('water')) return 'Water';
  if (normalized.contains('aneco')) return 'Aneco';
  if (normalized.contains('meralco')) return 'Meralco';
  if (normalized.contains('cepalco')) return 'Electricity';
  if (RegExp(r'\b(?:electricity|electric|power)\b').hasMatch(normalized)) {
    return 'Electricity';
  }
  if (RegExp(r'\b(?:internet|wifi)\b').hasMatch(normalized)) {
    return 'Internet';
  }
  if (normalized.contains('home credit')) return 'Home Credit';
  if (normalized.contains('skyro')) return 'Skyro';
  if (normalized.contains('insurance')) return 'Insurance';
  if (RegExp(r'\brent\b').hasMatch(normalized)) return 'Rent';
  if (RegExp(r'\b(?:phone|mobile|load)\b').hasMatch(normalized)) {
    return 'Phone';
  }
  if (RegExp(r'\b(?:netflix|spotify|subscription)\b').hasMatch(normalized)) {
    return 'Subscription';
  }
  if (normalized.contains('shopee') &&
      RegExp(
        r'\b(?:bill|payment|installment|loan|credit)\b',
      ).hasMatch(normalized)) {
    return 'Shopee';
  }
  if (RegExp(r'\b(?:loan|debt|credit card)\b').hasMatch(normalized)) {
    return 'Loan';
  }
  if (RegExp(r'\bbill\b').hasMatch(normalized)) return 'Other Bill';

  return null;
}

String cleanBillName(String text) {
  var name = text
      .replaceAll(RegExp(r'^Bill\s+Paid\s*:\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'^Received\s*:\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bbill(s)?\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final lower = name.toLowerCase();
  if (lower.contains('aneco')) return 'Aneco';
  if (lower.contains('meralco')) return 'Meralco';
  if (lower.contains('cepalco')) return 'Cepalco';
  if (RegExp(r'\b(?:electricity|electric|power)\b').hasMatch(lower)) {
    return 'Electricity';
  }
  if (lower.contains('netflix')) return 'Netflix';
  if (lower.contains('spotify')) return 'Spotify';
  if (lower.contains('subscription')) return 'Subscription';
  if (lower.isEmpty) return 'Bill';
  return name;
}

bool isPaidBillTransaction(String category, String description) =>
    RegExp(
      r'\b(?:Bill\s+)?Paid\s*:',
      caseSensitive: false,
    ).hasMatch(description) ||
    RegExp(
      r'^(?:Bill\s+)?Paid\b',
      caseSensitive: false,
    ).hasMatch(description) ||
    category.trim().toLowerCase() == 'bills';

bool isScheduledBillTransactionCategory(String category) =>
    category.trim().toLowerCase() == 'bills';
