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

    // Emergency routing takes priority over all other intent checks.
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

    if (_containsKannada(question)) {
      return _unsupported(
        'Verified Kannada answers are not available in the current AMMA '
        'knowledge base. Please ask your ASHA or a qualified healthcare '
        'professional. For an emergency, contact local emergency services.',
      );
    }

    if (_mentionsUwin(normalized)) {
      return _unsupported(
        'The current AMMA knowledge base does not have a verified source for '
        'U-WIN registration or records. Please confirm with your ASHA or '
        'vaccination provider.',
      );
    }

    if (_isPersonalHealthQuestion(normalized)) {
      return _unsupported(
        'AMMA cannot access or interpret your personal health records, test '
        'results, readings, or symptoms. Please discuss them with your ASHA '
        'or a qualified healthcare professional.',
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

    final sources = context.sources.map((source) {
      final review = source.reviewStatus.replaceAll('_', ' ');
      final url = source.sourceUrl == null ? '' : ' | ${source.sourceUrl}';
      return '${source.topic} | ${source.source} [$review]$url';
    }).toList();

    final answer = context.sources
        .map((source) => '${source.topic}\n${source.content}')
        .join('\n\n');

    return AmmaAiResponse(
      answer:
          '$answer\n\nThis information is for support only, '
          'not a diagnosis. The source material has not completed AMMA '
          'clinical review. Discuss individual concerns with a qualified '
          'healthcare professional.',
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

    final normalized =
        ' ${query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim()} ';
    return emergencyPhrases.any((phrase) {
      final normalizedPhrase =
          phrase.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
      return normalized.contains(' $normalizedPhrase ');
    });
  }

  bool _containsKannada(String query) =>
      RegExp(r'[\u0C80-\u0CFF]').hasMatch(query);

  bool _mentionsUwin(String query) {
    final normalized = query.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return RegExp(r'\bu\s*win\b|\buwin\b').hasMatch(normalized);
  }

  bool _isPersonalHealthQuestion(String query) {
    final normalized = query
        .replaceAll(RegExp(r'[^a-z0-9/]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final refersToOwnData = RegExp(r'\b(my|mine)\b').hasMatch(normalized);
    final firstPersonHealthStatement = RegExp(
      r'\bi have\b|\bi am\b|\bi\s+m\b|\bi feel\b',
    ).hasMatch(normalized);
    if (!refersToOwnData && !firstPersonHealthStatement) return false;

    const recordTerms = [
      'blood pressure',
      'hemoglobin',
      'haemoglobin',
      'anemia',
      'anaemia',
      'weight',
      'test result',
      'test results',
      'test report',
      'scan report',
      'report',
      'result',
      'reading',
      'symptom',
      'headache',
      'swelling',
      'fever',
      'bleeding',
      'breathing difficulty',
      'shortness of breath',
      'weeks pregnant',
      'vaccine card',
      'vaccination record',
    ];
    final hasPersonalRecordTerm =
        recordTerms.any(normalized.contains) ||
        RegExp(r'\bbp\b|\bhb\b').hasMatch(normalized);
    final hasReading =
        RegExp(r'\b\d{2,3}\s*/\s*\d{2,3}\b').hasMatch(normalized) ||
        RegExp(r'\b\d+(\.\d+)?\s*(g/dl|kg)\b').hasMatch(normalized);

    if (refersToOwnData && (hasPersonalRecordTerm || hasReading)) return true;
    if (firstPersonHealthStatement &&
        (hasReading || hasPersonalRecordTerm)) {
      return true;
    }

    const symptomTerms = [
      'headache',
      'swelling',
      'fever',
      'bleeding',
      'breathing difficulty',
      'shortness of breath',
      'pain',
      'dizziness',
    ];
    return firstPersonHealthStatement &&
        symptomTerms.any(normalized.contains);
  }

  AmmaAiResponse _unsupported(String answer) => AmmaAiResponse(
    answer: answer,
    intent: AmmaIntent.unsupported,
    requiresUrgentCare: false,
    isGrounded: false,
    sources: const [],
  );
}
