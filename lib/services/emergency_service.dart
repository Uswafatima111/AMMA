import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Client-side emergency workflow. Firestore rules remain the authorization
/// boundary; these checks provide early, useful errors to callers.
class EmergencyService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  EmergencyService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const statuses = {'active', 'responded', 'resolved'};

  static bool canTransition(String from, String to) =>
      (from == 'active' && to == 'responded') ||
      (from == 'responded' && to == 'resolved');

  static bool patientOwnsRequest({
    required String authenticatedUid,
    required String patientId,
  }) => authenticatedUid.isNotEmpty && authenticatedUid == patientId;

  static bool isAssignedAsha({
    required String authenticatedUid,
    required String role,
    required String? assignedAshaId,
    required String? motherAssignedAshaId,
  }) {
    // assignedAshaId is intentionally historical and must not gate current
    // access after a mother is reassigned.
    return authenticatedUid.isNotEmpty &&
        role == 'asha' &&
        motherAssignedAshaId == authenticatedUid;
  }

  static bool hasValidMotherAssignment({
    required bool hasLinkedMother,
    required String? motherId,
    required String? assignedAshaId,
  }) => hasLinkedMother
      ? motherId != null && motherId.isNotEmpty
      : motherId == null && assignedAshaId == null;

  static void validateTransition(String from, String to) {
    if (!canTransition(from, to)) {
      throw StateError('Invalid emergency status transition: $from -> $to.');
    }
  }

  static Map<String, dynamic> resolutionUpdate(String responderId) => {
    'status': 'resolved',
    'resolvedAt': FieldValue.serverTimestamp(),
    'resolvedBy': responderId,
  };

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Authentication required.');
    }
    return uid;
  }

  Future<String> _role(String uid) async {
    final profile = await _firestore.collection('users').doc(uid).get();
    final role = profile.data()?['role'];
    if (!profile.exists || (role != 'asha' && role != 'patient')) {
      throw StateError('A valid user profile is required.');
    }
    return role as String;
  }

  Future<Map<String, dynamic>?> _motherForPatient(String uid) async {
    final linked = await _firestore
        .collection('mothers')
        .where('patientUid', isEqualTo: uid)
        .limit(2)
        .get();
    if (linked.docs.length > 1) {
      throw StateError('Multiple mother profiles are linked to this patient.');
    }
    if (linked.docs.length == 1) {
      return {...linked.docs.first.data(), 'id': linked.docs.first.id};
    }
    final legacy = await _firestore.collection('mothers').doc(uid).get();
    return legacy.exists ? {...legacy.data()!, 'id': legacy.id} : null;
  }

  Future<String> createEmergency({
    required String userId,
    required String message,
    double? latitude,
    double? longitude,
  }) async {
    final uid = _requireUid();
    if (!patientOwnsRequest(authenticatedUid: uid, patientId: userId)) {
      throw StateError('Patient ID must match the signed-in user.');
    }
    if (await _role(uid) != 'patient') {
      throw StateError('Only patients can create emergencies.');
    }
    if (message.trim().isEmpty) {
      throw ArgumentError('Emergency message cannot be empty.');
    }
    if ((latitude == null) != (longitude == null) ||
        (latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180))) {
      throw ArgumentError(
        'Coordinates must be a valid latitude/longitude pair.',
      );
    }

    final mother = await _motherForPatient(uid);
    final motherId = mother?['id'] as String?;
    final assignedAshaId = mother?['assignedAshaId'] as String?;
    if (!hasValidMotherAssignment(
      hasLinkedMother: mother != null,
      motherId: motherId,
      assignedAshaId: assignedAshaId,
    )) {
      throw StateError('Emergency request mother assignment is invalid.');
    }
    final data = <String, dynamic>{
      'patientId': uid,
      'motherId': motherId,
      'assignedAshaId': assignedAshaId,
      'message': message.trim(),
      'type': 'medical_emergency',
      'severity': 'critical',
      'status': 'active',
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
      'respondedBy': null,
      'resolvedAt': null,
      'resolvedBy': null,
    };
    final ref = await _firestore.collection('emergency_requests').add(data);
    return ref.id;
  }

  /// Assigned ASHA requests only. An ASHA without a UID sees no documents.
  Stream<QuerySnapshot<Map<String, dynamic>>> getActiveEmergencies() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }
    return _firestore
        .collection('mothers')
        .where('assignedAshaId', isEqualTo: uid)
        .snapshots()
        .asyncExpand((mothers) {
          final motherIds = mothers.docs.map((doc) => doc.id).toList();
          if (motherIds.isEmpty) return const Stream.empty();
          // Rules evaluate the mother lookup for each potential result, with
          // a 10-call access limit per query. Keep the query within that
          // bound; merging multiple queries needs a different public API.
          if (motherIds.length > 10) {
            return Stream<QuerySnapshot<Map<String, dynamic>>>.error(
              StateError(
                'This ASHA has more than 10 assigned mothers; emergency query '
                'cannot safely represent the full assignment set.',
              ),
            );
          }
          return _firestore
              .collection('emergency_requests')
              .where('motherId', whereIn: motherIds)
              .where('status', isNotEqualTo: 'resolved')
              .snapshots();
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPatientEmergencies(
    String patientId,
  ) {
    final uid = _requireUid();
    if (patientId != uid) {
      throw StateError('Patients may view only their own requests.');
    }
    return _firestore
        .collection('emergency_requests')
        .where('patientId', isEqualTo: uid)
        .snapshots();
  }

  Future<void> respondToEmergency({
    required String emergencyId,
    required String responderId,
  }) async {
    final uid = _requireUid();
    if (responderId != uid || await _role(uid) != 'asha') {
      throw StateError('Only the signed-in ASHA can respond.');
    }
    await _transition(emergencyId, 'responded', uid);
  }

  Future<void> resolveEmergency(String emergencyId) async {
    final uid = _requireUid();
    if (await _role(uid) != 'asha') {
      throw StateError('Only an ASHA can resolve emergencies.');
    }
    await _transition(emergencyId, 'resolved', uid);
  }

  Future<void> _transition(String id, String next, String uid) async {
    final ref = _firestore.collection('emergency_requests').doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw StateError('Emergency request not found.');
      }
      final data = snapshot.data()!;
      final motherId = data['motherId'];
      if (motherId is! String || motherId.isEmpty) {
        throw StateError('Emergency has no assigned mother.');
      }
      final mother = await transaction.get(
        _firestore.collection('mothers').doc(motherId),
      );
      if (!mother.exists ||
          !isAssignedAsha(
            authenticatedUid: uid,
            role: 'asha',
            assignedAshaId: data['assignedAshaId'] as String?,
            motherAssignedAshaId: mother.data()?['assignedAshaId'] as String?,
          )) {
        throw StateError('Emergency mother is not assigned to this ASHA.');
      }
      final current = data['status'] as String?;
      if (current == null) throw StateError('Emergency status is missing.');
      validateTransition(current, next);
      transaction.update(
        ref,
        next == 'responded'
            ? {
                'status': next,
                'respondedAt': FieldValue.serverTimestamp(),
                'respondedBy': uid,
              }
            : resolutionUpdate(uid),
      );
    });
  }
}
