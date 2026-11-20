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

  test('normalizes electricity providers and removes bill wording', () {
    expect(billLabelForExpense('Aneco Bill'), 'ANECO Electricity');
    expect(billLabelForExpense('Meralco electricity'), 'Meralco Electricity');
    expect(billLabelForExpense('CEPALCO Bill'), 'CEPALCO Electricity');
    expect(billLabelForExpense('Electricity Bill'), 'Electricity');
    expect(cleanBillName('Aneco Bill'), 'ANECO Electricity');
    expect(cleanBillName('Meralco Bill'), 'Meralco Electricity');
    expect(cleanBillName('CEPALCO Bill'), 'CEPALCO Electricity');
    expect(cleanBillName('netflix sub bill'), 'Netflix');
  });

  test('recognizes both legacy and clean paid-bill transactions', () {
    expect(
      isPaidBillTransaction('ANECO Electricity', 'Bill Paid: Aneco Bill'),
      isTrue,
    );
    expect(
      isPaidBillTransaction('Electricity', 'Paid: ANECO Electricity'),
      isTrue,
    );
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
