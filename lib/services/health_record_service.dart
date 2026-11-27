import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';

class HealthRecordService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  HealthRecordService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static bool patientOwnsRecord({
    required String authenticatedUid,
    required String patientUid,
  }) => authenticatedUid.isNotEmpty && authenticatedUid == patientUid;

  static bool ashaOwnsRecord({
    required String authenticatedUid,
    required String role,
    required String? assignedAshaId,
  }) =>
      authenticatedUid.isNotEmpty &&
      role == 'asha' &&
      assignedAshaId == authenticatedUid;

  static bool canAccessMother({
    required String authenticatedUid,
    required String role,
    required String motherId,
    required String? patientUid,
    required String? assignedAshaId,
  }) =>
      (role == 'patient' &&
          (patientOwnsRecord(
                authenticatedUid: authenticatedUid,
                patientUid: patientUid ?? '',
              ) ||
              (patientUid == null && motherId == authenticatedUid))) ||
      ashaOwnsRecord(
        authenticatedUid: authenticatedUid,
        role: role,
        assignedAshaId: assignedAshaId,
      );

  static void validateRecord({
    required String motherId,
    required String bloodPressure,
    required double weight,
    required double hemoglobin,
  }) {
    if (motherId.trim().isEmpty || bloodPressure.trim().isEmpty) {
      throw ArgumentError('A mother ID and blood pressure are required.');
    }
    if (!weight.isFinite || !hemoglobin.isFinite || weight <= 0 || hemoglobin <= 0) {
      throw ArgumentError('Weight and hemoglobin must be valid positive numbers.');
    }
  }

  /// Adds a health record using the new motherId contract.
  ///
  /// userId remains optional for compatibility with existing callers.
  /// Both date and recordedAt are written during the migration.
  Future<String> addHealthRecord({
    String? userId,
    String? motherId,
    required String bloodPressure,
    required double weight,
    required double hemoglobin,
    List<String> symptoms = const [],
    String? notes,
    String? riskLevel,
    List<String> matchedRules = const [],
    String? explanation,
    String? recommendation,
    String? ruleVersion,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw StateError('Authentication required.');
    final profile = await _firestore.collection('users').doc(uid).get();
    if (!profile.exists || profile.data()?['role'] != 'asha') {
      throw StateError('Only an authenticated ASHA can create health records.');
    }

    final requestedId = motherId?.trim().isNotEmpty == true
        ? motherId!.trim()
        : userId?.trim();
    if (requestedId == null || requestedId.isEmpty) {
      throw ArgumentError('A motherId or legacy userId is required.');
    }
    var resolvedMotherId = requestedId;
    final mother = await _firestore.collection('mothers').doc(requestedId).get();
    if (!mother.exists ||
        !ashaOwnsRecord(
          authenticatedUid: uid,
          role: profile.data()?['role'] as String,
          assignedAshaId: mother.data()?['assignedAshaId'] as String?,
        )) {
      if (motherId != null && motherId.trim().isNotEmpty) {
        throw StateError('Mother is not assigned to the authenticated ASHA.');
      }
      resolvedMotherId =
          await FirestoreService(
            firestore: _firestore,
            auth: _auth,
          ).findAssignedMotherId(requestedId) ??
          '';
      if (resolvedMotherId.isEmpty) {
        throw StateError('No assigned mother matches the supplied legacy ID.');
      }
    }
    validateRecord(
      motherId: resolvedMotherId,
      bloodPressure: bloodPressure,
      weight: weight,
      hemoglobin: hemoglobin,
    );

    final recordRef = _firestore.collection('health_records').doc();
    final timestamp = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'id': recordRef.id,
      'motherId': resolvedMotherId,
      'bloodPressure': bloodPressure,
      'weight': weight,
      'hemoglobin': hemoglobin,
      'symptoms': symptoms,
      'date': timestamp,
      'recordedAt': timestamp,
      'notes': notes ?? '',
      'createdBy': uid,
    };

    if (riskLevel != null) data['riskLevel'] = riskLevel;
    if (matchedRules.isNotEmpty) data['matchedRules'] = matchedRules;
    if (explanation != null) data['explanation'] = explanation;
    if (recommendation != null) data['recommendation'] = recommendation;
    if (ruleVersion != null) data['ruleVersion'] = ruleVersion;

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(recordRef);
      if (existing.exists) throw StateError('Health record ID collision; retry creation.');
      transaction.set(recordRef, data);
    });
    return recordRef.id;
  }

  /// Streams records for a mother, including legacy records.
  ///
  /// Records are combined client-side to avoid requiring a composite index.
  Stream<List<Map<String, dynamic>>> watchHealthRecords({
    String? motherId,
    String? userId,
  }) {
    final requestedMotherId = motherId?.trim();
    final legacyUserId = userId?.trim();

    if ((requestedMotherId == null || requestedMotherId.isEmpty) &&
        (legacyUserId == null || legacyUserId.isEmpty)) {
      throw ArgumentError('A motherId or legacy userId is required.');
    }
    final source = requestedMotherId != null && requestedMotherId.isNotEmpty
        ? _recordsForMother(requestedMotherId)
        : getHealthRecords(legacyUserId!);
    return source.map(
      (snapshot) => snapshot.docs
          .map((document) => <String, dynamic>{...document.data(), 'id': document.id})
          .toList(),
    );
  }

  /// Legacy stream signature used by existing code.
  Stream<QuerySnapshot<Map<String, dynamic>>> getHealthRecords(String userId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream.error(StateError('Authentication required.'));
    }
    final collection = _firestore.collection('health_records');
    return _firestore.collection('users').doc(uid).get().asStream().asyncExpand((profile) async* {
      final role = profile.data()?['role'];
      if (!profile.exists || (role != 'patient' && role != 'asha')) {
        throw StateError('A valid user profile is required.');
      }

      String? resolvedMotherId;
      if (role == 'patient') {
        if (!patientOwnsRecord(authenticatedUid: uid, patientUid: userId)) {
          throw StateError('Patients may only read their own health records.');
        }
        final linked = await _firestore
            .collection('mothers')
            .where('patientUid', isEqualTo: uid)
            .limit(2)
            .get();
        resolvedMotherId = FirestoreService.resolvePatientMotherId(
          patientUid: uid,
          mothers: linked.docs.map((doc) => {...doc.data(), 'id': doc.id}),
        );
        if (resolvedMotherId == null) {
          final legacy = await _firestore.collection('mothers').doc(uid).get();
          if (legacy.exists &&
              (legacy.data()?['patientUid'] == null || legacy.data()?['patientUid'] == uid)) {
            resolvedMotherId = legacy.id;
          }
        }
        if (resolvedMotherId == null) {
          // Preserve access to old self-owned records only when no mother link
          // or legacy mother document can be resolved.
          yield* collection.where('userId', isEqualTo: uid).snapshots();
          return;
        }
      } else {
        final ashaService = FirestoreService(firestore: _firestore, auth: _auth);
        resolvedMotherId = await ashaService.findAssignedMotherId(userId);
        if (resolvedMotherId == null) {
          throw StateError('No assigned mother matches this health-record query.');
        }
      }

      yield* collection.where('motherId', isEqualTo: resolvedMotherId).snapshots();
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _recordsForMother(String motherId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream.error(StateError('Authentication required.'));
    }
    return _firestore.collection('users').doc(uid).get().asStream().asyncExpand((profile) async* {
      final role = profile.data()?['role'];
      if (!profile.exists || (role != 'patient' && role != 'asha')) {
        throw StateError('A valid user profile is required.');
      }
      final mother = await _firestore.collection('mothers').doc(motherId).get();
      if (!mother.exists) throw StateError('Mother profile not found.');
      final motherData = mother.data()!;
      if (!canAccessMother(
        authenticatedUid: uid,
        role: role as String,
        motherId: motherId,
        patientUid: motherData['patientUid'] as String?,
        assignedAshaId: motherData['assignedAshaId'] as String?,
      )) {
        throw StateError('Mother is not linked or assigned to this user.');
      }
      yield* _firestore
          .collection('health_records')
          .where('motherId', isEqualTo: motherId)
          .snapshots();
    });
  }

  Future<Map<String, dynamic>?> getHealthRecord(String recordId) async {
    final document = await _firestore
        .collection('health_records')
        .doc(recordId)
        .get();

    if (!document.exists) return null;

    return {...document.data()!, 'id': document.id};
  }

  Future<void> deleteHealthRecord(String recordId) async {
    await _firestore.collection('health_records').doc(recordId).delete();
  }
}
