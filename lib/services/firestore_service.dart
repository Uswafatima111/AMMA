import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ------------------------------------------------------------
  // LEGACY COMPATIBILITY
  // Keep these methods while existing screens use userId and
  // pregnancyWeek. Do not remove until the frontend is integrated.
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> getMother(String userId) async {
    final document = await _firestore.collection('mothers').doc(userId).get();

    if (!document.exists) {
      return null;
    }

    final data = document.data()!;
    return {
      ...data,
      'id': document.id,
      'gestationalWeeks': data['gestationalWeeks'] ?? data['pregnancyWeek'],
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMothers() {
    return _firestore.collection('mothers').orderBy('name').snapshots();
  }

  // Legacy method used by existing screens.
  Future<void> createMother({
    required String userId,
    required String name,
    required int pregnancyWeek,
    required String status,
  }) async {
    await _firestore.collection('mothers').doc(userId).set({
      'id': userId,
      'userId': userId,
      'name': name,
      'pregnancyWeek': pregnancyWeek,
      'gestationalWeeks': pregnancyWeek,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      data['patientUid'] = patientUid.trim();
    }

    if (expectedDeliveryDate != null) {
      data['expectedDeliveryDate'] = Timestamp.fromDate(expectedDeliveryDate);
    }

    await motherRef.set(data);
    return motherRef.id;
  }

  /// Gets a mother using her stable motherId.
  Future<Map<String, dynamic>?> getMotherById(String motherId) async {
    final document = await _firestore.collection('mothers').doc(motherId).get();

    if (!document.exists) {
      return null;
    }

    return {...document.data()!, 'id': document.id};
  }

  /// Finds the mother linked to a patient's Firebase Auth UID.
  ///
  /// Falls back to the legacy UID-as-document-ID convention.
  Future<Map<String, dynamic>?> getMotherForPatient(String patientUid) async {
    final linkedMothers = await _firestore
        .collection('mothers')
        .where('patientUid', isEqualTo: patientUid)
        .limit(2)
        .get();

    if (linkedMothers.docs.length > 1) {
      throw StateError(
        'More than one mother profile is linked to this patient UID.',
      );
    }

    if (linkedMothers.docs.length == 1) {
      final document = linkedMothers.docs.first;
      return {...document.data(), 'id': document.id};
    }

    // Backward compatibility for older profiles.
    return getMother(patientUid);
  }

  /// Streams mothers assigned to the specified ASHA UID.
  Stream<QuerySnapshot<Map<String, dynamic>>> getMothersAssignedToAsha(
    String ashaUid,
  ) {
    return _firestore
        .collection('mothers')
        .where('assignedAshaId', isEqualTo: ashaUid)
        .snapshots();
  }
}
