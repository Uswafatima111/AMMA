import 'rag_service.dart';

enum AmmaIntent { emergency, maternalHealthQuestion, unsupported }

class AmmaAiResponse {
  final String answer;
  final AmmaIntent intent;
  final bool requiresUrgentCare;
  final bool isGrounded;
  final List<String> sources;

  const AmmaAiResponse({
    required this.answer,
    required this.intent,
    required this.requiresUrgentCare,
    required this.isGrounded,
    required this.sources,
  });
}

class AmmaAiService {
  final RagService _ragService;

  AmmaAiService({RagService? ragService})
    : _ragService = ragService ?? RagService();

  AmmaAiResponse ask(String question) {
    final normalized = question.toLowerCase().trim();

    if (normalized.isEmpty) {
      return const AmmaAiResponse(
        answer: 'Please enter a question.',
        intent: AmmaIntent.unsupported,
        requiresUrgentCare: false,
        isGrounded: false,
        sources: [],
      );
    }

    // Route emergency-related questions before ordinary retrieval.
    if (_containsEmergencyIntent(normalized)) {
      return const AmmaAiResponse(
        answer:
            'If this is happening now, seek urgent professional '
            'medical help. Do not wait for an AI response. '
            'Use the AMMA emergency workflow or contact local '
            'emergency services as appropriate.',
        intent: AmmaIntent.emergency,
        requiresUrgentCare: true,
        isGrounded: false,
        sources: [],
      );
    }

    final context = _ragService.retrieveKnowledge(question);

    if (!context.hasSources) {
      return const AmmaAiResponse(
        answer:
            'I could not find relevant information in the current '
            'AMMA knowledge base. Please ask a qualified healthcare '
            'professional for advice about your situation.',
        intent: AmmaIntent.unsupported,
        requiresUrgentCare: false,
        isGrounded: false,
        sources: [],
      );
    }

    final sources = context.sources
        .map((source) => '${source.topic} — ${source.source}')
        .toList();

    final answer = context.sources
        .map((source) => '${source.topic}\n${source.content}')
        .join('\n\n');

    return AmmaAiResponse(
      answer:
          '$answer\n\nThis information is for support only, '
          'not a diagnosis. Discuss individual concerns with '
          'a qualified healthcare professional.',
      intent: AmmaIntent.maternalHealthQuestion,
      requiresUrgentCare: false,
      isGrounded: true,
      sources: sources,
    );
  }

  bool _containsEmergencyIntent(String query) {
    const emergencyPhrases = [
      'emergency',
      'sos',
      'ambulance',
      'heavy bleeding',
      'vaginal bleeding',
      'severe headache',
      'blurred vision',
      'chest pain',
      'difficulty breathing',
      'breathing difficulty',
      'shortness of breath',
      'severe abdominal pain',
    ];

    return emergencyPhrases.any(query.contains);
  }
}
