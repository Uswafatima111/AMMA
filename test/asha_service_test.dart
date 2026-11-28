import 'package:amma/services/asha_service.dart';
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
  const patientUid = 'patient-1';
  const motherId = 'mother-1';
  const assignedAshaId = 'asha-1';
  const otherAshaId = 'asha-2';

  Future<(FakeFirebaseFirestore, AshaService)> setup({
    String role = 'patient',
    bool includeContact = true,
  }) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(patientUid).set({
      'id': patientUid,
      'role': role,
      'assignedMotherId': motherId,
    });
    await firestore.collection('mothers').doc(motherId).set({
      'id': motherId,
      'patientUid': patientUid,
      'assignedAshaId': assignedAshaId,
    });
    await firestore.collection('users').doc(assignedAshaId).set({
      'id': assignedAshaId,
      'role': 'asha',
      'name': 'Assigned ASHA',
      'email': 'private@example.test',
      'phone': '1111111111',
    });
    if (includeContact) {
      await firestore.collection('asha_contacts').doc(assignedAshaId).set({
        'id': assignedAshaId,
        'name': 'Assigned ASHA',
        'phone': '1111111111',
      });
    }
    return (
      firestore,
      AshaService(firestore: firestore, auth: _TestAuth(patientUid)),
    );
  }

  group('Assigned ASHA contact lookup', () {
    test('returns only limited contact fields for the assigned ASHA', () async {
      final (_, service) = await setup();

      final contact = await service.getAshaContact(assignedAshaId);

      expect(contact, {
        'id': assignedAshaId,
        'name': 'Assigned ASHA',
        'phone': '1111111111',
      });
      expect(contact!.containsKey('email'), isFalse);
    });

    test(
      'does not return a different ASHA contact or an unprovisioned contact',
      () async {
        final (_, service) = await setup();

        expect(await service.getAshaContact(otherAshaId), isNull);

        final (_, missingContactService) = await setup(includeContact: false);
        expect(await missingContactService.getAshaContact(), isNull);
      },
    );

    test(
      'ASHA self lookup returns only contact fields from their own profile',
      () async {
        final (firestore, _) = await setup();
        await firestore.collection('users').doc(patientUid).set({
          'id': patientUid,
          'role': 'asha',
          'name': 'Self ASHA',
          'email': 'private-self@example.test',
          'phone': '3333333333',
        });
        final service = AshaService(
          firestore: firestore,
          auth: _TestAuth(patientUid),
        );

        expect(await service.getAshaContact(patientUid), {
          'id': patientUid,
          'name': 'Self ASHA',
          'phone': '3333333333',
        });
        expect(await service.getAshaContact(assignedAshaId), isNull);
      },
    );

    test(
      'ASHA can publish a projection matching only their own profile',
      () async {
        final (firestore, _) = await setup();
        await firestore.collection('users').doc(patientUid).set({
          'id': patientUid,
          'role': 'asha',
          'name': 'Self ASHA',
          'email': 'private-self@example.test',
          'phone': '3333333333',
        });
        final service = AshaService(
          firestore: firestore,
          auth: _TestAuth(patientUid),
        );

        await service.publishOwnContact();

        final projection = await firestore
            .collection('asha_contacts')
            .doc(patientUid)
            .get();
        expect(projection.data(), {
          'id': patientUid,
          'name': 'Self ASHA',
          'phone': '3333333333',
        });
      },
    );
  });
}
