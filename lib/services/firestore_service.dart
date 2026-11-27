import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static String? resolvePatientMotherId({
    required String patientUid,
    required Iterable<Map<String, dynamic>> mothers,
  }) {
    final matches = mothers
        .where((mother) => mother['patientUid'] == patientUid)
        .toList();
    if (matches.length > 1) {
      throw StateError('More than one mother profile is linked to this patient UID.');
    }
    if (matches.isEmpty) return null;
    final id = matches.single['id'];
    if (id is! String || id.trim().isEmpty) {
      throw StateError('The linked mother profile has no stable document ID.');
    }
    return id;
  }

  static String? resolveAssignedMotherId({
    required String legacyUserId,
    required Iterable<Map<String, dynamic>> mothers,
  }) {
    final matches = mothers.where((mother) =>
        mother['id'] == legacyUserId ||
        mother['userId'] == legacyUserId ||
        mother['patientUid'] == legacyUserId).toList();
    if (matches.length > 1) {
      throw StateError('The legacy patient identifier matches multiple mothers.');
    }
    if (matches.isEmpty) return null;
    final id = matches.single['id'];
    if (id is! String || id.trim().isEmpty) {
      throw StateError('The assigned mother profile has no stable document ID.');
    }
    return id;
  }

  // ------------------------------------------------------------
  // LEGACY COMPATIBILITY
  // Keep these methods while existing screens use userId and
  // pregnancyWeek. Do not remove until the frontend is integrated.
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> getMother(String userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw StateError('Authentication required.');
    final role = await _role(uid);

    if (role == 'patient') {
      if (userId != uid) {
        throw StateError('Patients may only retrieve their own linked profile.');
      }
      return getMotherForPatient(uid);
    }
    if (role != 'asha') throw StateError('A valid user role is required.');
    return getMotherById(userId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMothers() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream.error(StateError('Authentication required.'));
    }
    return _firestore.collection('users').doc(uid).get().asStream().asyncExpand((profile) {
      final role = profile.data()?['role'];
      if (!profile.exists || (role != 'asha' && role != 'patient')) {
        return Stream<QuerySnapshot<Map<String, dynamic>>>.error(
          StateError('A valid user profile is required.'),
        );
      }
      final query = _firestore.collection('mothers');
      return (role == 'asha'
              ? query.where('assignedAshaId', isEqualTo: uid)
              : query.where('patientUid', isEqualTo: uid))
          .snapshots();
    });
  }

  // Legacy method used by existing screens.
  Future<void> createMother({
    required String userId,
    required String name,
    required int pregnancyWeek,
    required String status,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || await _role(uid) != 'asha') {
      throw StateError('Only an authenticated ASHA can register a mother.');
    }
    final patient = await _firestore.collection('users').doc(userId).get();
    if (!patient.exists || patient.data()?['role'] != 'patient') {
      throw StateError('The linked patient profile does not exist.');
    }
    final existingLinks = await _firestore
        .collection('mothers')
        .where('assignedAshaId', isEqualTo: uid)
        .get();
    if (existingLinks.docs.any((doc) => doc.data()['patientUid'] == userId)) {
      throw StateError('This patient already has a linked mother profile.');
    }
    final ref = _firestore.collection('mothers').doc();
    final data = <String, dynamic>{
      'id': ref.id,
      'userId': userId,
      'patientUid': userId,
      'assignedAshaId': uid,
      'name': name,
      'pregnancyWeek': pregnancyWeek,
      'gestationalWeeks': pregnancyWeek,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) throw StateError('Mother ID collision; retry creation.');
      transaction.set(ref, data);
    });
  }

  // Legacy update method.
  Future<void> updateMother({
    required String userId,
    String? name,
    int? pregnancyWeek,
    String? status,
  }) async {
    final data = <String, dynamic>{};

    if (name != null) {
      data['name'] = name;
    }

    if (pregnancyWeek != null) {
      data['pregnancyWeek'] = pregnancyWeek;
      data['gestationalWeeks'] = pregnancyWeek;
    }

    if (status != null) {
      data['status'] = status;
    }

    if (data.isNotEmpty) {
      await _firestore.collection('mothers').doc(userId).update(data);
    }
  }

  Future<void> deleteMother(String userId) async {
    await _firestore.collection('mothers').doc(userId).delete();
  }

  // ------------------------------------------------------------
  // NEW SHARED CONTRACT METHODS
  // ------------------------------------------------------------

  /// Creates a complete maternal profile and returns its stable ID.
  ///
  /// patientUid is optional because an ASHA worker may register a
  /// mother before she has an app account.
  ///
  /// expectedDeliveryDate is optional until a clinically confirmed
  /// due date is available.
  Future<String> createMotherProfile({
    required String name,
    required int age,
    required String phone,
    required int gestationalWeeks,
    required String bloodPressure,
    required double weight,
    required double hemoglobin,
    required List<String> symptoms,
    required String emergencyContact,
    required String assignedAshaId,
    String riskLevel = 'low',
    String? patientUid,
    DateTime? expectedDeliveryDate,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || await _role(uid) != 'asha') {
      throw StateError('Only an authenticated ASHA can register a mother.');
    }
    if (assignedAshaId != uid) {
      throw StateError('A mother must be assigned to the authenticated ASHA.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Mother name cannot be empty.');
    }
    if (age < 1 || age > 120) {
      throw ArgumentError('Enter a valid age.');
    }
    if (gestationalWeeks < 1 || gestationalWeeks > 42) {
      throw ArgumentError('Gestational weeks must be between 1 and 42.');
    }
    if (weight <= 0 || hemoglobin <= 0) {
      throw ArgumentError('Weight and hemoglobin must be positive.');
    }

    const allowedRiskLevels = {'low', 'moderate', 'high'};
    if (!allowedRiskLevels.contains(riskLevel)) {
      throw ArgumentError('Risk level must be low, moderate, or high.');
    }

    final motherRef = _firestore.collection('mothers').doc();

    final data = <String, dynamic>{
      'id': motherRef.id,
      'name': name.trim(),
      'age': age,
      'phone': phone.trim(),
      'gestationalWeeks': gestationalWeeks,
      'bloodPressure': bloodPressure.trim(),
      'weight': weight,
      'hemoglobin': hemoglobin,
      'symptoms': symptoms,
      'emergencyContact': emergencyContact.trim(),
      'riskLevel': riskLevel,
      'assignedAshaId': assignedAshaId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (patientUid != null && patientUid.trim().isNotEmpty) {
      final normalizedPatientUid = patientUid.trim();
      final patient = await _firestore
          .collection('users')
          .doc(normalizedPatientUid)
          .get();
      if (!patient.exists || patient.data()?['role'] != 'patient') {
        throw StateError('The linked patient profile does not exist.');
      }
      final assignedMothers = await _firestore
          .collection('mothers')
          .where('assignedAshaId', isEqualTo: uid)
          .get();
      if (assignedMothers.docs.any(
        (doc) => doc.data()['patientUid'] == normalizedPatientUid,
      )) {
        throw StateError('This patient already has a linked mother profile.');
      }
      data['patientUid'] = normalizedPatientUid;
      // Compatibility alias for older callers. patientUid remains canonical.
      data['userId'] = normalizedPatientUid;
    }

    if (expectedDeliveryDate != null) {
      data['expectedDeliveryDate'] = Timestamp.fromDate(expectedDeliveryDate);
    }

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(motherRef);
      if (existing.exists) throw StateError('Mother ID collision; retry creation.');
      transaction.set(motherRef, data);
    });
    return motherRef.id;
  }

  /// Gets a mother using her stable motherId.
  Future<Map<String, dynamic>?> getMotherById(String motherId) async {
    final document = await _firestore.collection('mothers').doc(motherId).get();

    if (!document.exists) {
      return null;
    }

    final data = document.data()!;
    return {
      ...data,
      'id': document.id,
      'userId': data['userId'] ?? data['patientUid'] ?? document.id,
      'pregnancyWeek': data['pregnancyWeek'] ?? data['gestationalWeeks'],
      'gestationalWeeks': data['gestationalWeeks'] ?? data['pregnancyWeek'],
    };
  }

  /// Finds the mother linked to a patient's Firebase Auth UID.
  ///
  /// Falls back to the legacy UID-as-document-ID convention.
  Future<Map<String, dynamic>?> getMotherForPatient(String patientUid) async {
    final authenticatedUid = _auth.currentUser?.uid;
    if (authenticatedUid == null || authenticatedUid.isEmpty) {
      throw StateError('Authentication required.');
    }
    if (patientUid != authenticatedUid || await _role(authenticatedUid) != 'patient') {
      throw StateError('Only the authenticated patient can resolve their mother.');
    }
    final linkedMothers = await _firestore
        .collection('mothers')
        .where('patientUid', isEqualTo: authenticatedUid)
        .limit(2)
        .get();

    final linkedId = resolvePatientMotherId(
      patientUid: authenticatedUid,
      mothers: linkedMothers.docs.map((document) => {
        ...document.data(),
        'id': document.id,
      }),
    );
    if (linkedId != null) {
      final document = linkedMothers.docs.firstWhere((doc) => doc.id == linkedId);
      final data = document.data();
      return {
        ...data,
        'id': document.id,
        'userId': data['userId'] ?? authenticatedUid,
        'pregnancyWeek': data['pregnancyWeek'] ?? data['gestationalWeeks'],
        'gestationalWeeks': data['gestationalWeeks'] ?? data['pregnancyWeek'],
      };
    }

    // Backward compatibility for older profiles.
    final legacy = await _firestore.collection('mothers').doc(authenticatedUid).get();
    if (!legacy.exists) return null;
    final legacyData = legacy.data()!;
    if (legacyData['patientUid'] != null && legacyData['patientUid'] != authenticatedUid) {
      return null;
    }
    return {
      ...legacyData,
      'id': legacy.id,
      'gestationalWeeks': legacyData['gestationalWeeks'] ?? legacyData['pregnancyWeek'],
    };
  }

  /// Streams mothers assigned to the specified ASHA UID.
  Stream<QuerySnapshot<Map<String, dynamic>>> getMothersAssignedToAsha(
    String ashaUid,
  ) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || ashaUid != uid) {
      return Stream.error(StateError('An ASHA may list only their own assignments.'));
    }
    return _firestore
        .collection('mothers')
        .where('assignedAshaId', isEqualTo: ashaUid)
        .snapshots();
  }

  Future<String?> findAssignedMotherId(String legacyUserId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || await _role(uid) != 'asha') {
      throw StateError('Only an authenticated ASHA can resolve assigned mothers.');
    }
    final assigned = await _firestore
        .collection('mothers')
        .where('assignedAshaId', isEqualTo: uid)
        .get();
    return resolveAssignedMotherId(
      legacyUserId: legacyUserId,
      mothers: assigned.docs.map((doc) => {...doc.data(), 'id': doc.id}),
    );
  }

  Future<String?> _role(String uid) async {
    final profile = await _firestore.collection('users').doc(uid).get();
    final role = profile.data()?['role'];
    return profile.exists && (role == 'patient' || role == 'asha')
        ? role as String
        : null;
  }
}
