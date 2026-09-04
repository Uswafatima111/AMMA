import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/risk_result.dart';
import '../screens/ai/risk_engine.dart';

class AiRiskService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final RiskEngine _riskEngine = RiskEngine();

  Future<RiskResult?> assessLatestRecord({
    required String userId,
    required int pregnancyWeek,
  }) async {
    final snapshot = await _firestore
        .collection('health_records')
        .where('userId', isEqualTo: userId)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    // Find the most recent health record without requiring
    // a Firestore composite index.
    QueryDocumentSnapshot<Map<String, dynamic>> latest =
        snapshot.docs.first;

    for (final document in snapshot.docs.skip(1)) {
      final latestTimestamp =
          latest.data()['recordedAt'];

      final currentTimestamp =
          document.data()['recordedAt'];

      if (currentTimestamp is Timestamp &&
          (latestTimestamp is! Timestamp ||
              currentTimestamp
                  .compareTo(latestTimestamp) >
                  0)) {
        latest = document;
      }
    }

    final data = latest.data();

    final bloodPressure =
        data['bloodPressure']?.toString() ?? '';

    final weightValue = data['weight'];

    final hemoglobinValue = data['hemoglobin'];

    final weight = weightValue is num
        ? weightValue.toDouble()
        : double.tryParse(
              weightValue?.toString() ?? '',
            ) ??
            0;

    final hemoglobin = hemoglobinValue is num
        ? hemoglobinValue.toDouble()
        : double.tryParse(
              hemoglobinValue?.toString() ?? '',
            ) ??
            0;

    return _riskEngine.assess(
      pregnancyWeek: pregnancyWeek,
      bloodPressure: bloodPressure,
      hemoglobin: hemoglobin,
      weight: weight,
    );
  }
}