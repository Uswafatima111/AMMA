import '../core/constants/app_enums.dart';

class RiskResult {
  final RiskLevel riskLevel;
  final List<String> matchedRules;
  final String explanation;
  final String recommendation;
  final String ruleVersion;
  final DateTime timestamp;

  const RiskResult({
    required this.riskLevel,
    required this.matchedRules,
    required this.explanation,
    required this.recommendation,
    required this.ruleVersion,
    required this.timestamp,
  });
}