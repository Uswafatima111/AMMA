import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/risk_result.dart';
import '../screens/ai/risk_engine.dart';

class AiRiskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    final resolvedId = motherId?.trim().isNotEmpty == true
        ? motherId!.trim()
        : userId?.trim();

    if (resolvedId == null || resolvedId.isEmpty) {
      throw ArgumentError('A motherId or legacy userId is required.');
    }

    final collection = _firestore.collection('health_records');

    final results = await Future.wait([
      collection.where('motherId', isEqualTo: resolvedId).get(),
      collection.where('userId', isEqualTo: resolvedId).get(),
    ]);

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
