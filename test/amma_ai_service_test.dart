import 'package:flutter_test/flutter_test.dart';
import 'package:amma/ai/amma_ai_service.dart';
import 'package:amma/ai/rag_retriever.dart';

void main() {
  group('AmmaAiService', () {
    final service = AmmaAiService();

    test('handles empty input', () {
      final result = service.ask('');

      expect(result.answer, 'Please enter a question.');
      expect(result.intent, AmmaIntent.unsupported);
      expect(result.isGrounded, isFalse);
      expect(result.sources, isEmpty);
    });

    test('routes heavy bleeding to emergency handling', () {
      final result = service.ask('I have heavy bleeding');

      expect(result.requiresUrgentCare, isTrue);
      expect(result.intent, AmmaIntent.emergency);
      expect(result.isGrounded, isFalse);
    });

    test('recognizes emergency phrases with punctuation', () {
      final result = service.ask('I have chest pain!');

      expect(result.intent, AmmaIntent.emergency);
      expect(result.requiresUrgentCare, isTrue);
    });

    test('recognizes breathing difficulty', () {
      final result = service.ask('I have difficulty breathing');

      expect(result.intent, AmmaIntent.emergency);
      expect(result.requiresUrgentCare, isTrue);
    });

    test('retrieves blood pressure information', () {
      final result = service.ask(
        'Tell me about blood pressure during pregnancy',
      );

      expect(result.intent, AmmaIntent.maternalHealthQuestion);
      expect(result.isGrounded, isTrue);
      expect(result.sources, isNotEmpty);
      expect(result.answer.toLowerCase(), contains('blood pressure'));
    });

    test('retrieves pregnancy danger-sign information', () {
      final result = service.ask('What are the danger signs during pregnancy?');

      expect(result.intent, AmmaIntent.maternalHealthQuestion);
      expect(result.sources, isNotEmpty);
    });

    test('does not answer unrelated questions from the knowledge base', () {
      final result = service.ask('How do I repair a car engine?');

      expect(result.intent, AmmaIntent.unsupported);
      expect(result.isGrounded, isFalse);
      expect(result.sources, isEmpty);
    });

    test('uses a correctly encoded source separator', () {
      final result = service.ask(
        'Tell me about blood pressure during pregnancy',
      );

      expect(result.sources, isNotEmpty);
      expect(result.sources.first, contains(' — '));
      expect(result.sources.first, isNot(contains('â€”')));
    });
  });

  group('RagRetriever', () {
    final retriever = RagRetriever();

    test('returns relevant knowledge for a supported query', () {
      final results = retriever.retrieve('blood pressure during pregnancy');

      expect(results, isNotEmpty);
      expect(
        results.any(
          (result) => result.topic.toLowerCase().contains('blood pressure'),
        ),
        isTrue,
      );
    });

    test('returns no results for an unrelated query', () {
      final results = retriever.retrieve('quantum spaceship engine repair');

      expect(results, isEmpty);
    });

    test('returns no results for an empty query', () {
      expect(retriever.retrieve(''), isEmpty);
    });

    test('returns no results when limit is zero', () {
      expect(retriever.retrieve('blood pressure', limit: 0), isEmpty);
    });

    test('respects the requested result limit', () {
      final results = retriever.retrieve(
        'pregnancy blood pressure symptoms health',
        limit: 1,
      );

      expect(results.length, lessThanOrEqualTo(1));
    });
  });
}
