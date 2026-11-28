import 'package:amma/screens/asha/asha_help_requests_section.dart';
import 'package:amma/services/alert_service.dart';
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
  testWidgets('opening an open request acknowledges it once', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('asha-1').set({
      'id': 'asha-1',
      'role': 'asha',
    });
    await firestore.collection('mothers').doc('mother-1').set({
      'id': 'mother-1',
      'patientUid': 'patient-1',
      'assignedAshaId': 'asha-1',
    });
    await firestore.collection('alerts').doc('request-1').set({
      'id': 'request-1',
      'userId': 'patient-1',
      'motherId': 'mother-1',
      'assignedAshaId': 'asha-1',
      'type': 'benefit_help',
      'message': 'Please help me apply for benefits.',
      'status': 'open',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1),
    });
    final alertService = AlertService(
      firestore: firestore,
      auth: _TestAuth('asha-1'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AshaHelpRequestsSection(
            motherId: 'mother-1',
            alertService: alertService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Benefit help request'));
    await tester.pumpAndSettle();
    expect(find.text('Please help me apply for benefits.'), findsOneWidget);
    expect(
      (await firestore.collection('alerts').doc('request-1').get())
          .data()?['status'],
      'read',
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Benefit help request'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      (await firestore.collection('alerts').doc('request-1').get())
          .data()?['status'],
      'read',
    );
  });
}
