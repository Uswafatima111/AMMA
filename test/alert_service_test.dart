import 'package:amma/services/alert_service.dart';
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
  const motherId = 'mother-1';
  const assignedAshaId = 'asha-1';

  Future<(FakeFirebaseFirestore, AlertService)> setup({
    String role = 'patient',
    bool linked = true,
  }) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc(patientUid).set({
      'id': patientUid,
      'role': role,
      'assignedMotherId': motherId,
    });
    if (linked) {
      await firestore.collection('mothers').doc(motherId).set({
        'id': motherId,
        'patientUid': patientUid,
        'assignedAshaId': assignedAshaId,
      });
    }
    return (
      firestore,
      AlertService(firestore: firestore, auth: _TestAuth(patientUid)),
    );
  }

  group('Patient help requests', () {
    for (final type in AlertService.patientHelpRequestTypes) {
      test('creates a $type request for the linked mother', () async {
        final (firestore, service) = await setup();

        final alertId = await service.createPatientHelpRequest(
          type: type,
          message: 'Please contact me about this request.',
        );

        final alert = await firestore.collection('alerts').doc(alertId).get();
        expect(alert.exists, isTrue);
        expect(alert.data(), containsPair('id', alertId));
        expect(alert.data(), containsPair('userId', patientUid));
        expect(alert.data(), containsPair('motherId', motherId));
        expect(alert.data(), containsPair('assignedAshaId', assignedAshaId));
        expect(alert.data(), containsPair('type', type));
        expect(alert.data(), containsPair('status', 'open'));
      });
    }

    test('rejects non-patients and patients without a linked mother', () async {
      final (nonPatientFirestore, nonPatientService) = await setup(
        role: 'asha',
      );
      await expectLater(
        nonPatientService.createPatientHelpRequest(
          type: 'benefit_help',
          message: 'Help',
        ),
        throwsStateError,
      );
      expect(
        (await nonPatientFirestore.collection('alerts').get()).docs,
        isEmpty,
      );

      final (unlinkedFirestore, unlinkedService) = await setup(linked: false);
      await expectLater(
        unlinkedService.createPatientHelpRequest(
          type: 'benefit_help',
          message: 'Help',
        ),
        throwsStateError,
      );
      expect(
        (await unlinkedFirestore.collection('alerts').get()).docs,
        isEmpty,
      );
    });

    test('rejects unsupported types and empty messages', () async {
      final (firestore, service) = await setup();
      await expectLater(
        service.createPatientHelpRequest(
          type: 'medical_emergency',
          message: 'Help',
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.createPatientHelpRequest(type: 'benefit_help', message: '  '),
        throwsArgumentError,
      );
      expect((await firestore.collection('alerts').get()).docs, isEmpty);
    });
  });

  group('Help request status lifecycle', () {
    Future<(FakeFirebaseFirestore, AlertService)> setupAsAsha({
      String ashaUid = assignedAshaId,
      String currentMotherAshaId = assignedAshaId,
    }) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc(ashaUid).set({
        'id': ashaUid,
        'role': 'asha',
      });
      await firestore.collection('mothers').doc(motherId).set({
        'id': motherId,
        'patientUid': patientUid,
        'assignedAshaId': currentMotherAshaId,
      });
      await firestore.collection('alerts').doc('help-request').set({
        'id': 'help-request',
        'userId': patientUid,
        'motherId': motherId,
        'assignedAshaId': assignedAshaId,
        'type': 'benefit_help',
        'riskLevel': 'low',
        'message': 'Please help.',
        'status': 'open',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(100),
      });
      return (
        firestore,
        AlertService(firestore: firestore, auth: _TestAuth(ashaUid)),
      );
    }

    test(
      'uses only the existing statuses and permitted forward transitions',
      () {
        expect(AlertService.canTransitionAlertStatus('open', 'read'), isTrue);
        expect(
          AlertService.canTransitionAlertStatus('read', 'pending'),
          isTrue,
        );
        expect(
          AlertService.canTransitionAlertStatus('pending', 'accepted'),
          isTrue,
        );
        expect(
          AlertService.canTransitionAlertStatus('accepted', 'completed'),
          isTrue,
        );
        expect(
          AlertService.canTransitionAlertStatus('accepted', 'cancelled'),
          isTrue,
        );
        expect(
          AlertService.canTransitionAlertStatus('completed', 'open'),
          isFalse,
        );
        expect(
          AlertService.canTransitionAlertStatus('resolved', 'completed'),
          isFalse,
        );
        expect(AlertService.alertStatuses, contains('resolved'));
      },
    );

    test('assigned ASHA advances a request by changing only status', () async {
      final (firestore, service) = await setupAsAsha();

      await service.markAsRead('help-request');
      for (final status in ['pending', 'accepted', 'completed']) {
        await service.updateAlertStatus(
          alertId: 'help-request',
          status: status,
        );
      }

      final request = await firestore
          .collection('alerts')
          .doc('help-request')
          .get();
      expect(request.data(), {
        'id': 'help-request',
        'userId': patientUid,
        'motherId': motherId,
        'assignedAshaId': assignedAshaId,
        'type': 'benefit_help',
        'riskLevel': 'low',
        'message': 'Please help.',
        'status': 'completed',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(100),
      });
    });

    test('acknowledges an open request once and skips later opens', () async {
      final (firestore, service) = await setupAsAsha();

      expect(await service.markAsReadIfOpen('help-request'), isTrue);
      expect(await service.markAsReadIfOpen('help-request'), isFalse);
      expect(
        (await firestore.collection('alerts').doc('help-request').get())
            .data()?['status'],
        'read',
      );
    });

    test('rejects invalid transitions without changing the request', () async {
      final (firestore, service) = await setupAsAsha();

      await expectLater(
        service.updateAlertStatus(alertId: 'help-request', status: 'completed'),
        throwsStateError,
      );
      await expectLater(
        service.updateAlertStatus(alertId: 'help-request', status: 'resolved'),
        throwsStateError,
      );

      final request = await firestore
          .collection('alerts')
          .doc('help-request')
          .get();
      expect(request.data()?['status'], 'open');
    });

    test('patient cannot acknowledge a help request', () async {
      final (firestore, _) = await setupAsAsha();
      await firestore.collection('users').doc(patientUid).set({
        'id': patientUid,
        'role': 'patient',
      });
      final patientService = AlertService(
        firestore: firestore,
        auth: _TestAuth(patientUid),
      );

      await expectLater(
        patientService.markAsRead('help-request'),
        throwsStateError,
      );
      await expectLater(
        patientService.markAsReadIfOpen('help-request'),
        throwsStateError,
      );
      expect(
        (await firestore.collection('alerts').doc('help-request').get())
            .data()?['status'],
        'open',
      );
    });

    test('denies patient and unrelated ASHA updates', () async {
      final (patientFirestore, _) = await setupAsAsha();
      await patientFirestore.collection('users').doc(patientUid).set({
        'id': patientUid,
        'role': 'patient',
      });
      final patientService = AlertService(
        firestore: patientFirestore,
        auth: _TestAuth(patientUid),
      );
      await expectLater(
        patientService.updateAlertStatus(
          alertId: 'help-request',
          status: 'read',
        ),
        throwsStateError,
      );

      final (unrelatedFirestore, unrelatedService) = await setupAsAsha(
        ashaUid: 'asha-2',
      );
      await expectLater(
        unrelatedService.updateAlertStatus(
          alertId: 'help-request',
          status: 'read',
        ),
        throwsStateError,
      );
      await expectLater(
        unrelatedService.markAsReadIfOpen('help-request'),
        throwsStateError,
      );
      expect(
        (await unrelatedFirestore
                .collection('alerts')
                .doc('help-request')
                .get())
            .data()?['status'],
        'open',
      );
    });

    test(
      'current assigned ASHA can update while the recorded assignment stays immutable',
      () async {
        final (firestore, service) = await setupAsAsha(
          ashaUid: 'asha-2',
          currentMotherAshaId: 'asha-2',
        );

        await service.updateAlertStatus(
          alertId: 'help-request',
          status: 'read',
        );

        final request = await firestore
            .collection('alerts')
            .doc('help-request')
            .get();
        expect(request.data()?['status'], 'read');
        expect(request.data()?['assignedAshaId'], assignedAshaId);
      },
    );
  });

  test('mother alert stream returns only the requested mother ID', () async {
    final (firestore, service) = await setup();
    await firestore.collection('alerts').doc('own-alert').set({
      'motherId': motherId,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(10),
    });
    await firestore.collection('alerts').doc('other-alert').set({
      'motherId': 'another-mother',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(20),
    });

    final alerts = await service.watchAlertsForMother(motherId).first;

    expect(alerts, hasLength(1));
    expect(alerts.single['id'], 'own-alert');
  });

  test(
    'patient alert stream is scoped to the verified linked mother',
    () async {
      final (firestore, service) = await setup();
      await firestore.collection('alerts').doc('own-mother-alert').set({
        'id': 'own-mother-alert',
        'userId': patientUid,
        'motherId': motherId,
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(10),
      });
      await firestore.collection('alerts').doc('forged-user-alert').set({
        'id': 'forged-user-alert',
        'userId': patientUid,
        'motherId': 'another-mother',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(20),
      });

      final alerts = await service.getAlerts(patientUid).first;

      expect(alerts.docs.map((document) => document.id), ['own-mother-alert']);
    },
  );
}
