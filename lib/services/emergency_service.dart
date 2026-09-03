import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new emergency request.
  Future<String> createEmergency({
    required String userId,
    required String message,
    double? latitude,
    double? longitude,
  }) async {
    final document = await _firestore
        .collection('emergency_requests')
        .add({
      'patientId': userId,
      'message': message,
      'type': 'medical_emergency',
      'severity': 'critical',
      'status': 'active',
      'targetRoles': [
        'asha',
        'doctor',
        'ambulance',
      ],
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
      'respondedBy': null,
    });

    return document.id;
  }

  // Get active emergency requests.
  Stream<QuerySnapshot<Map<String, dynamic>>>
      getActiveEmergencies() {
    return _firestore
        .collection('emergency_requests')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  // Get emergencies created by a patient.
  Stream<QuerySnapshot<Map<String, dynamic>>>
      getPatientEmergencies(String patientId) {
    return _firestore
        .collection('emergency_requests')
        .where(
          'patientId',
          isEqualTo: patientId,
        )
        .snapshots();
  }

  // Mark an emergency as responded to.
  Future<void> respondToEmergency({
    required String emergencyId,
    required String responderId,
  }) async {
    await _firestore
        .collection('emergency_requests')
        .doc(emergencyId)
        .update({
      'status': 'responded',
      'respondedAt': FieldValue.serverTimestamp(),
      'respondedBy': responderId,
    });
  }

  // Resolve an emergency.
  Future<void> resolveEmergency(
    String emergencyId,
  ) async {
    await _firestore
        .collection('emergency_requests')
        .doc(emergencyId)
        .update({
      'status': 'resolved',
    });
  }
}