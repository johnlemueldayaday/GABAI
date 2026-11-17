String? billLabelForExpense(String text) {
  final normalized = text.toLowerCase().trim();
  if (normalized.isEmpty) return null;

  if (normalized.contains('water')) return 'Water';
  if (normalized.contains('aneco')) return 'ANECO Electricity';
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

bool isScheduledBillTransactionCategory(String category) =>
    category.trim().toLowerCase() == 'bills';
