import 'package:cloud_firestore/cloud_firestore.dart';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create an alert.
  Future<void> createAlert({
    required String userId,
    required String title,
    required String message,
    required String type,
    required String severity,
  }) async {
    await _firestore.collection('alerts').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'severity': severity,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get alerts for a patient.
  Stream<QuerySnapshot<Map<String, dynamic>>> getAlerts(
    String userId,
  ) {
    return _firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Mark an alert as read.
  Future<void> markAsRead(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).update({
      'isRead': true,
    });
  }

  // Delete an alert.
  Future<void> deleteAlert(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).delete();
  }
}