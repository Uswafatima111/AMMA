import 'package:amma/services/reminder_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestUser implements User {
  _TestUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuth implements FirebaseAuth {
  _TestAuth(String uid) : currentUser = _TestUser(uid);
  @override
  final User currentUser;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const motherId = 'mother-1';
  const assignedAsha = 'asha-1';
  const unrelatedAsha = 'asha-2';
  final start = DateTime.utc(2030, 3, 5);
  final end = DateTime.utc(2030, 3, 9);

  Future<FakeFirebaseFirestore> setup() async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(assignedAsha).set({'role': 'asha'});
    await firestore.collection('users').doc(unrelatedAsha).set({
      'role': 'asha',
    });
    await firestore.collection('users').doc('patient-1').set({
      'role': 'patient',
    });
    await firestore.collection('mothers').doc(motherId).set({
      'patientUid': 'patient-1',
      'assignedAshaId': assignedAsha,
    });
    return firestore;
  }

  test(
    'assigned ASHA can edit reminder details without changing identity',
    () async {
      final firestore = await setup();
      final service = ReminderService(
        firestore: firestore,
        auth: _TestAuth(assignedAsha),
      );
      final id = await service.createReminder(
        motherId: motherId,
        medicineName: 'Medicine A',
        instructions: 'Use the supplied instructions',
        startDate: start,
        endDate: end,
        reminderTime: '08:30',
      );
      final ref = firestore.collection('medicine_reminders').doc(id);
      final original = (await ref.get()).data()!;
      await service.updateReminder(
        reminderId: id,
        medicineName: 'Medicine B',
        instructions: 'Updated supplied instructions',
        startDate: start.add(const Duration(days: 1)),
        endDate: end,
        reminderTime: '09:45',
      );
      final updated = (await ref.get()).data()!;
      expect(updated['motherId'], original['motherId']);
      expect(updated['createdBy'], original['createdBy']);
      expect(updated['createdAt'], original['createdAt']);
      expect(updated['active'], original['active']);
      expect(updated['medicineName'], 'Medicine B');
      expect(updated['instructions'], 'Updated supplied instructions');
      expect(updated['reminderTime'], '09:45');
    },
  );

  test('unrelated ASHA and patient cannot edit a reminder', () async {
    final firestore = await setup();
    final creator = ReminderService(
      firestore: firestore,
      auth: _TestAuth(assignedAsha),
    );
    final id = await creator.createReminder(
      motherId: motherId,
      medicineName: 'Medicine A',
      instructions: 'Supplied instructions',
      startDate: start,
      endDate: end,
      reminderTime: '08:30',
    );
    for (final uid in [unrelatedAsha, 'patient-1']) {
      final unauthorized = ReminderService(
        firestore: firestore,
        auth: _TestAuth(uid),
      );
      await expectLater(
        unauthorized.updateReminder(
          reminderId: id,
          medicineName: 'Changed',
          instructions: 'Changed',
          startDate: start,
          endDate: end,
          reminderTime: '10:00',
        ),
        throwsStateError,
      );
    }
    final saved =
        (await firestore.collection('medicine_reminders').doc(id).get())
            .data()!;
    expect(saved['medicineName'], 'Medicine A');
    expect(saved['reminderTime'], '08:30');
  });

  test('rejects invalid reminder edit before writing', () async {
    final firestore = await setup();
    final service = ReminderService(
      firestore: firestore,
      auth: _TestAuth(assignedAsha),
    );
    final id = await service.createReminder(
      motherId: motherId,
      medicineName: 'Medicine A',
      instructions: 'Supplied instructions',
      startDate: start,
      endDate: end,
      reminderTime: '08:30',
    );
    await expectLater(
      service.updateReminder(
        reminderId: id,
        medicineName: 'Changed',
        instructions: 'Changed',
        startDate: end,
        endDate: start,
        reminderTime: '24:00',
      ),
      throwsArgumentError,
    );
    final saved =
        (await firestore.collection('medicine_reminders').doc(id).get())
            .data()!;
    expect(saved['medicineName'], 'Medicine A');
  });

  test(
    'reminder detail update and activation preserve creator and mother',
    () async {
      final firestore = await setup();
      final service = ReminderService(
        firestore: firestore,
        auth: _TestAuth(assignedAsha),
      );
      final id = await service.createReminder(
        motherId: motherId,
        medicineName: 'Medicine A',
        instructions: 'Supplied instructions',
        startDate: start,
        endDate: end,
        reminderTime: '08:30',
      );
      await service.setActive(reminderId: id, active: false);
      await service.setActive(reminderId: id, active: true);
      final saved =
          (await firestore.collection('medicine_reminders').doc(id).get())
              .data()!;
      expect(saved['active'], isTrue);
      expect(saved['createdBy'], assignedAsha);
      expect(saved['motherId'], motherId);
    },
  );

  test('current assignment controls writes after reassignment', () async {
    final firestore = await setup();
    final formerAshaService = ReminderService(
      firestore: firestore,
      auth: _TestAuth(assignedAsha),
    );
    final id = await formerAshaService.createReminder(
      motherId: motherId,
      medicineName: 'Medicine A',
      instructions: 'Supplied instructions',
      startDate: start,
      endDate: end,
      reminderTime: '08:30',
    );
    await firestore.collection('mothers').doc(motherId).update({
      'assignedAshaId': unrelatedAsha,
    });

    await expectLater(
      formerAshaService.updateReminder(
        reminderId: id,
        medicineName: 'Changed by former ASHA',
        instructions: 'Changed',
        startDate: start,
        endDate: end,
        reminderTime: '09:00',
      ),
      throwsStateError,
    );
    await expectLater(
      formerAshaService.setActive(reminderId: id, active: false),
      throwsStateError,
    );
    await expectLater(
      formerAshaService.createReminder(
        motherId: motherId,
        medicineName: 'Medicine C',
        instructions: 'New reminder',
        startDate: start,
        endDate: end,
        reminderTime: '10:00',
      ),
      throwsStateError,
    );

    final currentAshaService = ReminderService(
      firestore: firestore,
      auth: _TestAuth(unrelatedAsha),
    );
    await currentAshaService.updateReminder(
      reminderId: id,
      medicineName: 'Medicine B',
      instructions: 'Updated by newly assigned ASHA',
      startDate: start,
      endDate: end,
      reminderTime: '09:15',
    );
    await currentAshaService.setActive(reminderId: id, active: false);
    final newId = await currentAshaService.createReminder(
      motherId: motherId,
      medicineName: 'Medicine C',
      instructions: 'New reminder by current ASHA',
      startDate: start,
      endDate: end,
      reminderTime: '10:00',
    );
    final saved =
        (await firestore.collection('medicine_reminders').doc(id).get())
            .data()!;
    expect(saved['motherId'], motherId);
    expect(saved['createdBy'], assignedAsha);
    expect(saved['medicineName'], 'Medicine B');
    expect(saved['active'], isFalse);
    expect(
      (await firestore.collection('medicine_reminders').doc(newId).get())
          .data()?['createdBy'],
      unrelatedAsha,
    );
  });

  test('mother reminder stream is scoped to the requested stable ID', () async {
    final firestore = await setup();
    final service = ReminderService(
      firestore: firestore,
      auth: _TestAuth(assignedAsha),
    );
    await firestore.collection('medicine_reminders').doc('for-mother-1').set({
      'motherId': motherId,
      'medicineName': 'Medicine A',
      'instructions': 'Instructions',
      'startDate': Timestamp.fromDate(start),
      'endDate': Timestamp.fromDate(end),
      'reminderTime': '08:30',
      'active': true,
      'createdBy': assignedAsha,
      'createdAt': Timestamp.now(),
    });
    await firestore.collection('medicine_reminders').doc('for-mother-2').set({
      'motherId': 'mother-2',
      'medicineName': 'Other medicine',
      'instructions': 'Other instructions',
      'startDate': Timestamp.fromDate(start),
      'endDate': Timestamp.fromDate(end),
      'reminderTime': '08:30',
      'active': true,
      'createdBy': assignedAsha,
      'createdAt': Timestamp.now(),
    });

    final result = await service.watchForMother(motherId).first;
    expect(result.docs.map((document) => document.id), ['for-mother-1']);
    expect(() => service.watchForMother(' '), throwsArgumentError);
  });
}
