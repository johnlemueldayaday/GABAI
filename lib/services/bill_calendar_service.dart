import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BillCalendarService {
  BillCalendarService({DeviceCalendarPlugin? plugin})
    : _plugin = plugin ?? DeviceCalendarPlugin();

  static const _referencesKey = 'device_calendar_bill_events';
  static const _eventFormatVersion = 2;
  final DeviceCalendarPlugin _plugin;

  Future<void> syncAllBills(List<Bill> bills) async {
    if (kIsWeb) return;
    final preferences = await SharedPreferences.getInstance();
    final references = _loadReferences(preferences);
    if (bills.isEmpty && references.isEmpty) return;

    final calendarId = await _writableCalendarId();
    final billIds = bills.map((bill) => bill.id).toSet();
    for (final id in references.keys.toList()) {
      if (!billIds.contains(id)) {
        await _deleteReference(references, id);
      }
    }

    for (final bill in bills) {
      await _syncBill(bill, calendarId, references);
    }
    await _saveReferences(preferences, references);
  }

  Future<void> syncBill(Bill bill) async {
    if (kIsWeb) return;
    final preferences = await SharedPreferences.getInstance();
    final references = _loadReferences(preferences);
    final calendarId = await _writableCalendarId();
    await _syncBill(bill, calendarId, references);
    await _saveReferences(preferences, references);
  }

  Future<void> deleteBill(String billId) async {
    if (kIsWeb) return;
    final preferences = await SharedPreferences.getInstance();
    final references = _loadReferences(preferences);
    await _deleteReference(references, billId);
    await _saveReferences(preferences, references);
  }

  static RecurrenceRule? recurrenceRuleForFrequency(String frequency) {
    return switch (frequency) {
      'Once' => null,
      'Everyday' => RecurrenceRule(RecurrenceFrequency.Daily),
      'Weekly' => RecurrenceRule(RecurrenceFrequency.Weekly),
      'Monthly' => RecurrenceRule(RecurrenceFrequency.Monthly),
      'Quarterly' => RecurrenceRule(RecurrenceFrequency.Monthly, interval: 3),
      'Bi-monthly' => RecurrenceRule(RecurrenceFrequency.Monthly, interval: 2),
      'Annually' => RecurrenceRule(RecurrenceFrequency.Yearly),
      _ => throw ArgumentError.value(frequency, 'frequency', 'Unsupported'),
    };
  }

  Future<void> _syncBill(
    Bill bill,
    String calendarId,
    Map<String, _CalendarEventReference> references,
  ) async {
    var reference = references[bill.id];
    final signature = _signature(bill);

    if (reference != null &&
        (reference.calendarId != calendarId ||
            reference.signature != signature ||
            (!bill.isPaid && reference.isPaid))) {
      await _deleteReference(references, bill.id);
      reference = null;
    }

    if (bill.isPaid && bill.frequency == 'Once') {
      await _deleteReference(references, bill.id);
      return;
    }

    if (reference == null) {
      final start = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
      );
      final event = Event(
        calendarId,
        title: '${bill.isIncome ? 'Income' : 'Bill'}: ${bill.type}',
        description:
            '${bill.type} • ₱${bill.amount.toStringAsFixed(2)} • ${bill.frequency}',
        start: start,
        end: start,
        allDay: true,
        recurrenceRule: recurrenceRuleForFrequency(bill.frequency),
        // All-day alerts use the calendar's configured all-day alert time.
        reminders: [
          Reminder(minutes: 0),
          Reminder(minutes: 7 * 24 * 60),
        ],
      );
      final result = await _plugin.createOrUpdateEvent(event);
      final eventId = result?.data;
      if (result == null || !result.isSuccess || eventId == null) {
        throw StateError(_calendarError('Could not add event', result));
      }
      reference = _CalendarEventReference(
        calendarId: calendarId,
        eventId: eventId,
        signature: signature,
      );
      references[bill.id] = reference;
    }

    if (bill.isPaid && !reference.isPaid) {
      if (bill.frequency == 'Once') {
        await _deleteReference(references, bill.id);
        return;
      }
      final dayStart = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
      );
      final dayEnd = dayStart.add(const Duration(days: 1));
      final result = await _plugin.deleteEventInstance(
        reference.calendarId,
        reference.eventId,
        dayStart.millisecondsSinceEpoch,
        dayEnd.millisecondsSinceEpoch,
        false,
      );
      if (!result.isSuccess || result.data != true) {
        throw StateError(_calendarError('Could not mark event paid', result));
      }
      references[bill.id] = reference.copyWith(isPaid: true);
    }
  }

  Future<String> _writableCalendarId() async {
    final permissionStatus = await _plugin.hasPermissions();
    if (permissionStatus.data != true) {
      final requested = await _plugin.requestPermissions();
      if (requested.data != true) {
        throw StateError(
          'Allow GABAI to access your calendar to add bill reminders.',
        );
      }
    }

    final result = await _plugin.retrieveCalendars();
    if (!result.isSuccess) {
      throw StateError(_calendarError('Could not load calendars', result));
    }
    final List<Calendar> calendars = result.data?.toList() ?? [];
    final writableCalendars = calendars
        .where((calendar) => calendar.id != null && calendar.isReadOnly != true)
        .toList();
    if (writableCalendars.isEmpty) {
      throw StateError(
        'No writable calendar found. Add or enable a calendar on your phone.',
      );
    }
    final selectedCalendar = writableCalendars.firstWhere(
      (calendar) => calendar.isDefault == true,
      orElse: () => writableCalendars.first,
    );
    return selectedCalendar.id!;
  }

  Future<void> _deleteReference(
    Map<String, _CalendarEventReference> references,
    String billId,
  ) async {
    final reference = references[billId];
    if (reference == null) return;

    final result = await _plugin.deleteEvent(
      reference.calendarId,
      reference.eventId,
    );
    if (!result.isSuccess || result.data != true) {
      throw StateError(
        _calendarError('Could not remove calendar event', result),
      );
    }
    references.remove(billId);
  }

  Map<String, _CalendarEventReference> _loadReferences(
    SharedPreferences preferences,
  ) {
    final value = preferences.getString(_referencesKey);
    if (value == null) return {};
    final decoded = jsonDecode(value) as Map<String, dynamic>;
    return decoded.map(
      (id, json) => MapEntry(
        id,
        _CalendarEventReference.fromJson(json as Map<String, dynamic>),
      ),
    );
  }

  Future<void> _saveReferences(
    SharedPreferences preferences,
    Map<String, _CalendarEventReference> references,
  ) async {
    await preferences.setString(
      _referencesKey,
      jsonEncode(
        references.map((id, reference) => MapEntry(id, reference.toJson())),
      ),
    );
  }

  String _signature(Bill bill) => jsonEncode([
    _eventFormatVersion,
    bill.type,
    bill.amount,
    bill.dueDate.toIso8601String(),
    bill.frequency,
    bill.isIncome,
  ]);

  String _calendarError(String operation, Result<Object?>? result) {
    final details = result?.errors
        .map((error) => error.errorMessage)
        .join('; ');
    return details == null || details.isEmpty
        ? '$operation. Please check calendar access and try again.'
        : '$operation: $details';
  }
}

class _CalendarEventReference {
  const _CalendarEventReference({
    required this.calendarId,
    required this.eventId,
    required this.signature,
    this.isPaid = false,
  });

  final String calendarId;
  final String eventId;
  final String signature;
  final bool isPaid;

  _CalendarEventReference copyWith({bool? isPaid}) => _CalendarEventReference(
    calendarId: calendarId,
    eventId: eventId,
    signature: signature,
    isPaid: isPaid ?? this.isPaid,
  );

  Map<String, dynamic> toJson() => {
    'calendarId': calendarId,
    'eventId': eventId,
    'signature': signature,
    'isPaid': isPaid,
  };

  factory _CalendarEventReference.fromJson(Map<String, dynamic> json) =>
      _CalendarEventReference(
        calendarId: json['calendarId'] as String,
        eventId: json['eventId'] as String,
        signature: json['signature'] as String,
        isPaid: json['isPaid'] as bool? ?? false,
      );
}
