import '../../core/constants/app_enums.dart';
import '../../models/risk_result.dart';

class RiskEngine {
  RiskResult assess({
    required int pregnancyWeek,
    required String bloodPressure,
    required double hemoglobin,
    required double weight,
    List<String> symptoms = const [],
  }) {
    int score = 0;
    final matchedRules = <String>[];

    // Blood pressure
    final bpParts = bloodPressure.split('/');

    if (bpParts.length == 2) {
      final systolic = int.tryParse(bpParts[0].trim());
      final diastolic = int.tryParse(bpParts[1].trim());

      if (systolic != null && diastolic != null) {
        if (systolic >= 160 || diastolic >= 110) {
          score += 50;
          matchedRules.add('Severely elevated blood pressure');
        } else if (systolic >= 140 || diastolic >= 90) {
          score += 35;
          matchedRules.add('Elevated blood pressure');
        } else if (systolic >= 130 || diastolic >= 80) {
          score += 15;
          matchedRules.add('Blood pressure above target range');
        }
      }
    }

    // Hemoglobin
    if (hemoglobin < 7) {
      score += 40;
      matchedRules.add('Severely low hemoglobin');
    } else if (hemoglobin < 10) {
      score += 25;
      matchedRules.add('Low hemoglobin');
    } else if (hemoglobin < 11) {
      score += 10;
      matchedRules.add('Mildly low hemoglobin');
    }

    // Pregnancy week validation
    if (pregnancyWeek < 1 || pregnancyWeek > 42) {
      score += 20;
      matchedRules.add('Pregnancy week outside expected range');
    }

    // Symptoms
    for (final symptom in symptoms) {
      final normalized = symptom.toLowerCase().trim();

      if (normalized.contains('bleeding')) {
        score += 40;
        matchedRules.add('Bleeding reported');
      }

      if (normalized.contains('severe headache')) {
        score += 30;
        matchedRules.add('Severe headache reported');
      }

      if (normalized.contains('blurred vision')) {
        score += 30;
        matchedRules.add('Vision changes reported');
      }

      if (normalized.contains('chest pain')) {
        score += 40;
        matchedRules.add('Chest pain reported');
      }

      if (normalized.contains('breathing difficulty') ||
          normalized.contains('shortness of breath')) {
        score += 40;
        matchedRules.add('Breathing difficulty reported');
      }

      if (normalized.contains('severe abdominal pain')) {
        score += 35;
        matchedRules.add('Severe abdominal pain reported');
      }
    }

    score = score.clamp(0, 100);

    final riskLevel = _getRiskLevel(score);

    if (matchedRules.isEmpty) {
      matchedRules.add('No major risk indicators detected');
    }

    final explanation = _buildExplanation(
      riskLevel,
      score,
      matchedRules,
    );

    return RiskResult(
      riskLevel: riskLevel,
      matchedRules: matchedRules,
      explanation: explanation,
      recommendation: _recommendation(riskLevel),
      ruleVersion: 'v1.0',
      timestamp: DateTime.now(),
    );
  }

  RiskLevel _getRiskLevel(int score) {
    if (score >= 45) {
      return RiskLevel.high;
    }

    if (score >= 20) {
      return RiskLevel.moderate;
    }

    return RiskLevel.low;
  }

  String _buildExplanation(
    RiskLevel riskLevel,
    int score,
    List<String> matchedRules,
  ) {
    final level = riskLevel.name;

    return 'Risk assessment: $level '
        '(score $score/100). '
        'The assessment was influenced by: '
        '${matchedRules.join(', ')}.';
  }

  String _recommendation(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.high:
        return 'Contact the healthcare team promptly for further assessment.';

      case RiskLevel.moderate:
        return 'Continue monitoring and discuss the findings with the healthcare team.';

      case RiskLevel.low:
        return 'Continue routine maternal monitoring and scheduled care.';
    }
  }
}