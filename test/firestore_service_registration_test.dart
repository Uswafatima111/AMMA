import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amma/services/firestore_service.dart';

enum _WriteType { set, update, delete }

class _PendingWrite {
  const _PendingWrite(this.type, this.reference, [this.data]);

  final _WriteType type;
  final DocumentReference reference;
  final Object? data;
}

/// fake_cloud_firestore executes writes eagerly and cannot roll them back.
/// Stage them so a missing update target fails before commit, matching the
/// atomic failure behavior exercised by these registration tests.
class _AtomicFakeFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _StagedTransaction();
    final result = await transactionHandler(transaction);
    for (final write in transaction.writes) {
      if (write.type == _WriteType.update &&
          !(await write.reference.get()).exists) {
        throw StateError('Transaction update target does not exist.');
      }
    }

    final batch = super.batch();
    for (final write in transaction.writes) {
      switch (write.type) {
        case _WriteType.set:
          batch.set(write.reference, write.data);
        case _WriteType.update:
          batch.update(write.reference, write.data as Map<Object, Object?>);
        case _WriteType.delete:
          batch.delete(write.reference);
      }
    }
    await batch.commit();
    return result;
  }
}

class _StagedTransaction implements Transaction {
  final writes = <_PendingWrite>[];
  bool _hasWritten = false;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) {
    if (_hasWritten) throw StateError('Transaction reads must precede writes.');
    return documentReference.get();
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _hasWritten = true;
    writes.add(_PendingWrite(_WriteType.set, documentReference, data));
    return this;
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    _hasWritten = true;
    writes.add(_PendingWrite(_WriteType.update, documentReference, data));
    return this;
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    _hasWritten = true;
    writes.add(_PendingWrite(_WriteType.delete, documentReference));
    return this;
  }
}

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
  const ashaUid = 'asha-1';
  const patientUid = 'patient-1';

  Future<(_AtomicFakeFirestore, FirestoreService)> setup({
    required bool createPatient,
  }) async {
    final firestore = _AtomicFakeFirestore();
    await firestore.collection('users').doc(ashaUid).set({
      'id': ashaUid,
      'role': 'asha',
    });
    if (createPatient) {
      await firestore.collection('users').doc(patientUid).set({
        'id': patientUid,
        'role': 'patient',
      });
    }
    return (
      firestore,
      FirestoreService(firestore: firestore, auth: _TestAuth(ashaUid)),
    );
  }

  group('FirestoreService mother registration transactions', () {
    test(
      'createMother creates the mother and links the patient profile',
      () async {
        final (firestore, service) = await setup(createPatient: true);

        await service.createMother(
          userId: patientUid,
          name: 'Test Mother',
          pregnancyWeek: 20,
          status: 'active',
        );

        final mothers = await firestore
            .collection('mothers')
            .where('patientUid', isEqualTo: patientUid)
            .get();
        expect(mothers.docs, hasLength(1));
        final mother = mothers.docs.single;
        expect(mother.data()['assignedAshaId'], ashaUid);
        expect(mother.data()['id'], mother.id);
        final patient = await firestore
            .collection('users')
            .doc(patientUid)
            .get();
        expect(patient.data()?['assignedMotherId'], mother.id);
      },
    );

    test(
      'createMother leaves neither write when patient linking fails',
      () async {
        final (firestore, service) = await setup(createPatient: false);

        await expectLater(
          service.createMother(
            userId: patientUid,
            name: 'Test Mother',
            pregnancyWeek: 20,
            status: 'active',
          ),
          throwsA(anything),
        );

        expect((await firestore.collection('mothers').get()).docs, isEmpty);
        expect(
          (await firestore.collection('users').doc(patientUid).get()).exists,
          isFalse,
        );
      },
    );

    test(
      'createMotherProfile creates the mother and links the patient',
      () async {
        final (firestore, service) = await setup(createPatient: true);

        final motherId = await service.createMotherProfile(
          name: 'Test Mother',
          age: 28,
          phone: '1234567890',
          gestationalWeeks: 20,
          bloodPressure: '110/70',
          weight: 60,
          hemoglobin: 12,
          symptoms: const [],
          emergencyContact: '1234567890',
          assignedAshaId: ashaUid,
          patientUid: patientUid,
        );

        final mother = await firestore
            .collection('mothers')
            .doc(motherId)
            .get();
        expect(mother.exists, isTrue);
        expect(mother.data()?['patientUid'], patientUid);
        expect(mother.data()?['assignedAshaId'], ashaUid);
        final patient = await firestore
            .collection('users')
            .doc(patientUid)
            .get();
        expect(patient.data()?['assignedMotherId'], motherId);
      },
    );

    test(
      'createMotherProfile leaves no mother when patient linking fails',
      () async {
        final (firestore, service) = await setup(createPatient: false);

        await expectLater(
          service.createMotherProfile(
            name: 'Test Mother',
            age: 28,
            phone: '1234567890',
            gestationalWeeks: 20,
            bloodPressure: '110/70',
            weight: 60,
            hemoglobin: 12,
            symptoms: const [],
            emergencyContact: '1234567890',
            assignedAshaId: ashaUid,
            patientUid: patientUid,
          ),
          throwsA(anything),
        );

        expect((await firestore.collection('mothers').get()).docs, isEmpty);
        expect(
          (await firestore.collection('users').doc(patientUid).get()).exists,
          isFalse,
        );
      },
    );
  });
}
