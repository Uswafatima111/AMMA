import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Legacy appointment creation. Existing screens can still use this.
  Future<void> createAppointment({
    required String userId,
    required String title,
    required String doctorName,
    required DateTime date,
    String? notes,
  }) async {
    final appointmentRef = _firestore.collection('appointments').doc();

    await appointmentRef.set({
      'id': appointmentRef.id,
      'userId': userId,
      'title': title,
      'doctorName': doctorName,
      'date': Timestamp.fromDate(date),
      'status': 'scheduled',
      'notes': notes ?? '',
      'reminderEnabled': true,
    });
  }

  /// New contract-based appointment creation.
  Future<String> createAppointmentForMother({
    required String motherId,
    required DateTime date,
    required String type,
    required String doctorName,
    required String facilityName,
    bool reminderEnabled = true,
    String status = 'scheduled',
    String? notes,
  }) async {
    const allowedTypes = {'routine', 'followUp', 'emergency'};

    if (motherId.trim().isEmpty) {
      throw ArgumentError('motherId cannot be empty.');
    }
    if (!allowedTypes.contains(type)) {
      throw ArgumentError('Appointment type is invalid.');
    }

    final appointmentRef = _firestore.collection('appointments').doc();

    await appointmentRef.set({
      'id': appointmentRef.id,
      'motherId': motherId,
      'date': Timestamp.fromDate(date),
      'type': type,
      'status': status,
      'reminderEnabled': reminderEnabled,
      'doctorName': doctorName,
      'facilityName': facilityName,
      'notes': notes ?? '',
    });

    return appointmentRef.id;
  }

  /// Legacy stream for existing screens.
  Stream<QuerySnapshot<Map<String, dynamic>>> getAppointments(String userId) {
    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  /// Stream appointments for a mother, including legacy records.
  ///
  /// Use only with appropriate Firestore security rules. This method
  /// combines the old and new schemas during migration.
  Stream<List<Map<String, dynamic>>> watchAppointmentsForMother(
    String motherId,
  ) {
    if (motherId.trim().isEmpty) {
      throw ArgumentError('motherId cannot be empty.');
    }

    return _firestore.collection('appointments').snapshots().map((snapshot) {
      final matching = snapshot.docs
          .where((document) {
            final data = document.data();
            return data['motherId'] == motherId || data['userId'] == motherId;
          })
          .map((document) {
            return <String, dynamic>{...document.data(), 'id': document.id};
          })
          .toList();

      matching.sort((a, b) {
        final aDate = a['date'];
        final bDate = b['date'];

        final aMillis = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
        final bMillis = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;

        return aMillis.compareTo(bMillis);
      });

      return matching;
    });
  }

  /// Returns the next future scheduled appointment, or null.
  Future<Map<String, dynamic>?> getUpcomingAppointment(String motherId) async {
    if (motherId.trim().isEmpty) {
      throw ArgumentError('motherId cannot be empty.');
    }

    final snapshot = await _firestore.collection('appointments').get();

    final now = DateTime.now();

    final upcoming =
        snapshot.docs.where((document) {
          final data = document.data();
          final belongsToMother =
              data['motherId'] == motherId || data['userId'] == motherId;
          final dateValue = data['date'];

          if (!belongsToMother || dateValue is! Timestamp) {
            return false;
          }

          final status = (data['status'] ?? 'scheduled').toString();
          final active = status == 'scheduled' || status == 'pending';

          return active && dateValue.toDate().isAfter(now);
        }).toList()..sort((a, b) {
          final aDate = a.data()['date'] as Timestamp;
          final bDate = b.data()['date'] as Timestamp;
          return aDate.compareTo(bDate);
        });

    if (upcoming.isEmpty) return null;

    final document = upcoming.first;

    return {
      ...document.data(),
      'id': document.id,
      'motherId': document.data()['motherId'] ?? motherId,
      'reminderEnabled': document.data()['reminderEnabled'] ?? false,
    };
  }

  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': status,
    });
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _firestore.collection('appointments').doc(appointmentId).delete();
  }
}
