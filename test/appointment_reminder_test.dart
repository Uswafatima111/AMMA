import 'package:flutter_test/flutter_test.dart';
import 'package:amma/models/appointment_model.dart';
import 'package:amma/models/medicine_reminder_model.dart';
import 'package:amma/services/appointment_service.dart';
import 'package:amma/services/reminder_service.dart';

void main() {
  final future = DateTime.utc(2030, 4, 12, 10);

  group('Appointments', () {
    test('validates mother, date, appointment type and initial status', () {
      expect(
        () => AppointmentService.validateAppointment(
          motherId: 'mother-1',
          date: future,
          type: 'followUp',
          status: 'scheduled',
        ),
        returnsNormally,
      );
      expect(
        () => AppointmentService.validateAppointment(
          motherId: '',
          date: future,
          type: 'routine',
          status: 'scheduled',
        ),
        throwsArgumentError,
      );
      expect(
        () => AppointmentService.validateAppointment(
          motherId: 'mother-1',
          date: future,
          type: 'unknown',
          status: 'scheduled',
        ),
        throwsArgumentError,
      );
      expect(
        () => AppointmentService.validateAppointment(
          motherId: 'mother-1',
          date: future,
          type: 'routine',
          status: 'completed',
        ),
        throwsArgumentError,
      );
    });

    test('enforces pending and scheduled status transitions', () {
      expect(AppointmentService.canTransition('pending', 'scheduled'), isTrue);
      expect(AppointmentService.canTransition('pending', 'cancelled'), isTrue);
      expect(
        AppointmentService.canTransition('scheduled', 'completed'),
        isTrue,
      );
      expect(
        AppointmentService.canTransition('scheduled', 'cancelled'),
        isTrue,
      );
      expect(
        () => AppointmentService.validateStatusTransition(
          'completed',
          'scheduled',
        ),
        throwsStateError,
      );
      expect(
        () =>
            AppointmentService.validateStatusTransition('pending', 'completed'),
        throwsStateError,
      );
      expect(
        () => AppointmentService.validateStatusTransition(
          'cancelled',
          'scheduled',
        ),
        throwsStateError,
      );
      expect(
        () => AppointmentService.validateStatusTransition(
          'completed',
          'cancelled',
        ),
        throwsStateError,
      );
    });

    test(
      'authorization helpers distinguish patient ownership and assigned ASHA',
      () {
        expect(
          AppointmentService.patientOwnsAppointment(
            authenticatedUid: 'patient-1',
            patientId: 'patient-1',
          ),
          isTrue,
        );
        expect(
          AppointmentService.patientOwnsAppointment(
            authenticatedUid: 'patient-1',
            patientId: 'patient-2',
          ),
          isFalse,
        );
        expect(
          AppointmentService.isAssignedAsha(
            authenticatedUid: 'asha-1',
            role: 'asha',
            assignedAshaId: 'asha-1',
          ),
          isTrue,
        );
        expect(
          AppointmentService.isAssignedAsha(
            authenticatedUid: 'asha-1',
            role: 'asha',
            assignedAshaId: 'asha-2',
          ),
          isFalse,
        );
        expect(
          AppointmentService.isAssignedAsha(
            authenticatedUid: 'asha-1',
            role: 'patient',
            assignedAshaId: 'asha-1',
          ),
          isFalse,
        );
      },
    );

    test('patient appointment query requires the authenticated UID', () {
      expect(
        AppointmentService.isPatientOwnedAppointmentQuery(
          authenticatedUid: 'patient-1',
          userId: 'patient-1',
        ),
        isTrue,
      );
      expect(
        AppointmentService.isPatientOwnedAppointmentQuery(
          authenticatedUid: 'patient-1',
          userId: 'patient-2',
        ),
        isFalse,
      );
    });

    test('ASHA query resolves only a mother in its assigned mother set', () {
      expect(
        AppointmentService.matchingAssignedMotherIds(
          suppliedUserId: 'legacy-patient-id',
          assignedMothers: [
            {'id': 'mother-1', 'patientUid': 'legacy-patient-id'},
            {'id': 'mother-2', 'patientUid': 'patient-2'},
          ],
        ),
        ['mother-1'],
      );
    });

    test('deterministic appointment identity prevents exact duplicates', () {
      final first = AppointmentService.appointmentDocumentId(
        motherId: 'mother-1',
        date: future,
        type: 'followUp',
        doctorName: 'Dr A',
        facilityName: 'Clinic',
      );
      final duplicate = AppointmentService.appointmentDocumentId(
        motherId: 'mother-1',
        date: future,
        type: 'followUp',
        doctorName: ' dr a ',
        facilityName: 'clinic',
      );
      final distinct = AppointmentService.appointmentDocumentId(
        motherId: 'mother-1',
        date: future.add(const Duration(minutes: 1)),
        type: 'followUp',
        doctorName: 'Dr A',
        facilityName: 'Clinic',
      );
      expect(first, duplicate);
      expect(first, isNot(distinct));
      expect(
        first,
        isNot(
          AppointmentService.appointmentDocumentId(
            motherId: 'mother-1',
            date: future,
            type: 'emergency',
            doctorName: 'Dr A',
            facilityName: 'Clinic',
          ),
        ),
      );
      expect(
        first,
        isNot(
          AppointmentService.appointmentDocumentId(
            motherId: 'mother-1',
            date: future,
            type: 'followUp',
            doctorName: 'Dr A',
            facilityName: 'Clinic',
            appointmentKey: 'second',
          ),
        ),
      );
    });

    test('parses valid dates and rejects invalid appointment data', () {
      final model = AppointmentModel.fromMap('appt-1', {
        'motherId': 'mother-1',
        'date': future,
        'type': 'routine',
        'status': 'scheduled',
        'reminderEnabled': false,
      });
      expect(model.date, future);
      expect(
        () => AppointmentModel.fromMap('appt-1', {
          'motherId': 'mother-1',
          'date': 'tomorrow',
          'type': 'routine',
          'status': 'scheduled',
        }),
        throwsFormatException,
      );
      expect(
        () => AppointmentModel.fromMap('appt-1', {
          'motherId': 'mother-1',
          'date': future,
          'type': 'other',
          'status': 'scheduled',
        }),
        throwsFormatException,
      );
      expect(
        () => AppointmentModel.fromMap('appt-1', {
          'motherId': 'mother-1',
          'type': 'routine',
          'status': 'scheduled',
        }),
        throwsFormatException,
      );
    });

    test('completed and cancelled appointments are retained as history', () {
      expect(
        AppointmentService.isHistoryAppointment(
          status: 'completed',
          appointmentDate: future,
          now: DateTime.utc(2029),
        ),
        isTrue,
      );
      expect(
        AppointmentService.isHistoryAppointment(
          status: 'cancelled',
          appointmentDate: future,
          now: DateTime.utc(2029),
        ),
        isTrue,
      );
      expect(
        AppointmentService.isHistoryAppointment(
          status: 'scheduled',
          appointmentDate: future,
          now: DateTime.utc(2029),
        ),
        isFalse,
      );
    });
  });

  group('Medicine reminders', () {
    test('requires supplied instructions, valid dates and HH:mm time', () {
      expect(
        () => ReminderService.validateReminder(
          motherId: 'mother-1',
          medicineName: 'as supplied',
          instructions: 'Follow clinician instructions',
          startDate: future,
          endDate: future.add(const Duration(days: 2)),
          reminderTime: '08:30',
        ),
        returnsNormally,
      );
      expect(
        () => ReminderService.validateReminder(
          motherId: 'mother-1',
          medicineName: 'medicine',
          instructions: '',
          startDate: future,
          endDate: future,
          reminderTime: '08:30',
        ),
        throwsArgumentError,
      );
      expect(
        () => ReminderService.validateReminder(
          motherId: 'mother-1',
          medicineName: 'medicine',
          instructions: 'provided',
          startDate: future,
          endDate: future.subtract(const Duration(days: 1)),
          reminderTime: '08:30',
        ),
        throwsArgumentError,
      );
      expect(
        () => ReminderService.validateReminder(
          motherId: 'mother-1',
          medicineName: 'medicine',
          instructions: 'provided',
          startDate: future,
          endDate: future,
          reminderTime: '25:00',
        ),
        throwsArgumentError,
      );
    });

    test(
      'duplicate reminder identity is stable and changes with reminder time',
      () {
        final first = ReminderService.reminderDocumentId(
          motherId: 'mother-1',
          medicineName: 'Medicine A',
          startDate: future,
          endDate: future.add(const Duration(days: 2)),
          reminderTime: '08:30',
        );
        final duplicate = ReminderService.reminderDocumentId(
          motherId: 'mother-1',
          medicineName: ' medicine a ',
          startDate: future,
          endDate: future.add(const Duration(days: 2)),
          reminderTime: '08:30',
        );
        final distinct = ReminderService.reminderDocumentId(
          motherId: 'mother-1',
          medicineName: 'Medicine A',
          startDate: future,
          endDate: future.add(const Duration(days: 2)),
          reminderTime: '09:30',
        );
        expect(first, duplicate);
        expect(first, isNot(distinct));
      },
    );

    test('only the assigned ASHA passes reminder management check', () {
      expect(
        ReminderService.isAssignedAsha(
          uid: 'asha-1',
          role: 'asha',
          assignedAshaId: 'asha-1',
        ),
        isTrue,
      );
      expect(
        ReminderService.isAssignedAsha(
          uid: 'asha-2',
          role: 'asha',
          assignedAshaId: 'asha-1',
        ),
        isFalse,
      );
      expect(
        ReminderService.isAssignedAsha(
          uid: 'patient-1',
          role: 'patient',
          assignedAshaId: 'patient-1',
        ),
        isFalse,
      );
    });

    test('malformed stored reminder data fails safely', () {
      expect(
        () => MedicineReminderModel.fromMap('rem-1', {
          'motherId': 'mother-1',
          'medicineName': 'Medication',
          'instructions': 'Clinician-provided',
          'startDate': future,
          'endDate': future,
          'reminderTime': '08:30',
          'active': true,
        }),
        throwsFormatException,
      );
    });

    test('reminder model exposes both active and inactive records', () {
      final base = <String, dynamic>{
        'motherId': 'mother-1',
        'medicineName': 'Medication as entered',
        'instructions': 'Instructions supplied by ASHA',
        'startDate': future,
        'endDate': future.add(const Duration(days: 2)),
        'reminderTime': '08:30',
        'createdAt': future,
      };
      final active = MedicineReminderModel.fromMap('rem-active', {
        ...base,
        'active': true,
      });
      final inactive = MedicineReminderModel.fromMap('rem-inactive', {
        ...base,
        'active': false,
      });
      expect(active.active, isTrue);
      expect(inactive.active, isFalse);
    });
  });
}
