import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/risk_result.dart';
import '../screens/ai/risk_engine.dart';
import 'firestore_service.dart';

class AiRiskService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AiRiskService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final RiskEngine _riskEngine = RiskEngine();

  /// Assesses the newest available health record.
  ///
  /// Existing callers can continue passing userId.
  /// New callers should pass motherId.
  Future<RiskResult?> assessLatestRecord({
    String? userId,
    String? motherId,
    required int pregnancyWeek,
  }) async {
    var resolvedMotherId = motherId?.trim();
    var unlinkedPatientUid = '';
    if (resolvedMotherId?.isNotEmpty != true) {
      final uid = _auth.currentUser?.uid;
      if (uid == null || uid.isEmpty || userId?.trim() != uid) {
        throw StateError('A patient may assess only their own health records.');
      }
      final mother = await FirestoreService(
        firestore: _firestore,
        auth: _auth,
      ).getMotherForPatient(uid);
      resolvedMotherId = mother?['id'] as String?;
      if (resolvedMotherId == null || resolvedMotherId.isEmpty) {
        unlinkedPatientUid = uid;
      }
    }

    if ((resolvedMotherId == null || resolvedMotherId.isEmpty) &&
        unlinkedPatientUid.isEmpty) {
      throw ArgumentError('A motherId or legacy userId is required.');
    }

    final collection = _firestore.collection('health_records');

    // Linked patients and assigned ASHAs use only the canonical, authorized
    // motherId query. A userId-only query is reserved for genuinely unlinked
    // patients whose legacy records are authorized by the rules.
    final results = await (resolvedMotherId?.isNotEmpty == true
        ? Future.wait([
            collection.where('motherId', isEqualTo: resolvedMotherId).get(),
          ])
        : Future.wait([
            collection.where('userId', isEqualTo: unlinkedPatientUid).get(),
          ]));

    // Merge results and remove duplicates by document ID.
    final documents = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final snapshot in results) {
      for (final document in snapshot.docs) {
        documents[document.id] = document;
      }
    }

    if (documents.isEmpty) return null;

    int timestampMillis(Map<String, dynamic> data) {
      final value = data['date'] ?? data['recordedAt'];
      return value is Timestamp ? value.millisecondsSinceEpoch : 0;
    }

    final ordered = documents.values.toList()
      ..sort(
        (a, b) =>
            timestampMillis(b.data()).compareTo(timestampMillis(a.data())),
      );

    final data = ordered.first.data();

    final bloodPressure = data['bloodPressure']?.toString() ?? '';

    final weightValue = data['weight'];
    final hemoglobinValue = data['hemoglobin'];

    double? parseMeasurement(dynamic value) {
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      return parsed != null && parsed.isFinite ? parsed : null;
    }

    // Keep absent or malformed values absent. The risk engine reports them as
    // invalid inputs instead of silently converting them to zero readings.
    final weight = parseMeasurement(weightValue);
    final hemoglobin = parseMeasurement(hemoglobinValue);

    final rawSymptoms = data['symptoms'];
    final symptoms = rawSymptoms is List
        ? rawSymptoms.map((item) => item.toString()).toList()
        : <String>[];

    return _riskEngine.assess(
      pregnancyWeek: pregnancyWeek,
      bloodPressure: bloodPressure,
      hemoglobin: hemoglobin,
      weight: weight,
      symptoms: symptoms,
    );
  }
}
