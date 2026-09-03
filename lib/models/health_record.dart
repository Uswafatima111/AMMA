class HealthRecord {
  final String id;
  final String motherId;
  final DateTime date;
  final String bloodPressure;
  final double hemoglobin;
  final double weight;
  final List<String> symptoms;
  final String riskLevel;
  final List<String> matchedRules;
  final String explanation;
  final String recommendation;
  final String ruleVersion;

  const HealthRecord({
    required this.id,
    required this.motherId,
    required this.date,
    required this.bloodPressure,
    required this.hemoglobin,
    required this.weight,
    required this.symptoms,
    required this.riskLevel,
    required this.matchedRules,
    required this.explanation,
    required this.recommendation,
    required this.ruleVersion,
  });
}
