import 'package:amma/core/constants/app_enums.dart';
import 'package:amma/services/emergency_service.dart';
import 'package:amma/services/referral_service.dart';
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
  const patientUid = 'patient-1';
  const ashaUid = 'asha-1';
  const motherId = 'mother-1';

  Future<FakeFirebaseFirestore> setup() async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(patientUid).set({
      'id': patientUid,
      'role': 'patient',
      'assignedMotherId': motherId,
    });
    await firestore.collection('users').doc(ashaUid).set({
      'id': ashaUid,
      'role': 'asha',
    });
    await firestore.collection('users').doc('asha-2').set({
      'id': 'asha-2',
      'role': 'asha',
    });
    await firestore.collection('mothers').doc(motherId).set({
      'id': motherId,
      'patientUid': patientUid,
      'assignedAshaId': ashaUid,
    });
    return firestore;
  }

  group('Emergency service', () {
    test(
      'creates an emergency linked to the authenticated patient mother',
      () async {
        final firestore = await setup();
        final service = EmergencyService(
          firestore: firestore,
          auth: _TestAuth(patientUid),
        );

        final id = await service.createEmergency(
          userId: patientUid,
          message: 'Please help.',
        );
        final request =
            (await firestore.collection('emergency_requests').doc(id).get())
                .data()!;

        expect(request['patientId'], patientUid);
        expect(request['motherId'], motherId);
        expect(request['assignedAshaId'], ashaUid);
        expect(request['status'], 'active');
      },
    );

    test('rejects a conflicting legacy mother identity', () async {
      final firestore = await setup();
      await firestore.collection('mothers').doc(motherId).delete();
      await firestore.collection('mothers').doc(patientUid).set({
        'id': patientUid,
        'userId': patientUid,
        'patientUid': 'another-patient',
        'assignedAshaId': ashaUid,
      });
      final service = EmergencyService(
        firestore: firestore,
        auth: _TestAuth(patientUid),
      );

      await expectLater(
        service.createEmergency(userId: patientUid, message: 'Please help.'),
        throwsStateError,
      );
      expect(
        (await firestore.collection('emergency_requests').get()).docs,
        isEmpty,
      );
    });

    test(
      'responds then resolves while preserving responder metadata',
      () async {
        final firestore = await setup();
        final patientService = EmergencyService(
          firestore: firestore,
          auth: _TestAuth(patientUid),
        );
        final id = await patientService.createEmergency(
          userId: patientUid,
          message: 'Please help.',
        );
        final ashaService = EmergencyService(
          firestore: firestore,
          auth: _TestAuth(ashaUid),
        );

        await ashaService.respondToEmergency(
          emergencyId: id,
          responderId: ashaUid,
        );
        final responded =
            (await firestore.collection('emergency_requests').doc(id).get())
                .data()!;
        await ashaService.resolveEmergency(id);
        final resolved =
            (await firestore.collection('emergency_requests').doc(id).get())
                .data()!;

        expect(resolved['status'], 'resolved');
        expect(resolved['respondedBy'], ashaUid);
        expect(resolved['respondedAt'], responded['respondedAt']);
        expect(resolved['resolvedBy'], ashaUid);
        expect(resolved['resolvedAt'], isA<Timestamp>());
        expect(resolved['patientId'], patientUid);
        expect(resolved['motherId'], motherId);
        expect(resolved['assignedAshaId'], ashaUid);
      },
    );

    test('rejects patients and unrelated ASHAs from responding', () async {
      final firestore = await setup();
      final patientService = EmergencyService(
        firestore: firestore,
        auth: _TestAuth(patientUid),
      );
      final id = await patientService.createEmergency(
        userId: patientUid,
        message: 'Please help.',
      );
      final unrelatedService = EmergencyService(
        firestore: firestore,
        auth: _TestAuth('asha-2'),
      );

      await expectLater(patientService.resolveEmergency(id), throwsStateError);
      await expectLater(
        unrelatedService.respondToEmergency(
          emergencyId: id,
          responderId: 'asha-2',
        ),
        throwsStateError,
      );
      expect(
        (await firestore.collection('emergency_requests').doc(id).get())
            .data()?['status'],
        'active',
      );
    });
  });

  group('Referral service', () {
    test('supports acceptance followed by completion', () async {
      final firestore = await setup();
      final service = ReferralService(
        firestore: firestore,
        auth: _TestAuth(ashaUid),
      );

      final id = await service.createReferral(
        motherId: motherId,
        facility: 'Community Health Center',
      );
      await service.updateStatus(
        referralId: id,
        status: ReferralStatus.accepted,
      );
      await service.updateStatus(
        referralId: id,
        status: ReferralStatus.completed,
      );
      final referral = (await firestore.collection('referrals').doc(id).get())
          .data()!;

      expect(referral['status'], 'completed');
      expect(referral['motherId'], motherId);
      expect(referral['referringAshaId'], ashaUid);
      expect(referral['facility'], 'Community Health Center');
      expect(referral['acceptedAt'], isA<Timestamp>());
      expect(referral['completedAt'], isA<Timestamp>());
      expect(referral['cancelledAt'], isNull);
    });

    test('supports cancellation from pending and accepted states', () async {
      final firestore = await setup();
      final service = ReferralService(
        firestore: firestore,
        auth: _TestAuth(ashaUid),
      );
      final pendingId = await service.createReferral(
        motherId: motherId,
        facility: 'Clinic A',
      );
      await service.updateStatus(
        referralId: pendingId,
        status: ReferralStatus.cancelled,
      );
      final acceptedId = await service.createReferral(
        motherId: motherId,
        facility: 'Clinic B',
      );
      await service.updateStatus(
        referralId: acceptedId,
        status: ReferralStatus.accepted,
      );
      await service.updateStatus(
        referralId: acceptedId,
        status: ReferralStatus.cancelled,
      );

      final pendingCancelled =
          (await firestore.collection('referrals').doc(pendingId).get())
              .data()!;
      final acceptedCancelled =
          (await firestore.collection('referrals').doc(acceptedId).get())
              .data()!;
      expect(pendingCancelled['status'], 'cancelled');
      expect(pendingCancelled['acceptedAt'], isNull);
      expect(pendingCancelled['cancelledAt'], isA<Timestamp>());
      expect(acceptedCancelled['status'], 'cancelled');
      expect(acceptedCancelled['acceptedAt'], isA<Timestamp>());
      expect(acceptedCancelled['cancelledAt'], isA<Timestamp>());
    });

    test('denies an unrelated ASHA from changing referral status', () async {
      final firestore = await setup();
      final creator = ReferralService(
        firestore: firestore,
        auth: _TestAuth(ashaUid),
      );
      final id = await creator.createReferral(
        motherId: motherId,
        facility: 'Clinic',
      );
      final unrelated = ReferralService(
        firestore: firestore,
        auth: _TestAuth('asha-2'),
      );

      await expectLater(
        unrelated.updateStatus(referralId: id, status: ReferralStatus.accepted),
        throwsStateError,
      );
      expect(
        (await firestore.collection('referrals').doc(id).get())
            .data()?['status'],
        'pending',
      );
    });
  });
}
