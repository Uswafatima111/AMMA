import '../models/risk_result.dart';
import '../screens/ai/risk_engine.dart';
import 'health_record_service.dart';

/// Coordinates Uswa's RiskEngine and HealthRecordService.
/// The clinical rules stay in RiskEngine.
class HealthService {
  final HealthRecordService _records = HealthRecordService();
  final RiskEngine _engine = RiskEngine();

  RiskResult assess({
    required int pregnancyWeek,
    required String bloodPressure,
    required double hemoglobin,
    required double weight,
    required List<String> symptoms,
  }) {
    return _engine.assess(
      pregnancyWeek: pregnancyWeek,
      bloodPressure: bloodPressure,
      hemoglobin: hemoglobin,
      weight: weight,
      symptoms: symptoms,
    );
  }

  Future<RiskResult> submitHealthCheck({
    required String motherId,
    required int gestationalWeeks,
    required String bloodPressure,
    required double weight,
    required double hemoglobin,
    required List<String> symptoms,
  }) async {
    final result = assess(
      pregnancyWeek: gestationalWeeks,
      bloodPressure: bloodPressure,
      hemoglobin: hemoglobin,
      weight: weight,
      symptoms: symptoms,
    );

    await _records.addHealthRecord(
      motherId: motherId,
      bloodPressure: bloodPressure,
      weight: weight,
      hemoglobin: hemoglobin,
      symptoms: symptoms,
      riskLevel: result.riskLevel.name,
      matchedRules: result.matchedRules,
      explanation: result.explanation,
      recommendation: result.recommendation,
      ruleVersion: result.ruleVersion,
    );

    // TODO: BACKEND INTEGRATION REQUIRED FROM USWA
    // updateMotherRiskLevel(motherId, riskLevel) on the mothers collection.

    return result;
  }
}