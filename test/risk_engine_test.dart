import 'package:flutter_test/flutter_test.dart';
import 'package:amma/core/constants/app_enums.dart';
import 'package:amma/models/risk_result.dart';
import 'package:amma/screens/ai/risk_engine.dart';

void main() {
  late RiskEngine engine;

  setUp(() => engine = RiskEngine());

  RiskResult assess({
    int week = 20,
    String? bp = '120/70',
    double? hemoglobin = 12,
    double? weight = 60,
    List<String> symptoms = const [],
  }) {
    return engine.assess(
      pregnancyWeek: week,
      bloodPressure: bp,
      hemoglobin: hemoglobin,
      weight: weight,
      symptoms: symptoms,
    );
  }

  String scoreText(RiskResult result) =>
      RegExp(r'\(score (\d+)/100\)').firstMatch(result.explanation)!.group(1)!;

  group('blood pressure validation and boundaries', () {
    test(
      'applies existing score boundaries at 130/80, 140/90, and 160/110',
      () {
        final below = assess(bp: '129/79');
        final target = assess(bp: '130/80');
        final elevated = assess(bp: '140/90');
        final severe = assess(bp: '160/110');

        expect(scoreText(below), '0');
        expect(scoreText(target), '15');
        expect(
          target.matchedRules,
          contains('Blood pressure above target range'),
        );
        expect(scoreText(elevated), '35');
        expect(elevated.matchedRules, contains('Elevated blood pressure'));
        expect(scoreText(severe), '50');
        expect(
          severe.matchedRules,
          contains('Severely elevated blood pressure'),
        );
      },
    );

    test('marks malformed, missing, and implausible pressure as unscored', () {
      for (final bp in <String?>[
        null,
        '',
        'unknown',
        '120',
        '120/80/70',
        '0/0',
        '80/120',
        '500/90',
      ]) {
        final result = assess(bp: bp);

        expect(result.riskLevel, RiskLevel.low, reason: 'input was $bp');
        expect(scoreText(result), '0', reason: 'input was $bp');
        expect(
          result.matchedRules,
          contains('Blood pressure missing or invalid; not scored'),
          reason: 'input was $bp',
        );
        expect(result.recommendation, contains('Assessment incomplete'));
      }
    });

    test('accepts surrounding whitespace around a valid reading', () {
      final result = assess(bp: ' 140 / 90 ');

      expect(scoreText(result), '35');
      expect(result.matchedRules, contains('Elevated blood pressure'));
    });
  });

  group('measurement validation', () {
    test(
      'does not turn missing or invalid haemoglobin into severe anaemia',
      () {
        for (final value in <double?>[
          null,
          0,
          -1,
          double.nan,
          double.infinity,
        ]) {
          final result = assess(hemoglobin: value);

          expect(result.riskLevel, RiskLevel.low);
          expect(scoreText(result), '0');
          expect(
            result.matchedRules,
            contains('Hemoglobin missing or invalid; not scored'),
          );
          expect(result.recommendation, contains('Assessment incomplete'));
          expect(
            result.matchedRules,
            isNot(contains('Severely low hemoglobin')),
          );
        }
      },
    );

    test('does not score missing or invalid weight as a clinical finding', () {
      for (final value in <double?>[null, 0, -1, double.nan, double.infinity]) {
        final result = assess(weight: value);

        expect(result.riskLevel, RiskLevel.low);
        expect(scoreText(result), '0');
        expect(
          result.matchedRules,
          contains('Weight missing or invalid; not scored'),
        );
        expect(result.recommendation, contains('Assessment incomplete'));
      }
    });

    test('reports invalid pregnancy weeks without adding risk points', () {
      for (final week in [0, -1, 43, 100]) {
        final result = assess(week: week);

        expect(result.riskLevel, RiskLevel.low);
        expect(scoreText(result), '0');
        expect(
          result.matchedRules,
          contains('Pregnancy week missing or invalid; not scored'),
        );
        expect(result.recommendation, contains('Assessment incomplete'));
      }
    });

    test('empty symptoms produce a no-indicator result', () {
      final result = assess(symptoms: const []);

      expect(result.riskLevel, RiskLevel.low);
      expect(
        result.matchedRules,
        contains('No major risk indicators detected'),
      );
    });
  });

  group('haemoglobin boundaries', () {
    test('preserves the existing score boundaries', () {
      expect(scoreText(assess(hemoglobin: 11)), '0');
      expect(scoreText(assess(hemoglobin: 10)), '10');
      expect(scoreText(assess(hemoglobin: 7)), '25');
      expect(scoreText(assess(hemoglobin: 6.99)), '40');
      expect(
        assess(hemoglobin: 10).matchedRules,
        contains('Mildly low hemoglobin'),
      );
      expect(assess(hemoglobin: 7).matchedRules, contains('Low hemoglobin'));
      expect(
        assess(hemoglobin: 6.99).matchedRules,
        contains('Severely low hemoglobin'),
      );
    });
  });

  group('symptoms and emergency handling', () {
    test(
      'classifies existing emergency indicators HIGH regardless of score',
      () {
        for (final symptom in [
          'Heavy bleeding',
          'Chest pain',
          'Severe breathing difficulty',
          'Difficulty breathing',
          'Shortness of breath',
          'Severe abdominal pain',
          'Severe headache',
          'Blurred vision',
        ]) {
          final result = assess(symptoms: [symptom]);

          expect(result.riskLevel, RiskLevel.high, reason: symptom);
          expect(
            result.matchedRules,
            contains('Emergency symptom requires urgent assessment'),
            reason: symptom,
          );
          expect(
            result.recommendation,
            contains('urgent professional medical care now'),
          );
        }
      },
    );

    test('scores duplicate and case/whitespace variants only once', () {
      final result = assess(
        symptoms: [' Headache ', 'HEADACHE', 'headache', 'Severe   Headache'],
      );

      expect(scoreText(result), '30');
      expect(
        result.matchedRules.where((r) => r == 'Severe headache reported'),
        hasLength(1),
      );
      expect(result.matchedRules, isNot(contains('Headache reported')));
    });

    test('preserves existing non-emergency UI symptom matching', () {
      final result = assess(symptoms: ['  SWELLING  ', 'Fever']);

      expect(scoreText(result), '35');
      expect(result.matchedRules, contains('Swelling reported'));
      expect(result.matchedRules, contains('Fever reported'));
      expect(result.riskLevel, RiskLevel.moderate);
    });
  });

  test('combines independent signals and caps the displayed score at 100', () {
    final combined = assess(bp: '140/90', hemoglobin: 9);
    expect(scoreText(combined), '60');
    expect(combined.riskLevel, RiskLevel.high);
    expect(combined.matchedRules, contains('Elevated blood pressure'));
    expect(combined.matchedRules, contains('Low hemoglobin'));
    expect(combined.explanation, contains('high'));

    final capped = assess(
      bp: '160/110',
      hemoglobin: 6,
      symptoms: ['bleeding', 'chest pain', 'fever'],
    );
    expect(scoreText(capped), '100');
  });

  test('repeated assessments are deterministic apart from their timestamp', () {
    final first = assess(
      bp: '145/95',
      hemoglobin: 9.5,
      symptoms: ['Swelling', 'fever'],
    );
    final second = assess(
      bp: '145/95',
      hemoglobin: 9.5,
      symptoms: ['Swelling', 'fever'],
    );

    expect(second.riskLevel, first.riskLevel);
    expect(second.matchedRules, first.matchedRules);
    expect(second.explanation, first.explanation);
    expect(second.recommendation, first.recommendation);
    expect(second.ruleVersion, first.ruleVersion);
  });

  test('uses a new explicit rule version for changed assessment behavior', () {
    expect(assess().ruleVersion, 'v1.2');
  });
}
