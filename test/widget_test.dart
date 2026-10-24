import 'package:flutter_test/flutter_test.dart';
import 'package:amma/ai/amma_ai_service.dart';

void main() {
  group('AMMA AI service smoke tests', () {
    late AmmaAiService service;

    setUp(() {
      service = AmmaAiService();
    });

    test('returns a prompt for empty input', () {
      final result = service.ask('');

      expect(result.answer, 'Please enter a question.');
      expect(result.isGrounded, isFalse);
    });

    test('detects an emergency phrase', () {
      final result = service.ask('I have heavy bleeding');

      expect(result.intent, AmmaIntent.emergency);
      expect(result.requiresUrgentCare, isTrue);
    });

    test('retrieves supported maternal-health information', () {
      final result = service.ask(
        'Tell me about blood pressure during pregnancy',
      );

      expect(result.intent, AmmaIntent.maternalHealthQuestion);
      expect(result.sources, isNotEmpty);
    });

    test('rejects an unrelated question', () {
      final result = service.ask('How do I repair a car engine?');

      expect(result.intent, AmmaIntent.unsupported);
      expect(result.isGrounded, isFalse);
    });
  });
}
