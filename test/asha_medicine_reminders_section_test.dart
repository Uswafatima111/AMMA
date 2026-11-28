import 'package:amma/screens/asha/asha_medicine_reminders_section.dart';
import 'package:amma/services/reminder_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  testWidgets('assigned ASHA creates, edits and deactivates a reminder', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('asha-1').set({
      'id': 'asha-1',
      'role': 'asha',
    });
    await firestore.collection('mothers').doc('mother-1').set({
      'id': 'mother-1',
      'assignedAshaId': 'asha-1',
    });
    final service = ReminderService(
      firestore: firestore,
      auth: _TestAuth('asha-1'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AshaMedicineRemindersSection(
              motherId: 'mother-1',
              reminderService: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No medicine reminders for this mother.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reminder.create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reminder.form.medicine')),
      'Prenatal supplement',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reminder.form.instructions')),
      'Follow the care-team instructions',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reminder.form.start')),
      '2030-03-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reminder.form.end')),
      '2030-03-14',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reminder.form.time')),
      '25:00',
    );
    await tester.tap(find.byKey(const ValueKey('reminder.form.save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid time in HH:mm format.'), findsOneWidget);
    expect(
      await firestore
          .collection('medicine_reminders')
          .get()
          .then((snapshot) => snapshot.size),
      0,
    );

    await tester.enterText(
      find.byKey(const ValueKey('reminder.form.time')),
      '08:45',
    );
    await tester.tap(find.byKey(const ValueKey('reminder.form.save')));
    await tester.pumpAndSettle();
    final saved = await firestore.collection('medicine_reminders').get();
    expect(saved.size, 1);
    final reminderId = saved.docs.single.id;
    expect(find.text('Prenatal supplement'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('reminder.edit.$reminderId')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reminder.form.instructions')),
      'Updated instructions from the ASHA',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reminder.form.start')),
      '2030-03-02',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reminder.form.end')),
      '2030-03-18',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reminder.form.time')),
      '09:15',
    );
    await tester.tap(find.byKey(const ValueKey('reminder.form.save')));
    await tester.pumpAndSettle();
    var updated =
        (await firestore.collection('medicine_reminders').doc(reminderId).get())
            .data()!;
    expect(updated['instructions'], 'Updated instructions from the ASHA');
    expect(updated['reminderTime'], '09:15');
    expect(
      (updated['endDate'] as Timestamp).toDate().toUtc(),
      DateTime.utc(2030, 3, 18),
    );
    expect(updated['motherId'], 'mother-1');
    expect(updated['createdBy'], 'asha-1');

    await tester.tap(find.byKey(ValueKey('reminder.active.$reminderId')));
    await tester.pumpAndSettle();
    updated =
        (await firestore.collection('medicine_reminders').doc(reminderId).get())
            .data()!;
    expect(updated['active'], isFalse);
    expect(tester.takeException(), isNull);
  });
}
