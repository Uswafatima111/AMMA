import 'package:cloud_firestore/cloud_firestore.dart';

class HealthRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a health record for a patient.
  Future<void> addHealthRecord({
    required String userId,
    required String bloodPressure,
    required double weight,
    required double hemoglobin,
    String? notes,
  }) async {
    await _firestore.collection('health_records').add({
      'userId': userId,
      'bloodPressure': bloodPressure,
      'weight': weight,
      'hemoglobin': hemoglobin,
      'recordedAt': FieldValue.serverTimestamp(),
      'notes': notes ?? '',
    });
  }

  // Get all health records for a patient.
  Stream<QuerySnapshot<Map<String, dynamic>>> getHealthRecords(
    String userId,
  ) {
    return _firestore
        .collection('health_records')
        .where('userId', isEqualTo: userId)
      
        .snapshots();
  }

  // Get a single health record.
  Future<Map<String, dynamic>?> getHealthRecord(
    String recordId,
  ) async {
    final document = await _firestore
        .collection('health_records')
        .doc(recordId)
        .get();

    if (!document.exists) {
      return null;
    }

    return document.data();
  }

  // Delete a health record.
  Future<void> deleteHealthRecord(String recordId) async {
    await _firestore
        .collection('health_records')
        .doc(recordId)
        .delete();
  }
}