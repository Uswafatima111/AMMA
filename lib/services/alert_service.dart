import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';

class AlertService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AlertService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const patientHelpRequestTypes = {
    'benefit_help',
    'appointment_request',
  };

  static const alertStatuses = {
    'open',
    'read',
    'pending',
    'accepted',
    'completed',
    'cancelled',
    'resolved',
  };

  static const Map<String, Set<String>> alertStatusTransitions = {
    'open': {'read', 'pending', 'accepted', 'cancelled'},
    'read': {'pending', 'accepted', 'cancelled'},
    'pending': {'accepted', 'cancelled'},
    'accepted': {'completed', 'cancelled'},
  };

  static bool canTransitionAlertStatus(String from, String to) =>
      alertStatusTransitions[from]?.contains(to) ?? false;

  /// Creates a stored help request for the authenticated patient's own mother.
  /// This does not send a notification or guarantee a response.
  Future<String> createPatientHelpRequest({
    required String type,
    required String message,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Authentication required.');
    }
    if (!patientHelpRequestTypes.contains(type)) {
      throw ArgumentError('Patient help request type is invalid.');
    }
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty || trimmedMessage.length > 1000) {
      throw ArgumentError('Message must contain 1 to 1000 characters.');
    }

    final profile = await _firestore.collection('users').doc(uid).get();
    if (!profile.exists || profile.data()?['role'] != 'patient') {
      throw StateError('A patient profile is required.');
    }

    final mother = await _resolvePatientMother(uid, profile.data()!);
    if (mother == null) {
      throw StateError('No linked maternal profile was found.');
    }
    final motherData = mother.data()!;
    if (motherData['patientUid'] != uid && mother.id != uid) {
      throw StateError(
        'The linked maternal profile belongs to another patient.',
      );
    }
    final assignedAshaId = motherData['assignedAshaId'];
    if (assignedAshaId is! String || assignedAshaId.isEmpty) {
      throw StateError('The linked maternal profile has no assigned ASHA.');
    }

    final alertRef = _firestore.collection('alerts').doc();
    await alertRef.set({
      'id': alertRef.id,
      'userId': uid,
      'motherId': mother.id,
      'assignedAshaId': assignedAshaId,
      'type': type,
      'riskLevel': 'low',
      'message': trimmedMessage,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return alertRef.id;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolvePatientMother(
    String uid,
    Map<String, dynamic> profile,
  ) async {
    final assignedMotherId = profile['assignedMotherId'];
    if (assignedMotherId is String && assignedMotherId.isNotEmpty) {
      final linked = await _firestore
          .collection('mothers')
          .doc(assignedMotherId)
          .get();
      return linked.exists ? linked : null;
    }

    final linkedMothers = await _firestore
        .collection('mothers')
        .where('patientUid', isEqualTo: uid)
        .limit(2)
        .get();
    if (linkedMothers.docs.length > 1) {
      throw StateError(
        'More than one mother profile is linked to this patient.',
      );
    }
    if (linkedMothers.docs.length == 1) return linkedMothers.docs.single;

    final legacy = await _firestore.collection('mothers').doc(uid).get();
    return legacy.exists ? legacy : null;
  }

  /// Legacy method for existing screens.
  Future<void> createAlert({
    required String userId,
    required String title,
    required String message,
    required String type,
    required String severity,
  }) async {
    final alertRef = _firestore.collection('alerts').doc();

    await alertRef.set({
      'id': alertRef.id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'severity': severity,
      'riskLevel': severity,
      'status': 'open',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// New contract-based alert creation.
  Future<String> createAlertForMother({
    required String motherId,
    required String type,
    required String riskLevel,
    required String message,
    String status = 'open',
  }) async {
    if (motherId.trim().isEmpty) {
      throw ArgumentError('motherId cannot be empty.');
    }

    const allowedRiskLevels = {'low', 'moderate', 'high'};
    if (!allowedRiskLevels.contains(riskLevel)) {
      throw ArgumentError('Risk level must be low, moderate, or high.');
    }

    final alertRef = _firestore.collection('alerts').doc();

    await alertRef.set({
      'id': alertRef.id,
      'motherId': motherId,
      'type': type,
      'riskLevel': riskLevel,
      'message': message,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return alertRef.id;
  }

  /// Legacy alert stream.
  Stream<QuerySnapshot<Map<String, dynamic>>> getAlerts(String userId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || userId != uid) {
      return Stream.error(
        StateError('Patients may only read their own alerts.'),
      );
    }
    return _firestore.collection('users').doc(uid).snapshots().asyncExpand((
      profile,
    ) {
      if (!profile.exists || profile.data()?['role'] != 'patient') {
        return Stream<QuerySnapshot<Map<String, dynamic>>>.error(
          StateError('A patient profile is required to read patient alerts.'),
        );
      }
      return Stream.fromFuture(
        FirestoreService(
          firestore: _firestore,
          auth: _auth,
        ).getMotherForPatient(uid),
      ).asyncExpand((mother) {
        final motherId = mother?['id'];
        if (motherId is! String || motherId.isEmpty) {
          return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
        }
        return _firestore
            .collection('alerts')
            .where('motherId', isEqualTo: motherId)
            .snapshots();
      });
    });
  }

  /// Streams alerts for one stable mother ID. Firestore rules authorize each
  /// matching alert for the linked patient or currently assigned ASHA.
  Stream<List<Map<String, dynamic>>> watchAlertsForMother(String motherId) {
    if (motherId.trim().isEmpty) {
      throw ArgumentError('motherId cannot be empty.');
    }

    return _firestore
        .collection('alerts')
        .where('motherId', isEqualTo: motherId)
        .snapshots()
        .map((snapshot) {
          final matching = snapshot.docs.map((document) {
            return <String, dynamic>{...document.data(), 'id': document.id};
          }).toList();

          matching.sort((a, b) {
            final aDate = a['createdAt'];
            final bDate = b['createdAt'];

            final aMillis = aDate is Timestamp
                ? aDate.millisecondsSinceEpoch
                : 0;
            final bMillis = bDate is Timestamp
                ? bDate.millisecondsSinceEpoch
                : 0;

            return bMillis.compareTo(aMillis);
          });

          return matching;
        });
  }

  Future<void> markAsRead(String alertId) async {
    await updateAlertStatus(alertId: alertId, status: 'read');
  }

  /// Acknowledges an open patient help request once for its assigned ASHA.
  /// Returns false when the request is already in another status.
  Future<bool> markAsReadIfOpen(String alertId) async {
    final (alertRef, data) = await _loadAuthorizedHelpRequest(alertId);
    if (data['status'] != 'open') return false;
    if (!canTransitionAlertStatus('open', 'read')) {
      throw StateError('An open help request cannot be acknowledged.');
    }

    await alertRef.update({'status': 'read'});
    return true;
  }

  Future<void> deleteAlert(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).delete();
  }

  /// Updates an alert's workflow status.
  Future<void> updateAlertStatus({
    required String alertId,
    required String status,
  }) async {
    if (!alertStatuses.contains(status)) {
      throw ArgumentError('Alert status is invalid.');
    }

    final (alertRef, data) = await _loadAuthorizedHelpRequest(alertId);
    if (!canTransitionAlertStatus(data['status'] as String? ?? '', status)) {
      throw StateError(
        'Alert status cannot transition from ${data['status']} to $status.',
      );
    }

    // Only status changes. Request identity and creation fields remain fixed.
    await alertRef.update({'status': status});
  }

  Future<(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>
  _loadAuthorizedHelpRequest(String alertId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Authentication required.');
    }
    final profile = await _firestore.collection('users').doc(uid).get();
    if (!profile.exists || profile.data()?['role'] != 'asha') {
      throw StateError('Only an ASHA can update a help request.');
    }

    final alertRef = _firestore.collection('alerts').doc(alertId);
    final alert = await alertRef.get();
    if (!alert.exists) throw StateError('Alert was not found.');
    final data = alert.data()!;
    if (!patientHelpRequestTypes.contains(data['type'])) {
      throw StateError('Only help requests can be updated.');
    }
    final motherId = data['motherId'];
    if (motherId is! String || motherId.isEmpty) {
      throw StateError('The alert has no valid mother ID.');
    }
    final mother = await _firestore.collection('mothers').doc(motherId).get();
    if (!mother.exists || mother.data()?['assignedAshaId'] != uid) {
      throw StateError('The ASHA is not currently assigned to this mother.');
    }
    return (alertRef, data);
  }
}
