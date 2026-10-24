import 'package:cloud_firestore/cloud_firestore.dart';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    return _firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  /// Contract-based alert stream for a mother.
  ///
  /// This compatibility method filters locally; do not use it as
  /// a production authorization boundary.
  Stream<List<Map<String, dynamic>>> watchAlertsForMother(String motherId) {
    if (motherId.trim().isEmpty) {
      throw ArgumentError('motherId cannot be empty.');
    }

    return _firestore.collection('alerts').snapshots().map((snapshot) {
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
        final aDate = a['createdAt'];
        final bDate = b['createdAt'];

        final aMillis = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
        final bMillis = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;

        return bMillis.compareTo(aMillis);
      });

      return matching;
    });
  }

  Future<void> markAsRead(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).update({
      'isRead': true,
      'status': 'read',
    });
  }

  Future<void> deleteAlert(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).delete();
  }

  /// Updates an alert's workflow status.
  Future<void> updateAlertStatus({
    required String alertId,
    required String status,
  }) async {
    const allowedStatuses = {
      'open',
      'read',
      'pending',
      'accepted',
      'completed',
      'cancelled',
      'resolved',
    };

    if (!allowedStatuses.contains(status)) {
      throw ArgumentError('Alert status is invalid.');
    }

    await _firestore.collection('alerts').doc(alertId).update({
      'status': status,
    });
  }
}
