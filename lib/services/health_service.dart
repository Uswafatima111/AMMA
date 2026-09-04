import '../models/risk_result.dart';
import 'health_record_service.dart';
import 'ai_risk_service.dart';

/// Now wired to Uswa's real risk engine (pulled from backend-uswa).
/// Flow: save the health record to Firestore, then ask AiRiskService to
/// assess the most recently saved record for this mother.
///
/// ⚠ STILL OPEN WITH USWA:
///   - symptoms aren't factored into the score yet — her assessLatestRecord()
///     doesn't fetch or pass them to RiskEngine, even though RiskEngine
///     supports a symptoms parameter. Ask her to wire that through.
///   - userId vs motherId naming is still unconfirmed — passing mother.id as
///     userId for both the write and the read, so they stay internally
///     consistent even if the naming itself isn't resolved yet.
class HealthService {
  final HealthRecordService _healthRecordService = HealthRecordService();
  final AiRiskService _aiRiskService = AiRiskService();

  Future<RiskResult> submitHealthCheck({
    required String motherId,
    required int gestationalWeeks,
    required String bloodPressure,
    required double weight,
    required double hemoglobin,
    required List<String> symptoms,
  }) async {
    // Step 1: save the health record for real.
    await _healthRecordService.addHealthRecord(
      userId: motherId,
      bloodPressure: bloodPressure,
      weight: weight,
      hemoglobin: hemoglobin,
      symptoms: symptoms, // requires the symptoms param we added locally
    );

    // Step 2: ask the real risk engine to assess what was just saved.
    final result = await _aiRiskService.assessLatestRecord(
      userId: motherId,
      pregnancyWeek: gestationalWeeks,
    );

    if (result == null) {
      throw Exception('No health record found to assess — try again.');
    }

    return result;
  }
}