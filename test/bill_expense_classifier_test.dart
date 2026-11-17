import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/services/bill_expense_classifier.dart';

void main() {
  test('classifies representative bill names', () {
    expect(billLabelForExpense('Water Bill'), 'Water');
    expect(billLabelForExpense('internet payment'), 'Internet');
    expect(billLabelForExpense('ANECO electricity'), 'ANECO Electricity');
    expect(billLabelForExpense('Home Credit installment'), 'Home Credit');
    expect(billLabelForExpense('Skyro bill'), 'Skyro');
    expect(billLabelForExpense('Shopee bill'), 'Shopee');
    expect(billLabelForExpense('phone bill'), 'Phone');
    expect(billLabelForExpense('rent'), 'Rent');
    expect(billLabelForExpense('insurance payment'), 'Insurance');
  });

  test('does not classify ordinary shopping as a bill', () {
    expect(billLabelForExpense('Shopee purchase'), isNull);
    expect(billLabelForExpense('groceries'), isNull);
  });

  test('recognizes scheduled bill transactions for deduplication', () {
    expect(isScheduledBillTransactionCategory('Bills'), isTrue);
    expect(isScheduledBillTransactionCategory('Water'), isFalse);
  });
}
