import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/services/bai_assistant.dart';
import 'package:gabay/services/future_event_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('due car loan event is prompted as an outgoing payment', () async {
    final today = DateTime.now();
    await FutureEventStorage.saveEvents([
      FutureEvent(
        id: 'car-loan-due',
        amount: 1000,
        category: 'Car Loan',
        description: 'Car Loan',
        scheduledDate: DateTime(today.year, today.month, today.day),
      ),
    ]);

    final reply = await BaiAssistant().getAsyncGreeting();

    expect(reply.text, contains('Did you pay your Car Loan?'));
    expect(reply.text, isNot(contains('Did you receive your Car Loan?')));
  });
}
