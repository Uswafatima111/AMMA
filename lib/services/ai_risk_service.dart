import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/risk_result.dart';
import '../screens/ai/risk_engine.dart';

class AiRiskService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final RiskEngine _riskEngine = RiskEngine();

  Future<RiskResult?> assessLatestRecord({
    required String userId,
    required int pregnancyWeek,
  }) async {
    final snapshot = await _firestore
        .collection('health_records')
        .where('userId', isEqualTo: userId)
        .get();

    if (snapshot.docs.isEmpty) return null;

    QueryDocumentSnapshot<Map<String, dynamic>> latest = snapshot.docs.first;
    for (final document in snapshot.docs.skip(1)) {
      final latestTimestamp = latest.data()['recordedAt'];
      final currentTimestamp = document.data()['recordedAt'];
      if (currentTimestamp is Timestamp &&
          (latestTimestamp is! Timestamp || currentTimestamp.compareTo(latestTimestamp) > 0)) {
        latest = document;
      }
    }

    final data = latest.data();
    final bloodPressure = data['bloodPressure']?.toString() ?? '';
    final weightValue = data['weight'];
    final hemoglobinValue = data['hemoglobin'];

    final weight = weightValue is num ? weightValue.toDouble() : double.tryParse(weightValue?.toString() ?? '') ?? 0;
    final hemoglobin = hemoglobinValue is num ? hemoglobinValue.toDouble() : double.tryParse(hemoglobinValue?.toString() ?? '') ?? 0;

    // FIX: symptoms weren't being read from Firestore or passed to the
    // engine before — this is the one-line fix for the demo.
    final symptomsValue = data['symptoms'];
    final symptoms = symptomsValue is List
        ? symptomsValue.map((s) => s.toString()).toList()
        : <String>[];

    return _riskEngine.assess(
      pregnancyWeek: pregnancyWeek,
      bloodPressure: bloodPressure,
      hemoglobin: hemoglobin,
      weight: weight,
      symptoms: symptoms, // <- the actual fix
    );
  }
}