import '../../core/constants/app_enums.dart';
import '../../models/risk_result.dart';

class RiskEngine {
  // Broad input plausibility bounds, not clinical risk thresholds. They need
  // review by a qualified clinician before use in a clinical workflow.
  static const int _minimumSystolic = 50;
  static const int _maximumSystolic = 300;
  static const int _minimumDiastolic = 30;
  static const int _maximumDiastolic = 200;

  RiskResult assess({
    required int pregnancyWeek,
    required String? bloodPressure,
    required double? hemoglobin,
    required double? weight,
    List<String> symptoms = const [],
  }) {
    var score = 0;
    final matchedRules = <String>[];
    final invalidInputs = <String>[];

    // Invalid or absent data is reported but never treated as a risk finding.
    final bpMatch = RegExp(
      r'^(\d{2,3})\s*/\s*(\d{2,3})$',
    ).firstMatch((bloodPressure ?? '').trim());
    final systolic = int.tryParse(bpMatch?.group(1) ?? '');
    final diastolic = int.tryParse(bpMatch?.group(2) ?? '');
    final validBloodPressure =
        systolic != null &&
        diastolic != null &&
        systolic >= _minimumSystolic &&
        systolic <= _maximumSystolic &&
        diastolic >= _minimumDiastolic &&
        diastolic <= _maximumDiastolic &&
        systolic > diastolic;

    if (!validBloodPressure) {
      invalidInputs.add('blood pressure');
      matchedRules.add('Blood pressure missing or invalid; not scored');
    } else if (systolic >= 160 || diastolic >= 110) {
      score += 50;
      matchedRules.add('Severely elevated blood pressure');
    } else if (systolic >= 140 || diastolic >= 90) {
      score += 35;
      matchedRules.add('Elevated blood pressure');
    } else if (systolic >= 130 || diastolic >= 80) {
      score += 15;
      matchedRules.add('Blood pressure above target range');
    }

    if (hemoglobin == null || !hemoglobin.isFinite || hemoglobin <= 0) {
      invalidInputs.add('hemoglobin');
      matchedRules.add('Hemoglobin missing or invalid; not scored');
    } else if (hemoglobin < 7) {
      score += 40;
      matchedRules.add('Severely low hemoglobin');
    } else if (hemoglobin < 10) {
      score += 25;
      matchedRules.add('Low hemoglobin');
    } else if (hemoglobin < 11) {
      score += 10;
      matchedRules.add('Mildly low hemoglobin');
    }

    if (pregnancyWeek < 1 || pregnancyWeek > 42) {
      invalidInputs.add('pregnancy week');
      matchedRules.add('Pregnancy week missing or invalid; not scored');
    }

    if (weight == null || !weight.isFinite || weight <= 0) {
      invalidInputs.add('weight');
      matchedRules.add('Weight missing or invalid; not scored');
    }

    // Normalize case and internal whitespace, then classify each clinical
    // indicator once. Severe headache supersedes the ordinary headache score.
    final normalizedSymptoms = symptoms
        .map(
          (symptom) =>
              symptom.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' '),
        )
        .where((symptom) => symptom.isNotEmpty)
        .toSet();

    final hasBleeding = normalizedSymptoms.any((s) => s.contains('bleeding'));
    final hasSevereHeadache = normalizedSymptoms.any(
      (s) => s.contains('severe headache'),
    );
    final hasHeadache = normalizedSymptoms.any((s) => s.contains('headache'));
    final hasSwelling = normalizedSymptoms.any((s) => s.contains('swelling'));
    final hasFever = normalizedSymptoms.any((s) => s.contains('fever'));
    final hasBlurredVision = normalizedSymptoms.any(
      (s) => s.contains('blurred vision'),
    );
    final hasChestPain = normalizedSymptoms.any(
      (s) => s.contains('chest pain'),
    );
    final hasBreathingDifficulty = normalizedSymptoms.any(
      (s) =>
          s.contains('breathing difficulty') ||
          s.contains('difficulty breathing') ||
          s.contains('shortness of breath'),
    );
    final hasSevereAbdominalPain = normalizedSymptoms.any(
      (s) => s.contains('severe abdominal pain'),
    );

    if (hasBleeding) {
      score += 40;
      matchedRules.add('Bleeding reported');
    }
    if (hasSevereHeadache) {
      score += 30;
      matchedRules.add('Severe headache reported');
    } else if (hasHeadache) {
      score += 20;
      matchedRules.add('Headache reported');
    }
    if (hasSwelling) {
      score += 20;
      matchedRules.add('Swelling reported');
    }
    if (hasFever) {
      score += 15;
      matchedRules.add('Fever reported');
    }
    if (hasBlurredVision) {
      score += 30;
      matchedRules.add('Vision changes reported');
    }
    if (hasChestPain) {
      score += 40;
      matchedRules.add('Chest pain reported');
    }
    if (hasBreathingDifficulty) {
      score += 40;
      matchedRules.add('Breathing difficulty reported');
    }
    if (hasSevereAbdominalPain) {
      score += 35;
      matchedRules.add('Severe abdominal pain reported');
    }

    score = score.clamp(0, 100);

    final requiresUrgentAssessment =
        hasBleeding ||
        hasSevereHeadache ||
        hasBlurredVision ||
        hasChestPain ||
        hasBreathingDifficulty ||
        hasSevereAbdominalPain;

    final riskLevel = requiresUrgentAssessment
        ? RiskLevel.high
        : _getRiskLevel(score);

    if (requiresUrgentAssessment) {
      matchedRules.add('Emergency symptom requires urgent assessment');
    }
    if (!matchedRules.any(_isRiskFinding)) {
      matchedRules.add('No major risk indicators detected');
    }

    final explanation = _buildExplanation(riskLevel, score, matchedRules);

    return RiskResult(
      riskLevel: riskLevel,
      matchedRules: matchedRules,
      explanation: explanation,
      recommendation: requiresUrgentAssessment
          ? 'Seek urgent professional medical care now. Do not wait for this assessment.'
          : invalidInputs.isNotEmpty
          ? 'Assessment incomplete because ${invalidInputs.join(', ')} data are missing or invalid. Obtain valid measurements before interpreting this result.'
          : _recommendation(riskLevel),
      // Scoring, invalid-input handling, and emergency classification changed
      // from v1.1, so stored results need a distinct rule version.
      ruleVersion: 'v1.2',
      timestamp: DateTime.now(),
    );
  }

  bool _isRiskFinding(String rule) =>
      rule != 'Blood pressure missing or invalid; not scored' &&
      rule != 'Hemoglobin missing or invalid; not scored' &&
      rule != 'Pregnancy week missing or invalid; not scored' &&
      rule != 'Weight missing or invalid; not scored' &&
      rule != 'No major risk indicators detected';

  RiskLevel _getRiskLevel(int score) {
    if (score >= 45) return RiskLevel.high;
    if (score >= 20) return RiskLevel.moderate;
    return RiskLevel.low;
  }

  String _buildExplanation(
    RiskLevel riskLevel,
    int score,
    List<String> matchedRules,
  ) {
    return 'Risk assessment: ${riskLevel.name} '
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
