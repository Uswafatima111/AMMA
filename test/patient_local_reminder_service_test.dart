import 'package:amma/services/patient_local_reminder_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2030, 4, 2, 7);

  test('plans future enabled appointments and each active medicine day', () {
    final schedules = PatientLocalReminderService.plan(
      now: now,
      appointments: [
        {
          'id': 'future',
          'date': now.add(const Duration(days: 2)),
          'status': 'scheduled',
          'reminderEnabled': true,
        },
        {
          'id': 'disabled',
          'date': now.add(const Duration(days: 1)),
          'status': 'scheduled',
          'reminderEnabled': false,
        },
        {
          'id': 'done',
          'date': now.add(const Duration(days: 1)),
          'status': 'completed',
          'reminderEnabled': true,
        },
      ],
      reminders: [
        {
          'id': 'active',
          'active': true,
          'startDate': Timestamp.fromDate(DateTime.utc(2030, 4, 2)),
          'endDate': Timestamp.fromDate(DateTime.utc(2030, 4, 4)),
          'reminderTime': '08:30',
        },
        {
          'id': 'inactive',
          'active': false,
          'startDate': Timestamp.fromDate(DateTime.utc(2030, 4, 2)),
          'endDate': Timestamp.fromDate(DateTime.utc(2030, 4, 4)),
          'reminderTime': '09:00',
        },
      ],
    );

    expect(schedules, hasLength(4));
    expect(schedules.map((item) => item.key), contains('appointment:future'));
    expect(
      schedules.where((item) => item.key.startsWith('medicine:active:')),
      hasLength(3),
    );
    for (var index = 1; index < schedules.length; index++) {
      expect(schedules[index - 1].when.isBefore(schedules[index].when), isTrue);
    }
    expect(schedules.any((item) => item.key.contains('disabled')), isFalse);
    expect(schedules.any((item) => item.key.contains('inactive')), isFalse);
  });

  test('omits elapsed occurrences and caps the rolling schedule window', () {
    final schedules = PatientLocalReminderService.plan(
      now: now,
      limit: 5,
      appointments: const [],
      reminders: [
        {
          'id': 'daily',
          'active': true,
          'startDate': Timestamp.fromDate(DateTime.utc(2030, 4, 1)),
          'endDate': Timestamp.fromDate(DateTime.utc(2030, 5, 15)),
          'reminderTime': '08:00',
        },
      ],
    );
    expect(schedules, hasLength(5));
    expect(schedules.every((item) => item.when.isAfter(now)), isTrue);
    expect(schedules.first.when, DateTime(2030, 4, 2, 8));
  });
}
