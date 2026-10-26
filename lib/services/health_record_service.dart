import 'package:cloud_firestore/cloud_firestore.dart';

class HealthRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    final resolvedMotherId = motherId?.trim().isNotEmpty == true
        ? motherId!.trim()
        : userId?.trim();

    if (resolvedMotherId == null || resolvedMotherId.isEmpty) {
      throw ArgumentError('A motherId or legacy userId is required.');
    }

    final recordRef = _firestore.collection('health_records').doc();
    final timestamp = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'id': recordRef.id,
      'motherId': resolvedMotherId,
      'userId': userId ?? resolvedMotherId,
      'bloodPressure': bloodPressure,
      'weight': weight,
      'hemoglobin': hemoglobin,
      'symptoms': symptoms,
      'date': timestamp,
      'recordedAt': timestamp,
      'notes': notes ?? '',
    };

    if (riskLevel != null) data['riskLevel'] = riskLevel;
    if (matchedRules.isNotEmpty) data['matchedRules'] = matchedRules;
    if (explanation != null) data['explanation'] = explanation;
    if (recommendation != null) data['recommendation'] = recommendation;
    if (ruleVersion != null) data['ruleVersion'] = ruleVersion;

    await recordRef.set(data);
    return recordRef.id;
  }

  /// Streams records for a mother, including legacy records.
  ///
  /// Records are combined client-side to avoid requiring a composite index.
  Stream<List<Map<String, dynamic>>> watchHealthRecords({
    String? motherId,
    String? userId,
  }) {
    final resolvedId = motherId?.trim().isNotEmpty == true
        ? motherId!.trim()
        : userId?.trim();

    if (resolvedId == null || resolvedId.isEmpty) {
      throw ArgumentError('A motherId or legacy userId is required.');
    }

    return _firestore.collection('health_records').snapshots().map((snapshot) {
      final matching = snapshot.docs
          .where((document) {
            final data = document.data();
            return data['motherId'] == resolvedId ||
                data['userId'] == resolvedId;
          })
          .map((document) {
            return <String, dynamic>{...document.data(), 'id': document.id};
          })
          .toList();

      matching.sort((a, b) {
        final aDate = a['date'] ?? a['recordedAt'];
        final bDate = b['date'] ?? b['recordedAt'];

        final aMillis = aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
        final bMillis = bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;

        return bMillis.compareTo(aMillis);
      });

      return matching;
    });
  }

  /// Legacy stream signature used by existing code.
  Stream<QuerySnapshot<Map<String, dynamic>>> getHealthRecords(String userId) {
    return _firestore
        .collection('health_records')
        .where('userId', isEqualTo: userId)
        .snapshots();
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
