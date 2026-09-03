import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create an appointment.
  Future<void> createAppointment({
    required String userId,
    required String title,
    required String doctorName,
    required DateTime date,
    String? notes,
  }) async {
    await _firestore.collection('appointments').add({
      'userId': userId,
      'title': title,
      'doctorName': doctorName,
      'date': Timestamp.fromDate(date),
      'status': 'scheduled',
      'notes': notes ?? '',
    });
  }

  // Get appointments for a patient.
  Stream<QuerySnapshot<Map<String, dynamic>>> getAppointments(
    String userId,
  ) {
    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .orderBy('date')
        .snapshots();
  }

  // Update appointment status.
  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    await _firestore
        .collection('appointments')
        .doc(appointmentId)
        .update({
      'status': status,
    });
  }

  // Delete an appointment.
  Future<void> deleteAppointment(String appointmentId) async {
    await _firestore
        .collection('appointments')
        .doc(appointmentId)
        .delete();
  }
}