import '../models/risk_result.dart';
import '../screens/ai/risk_engine.dart';
import 'health_record_service.dart';

/// TEMPORARY: bypasses Firestore for the risk assessment step so the
/// health check flow works without Firebase running. Calls RiskEngine
/// directly with the form data instead of writing to Firestore and
/// reading it back via AiRiskService.
///
/// The Firestore save is still attempted (fire-and-forget) so data isn't
/// lost once Firebase is back up, but it no longer blocks the result.
///
/// ⚠ REVERT NOTE: once Firebase is confirmed working again, swap back to
/// calling _aiRiskService.assessLatestRecord() so the real saved record
/// (with server timestamp) is what gets assessed — this local version
/// assesses the form input directly, not what's actually in Firestore.
class HealthService {
  final HealthRecordService _healthRecordService = HealthRecordService();
  final RiskEngine _riskEngine = RiskEngine();

  Future<RiskResult> submitHealthCheck({
    required String motherId,
    required int gestationalWeeks,
    required String bloodPressure,
    required double weight,
    required double hemoglobin,
    required List<String> symptoms,
  }) async {
    // Try to save to Firestore, but don't let a failure block the result.
    try {
      await _healthRecordService.addHealthRecord(
        userId: motherId,
        bloodPressure: bloodPressure,
        weight: weight,
        hemoglobin: hemoglobin,
        symptoms: symptoms,
      );
    } catch (_) {
      // Firebase not available right now — ignore and continue locally.
    }

    // Assess directly from form input, no Firestore round trip needed.
    return _riskEngine.assess(
      pregnancyWeek: gestationalWeeks,
      bloodPressure: bloodPressure,
      hemoglobin: hemoglobin,
      weight: weight,
      symptoms: symptoms,
    );
  }
}