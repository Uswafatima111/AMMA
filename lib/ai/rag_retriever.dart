import 'knowledge/maternal_knowledge.dart';

class RagResult {
  final String id;
  final String topic;
  final String content;
  final String source;
  final int score;
  final String category;
  final String? sourceUrl;
  final String reviewStatus;
  final String? lastReviewed;

  const RagResult({
    required this.id,
    required this.topic,
    required this.content,
    required this.source,
    required this.score,
    this.category = 'maternal_health',
    this.sourceUrl,
    this.reviewStatus = 'review_status_unspecified',
    this.lastReviewed,
  });
}

class RagRetriever {
  static const Set<String> _specificSingleWordKeywords = {
    'anemia',
    'hemoglobin',
    'hb',
    'bp',
    'antenatal',
    'anc',
    'pmsma',
    'jssk',
    'uip',
    'vaccine',
    'immunization',
    'benefit',
    'scheme',
    'asha',
    'bleeding',
    'headache',
    'fever',
    'swelling',
    'seizure',
    'hypertension',
    'nutrition',
    'checkup',
    'emergency',
    'sos',
  };

  static const Set<String> _stopWords = {
    'a',
    'an',
    'the',
    'is',
    'are',
    'was',
    'were',
    'am',
    'i',
    'me',
    'my',
    'we',
    'our',
    'you',
    'your',
    'he',
    'she',
    'it',
    'they',
    'to',
    'of',
    'in',
    'on',
    'at',
    'for',
    'and',
    'or',
    'but',
    'do',
    'does',
    'did',
    'how',
    'what',
    'when',
    'where',
    'why',
    'who',
    'can',
    'could',
    'would',
    'should',
    'tell',
    'about',
    'please',
    'during',
    'with',
    'isnt',
    'dont',
    'doesnt',
    'from',
    'this',
    'that',
    'there',
    'their',
  };

  String _normalize(String text) {
    var normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    // Canonicalize common spelling, punctuation, and inflection variants.
    normalized = normalized
        .replaceAll(RegExp(r'\bhaemoglobin\b'), 'hemoglobin')
        .replaceAll(RegExp(r'\banaemia\b'), 'anemia')
        .replaceAll(RegExp(r'\bcheck\s+ups?\b'), 'checkup')
        .replaceAll(RegExp(r'\bappointments\b'), 'appointment')
        .replaceAll(RegExp(r'\bbenefits\b'), 'benefit')
        .replaceAll(RegExp(r'\bschemes\b'), 'scheme')
        .replaceAll(RegExp(r'\bvaccines\b'), 'vaccine')
        .replaceAll(RegExp(r'\bimmunisation\b'), 'immunization')
        .replaceAll(RegExp(r'\breports\b'), 'report')
        .replaceAll(RegExp(r'\bbabies\b'), 'baby');

    return normalized;
  }

  Set<String> _words(String text) {
    return _normalize(text)
        .split(' ')
        .where((word) => word.isNotEmpty && !_stopWords.contains(word))
        .toSet();
  }

  List<RagResult> retrieve(String query, {int limit = 3}) {
    if (limit <= 0) return [];

    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return [];

    final queryWords = _words(query);
    if (queryWords.isEmpty) return [];

    final paddedQuery = ' $normalizedQuery ';
    final results = <RagResult>[];

    for (final entry in MaternalKnowledge.entries) {
      final topic = entry['topic'].toString();
      final content = entry['content'].toString();
      final source = entry['source'].toString();
      final id = entry['id'].toString();
      final category = entry['category']?.toString() ?? 'maternal_health';
      final sourceUrl = entry['sourceUrl']?.toString();
      final reviewStatus =
          entry['reviewStatus']?.toString() ?? 'review_status_unspecified';
      final lastReviewed = entry['lastReviewed']?.toString();

      final keywords = (entry['keywords'] as List<dynamic>)
          .map((keyword) => _normalize(keyword.toString()))
          .where((keyword) => keyword.isNotEmpty)
          .toSet();

      final topicWords = _words(topic);
      final contentWords = _words(content);
      final keywordWords = keywords.expand(_words).toSet();

      var score = 0;
      var hasKeywordPhraseMatch = false;
      var hasSpecificSingleKeywordMatch = false;

      // Exact phrase/word matches against the normalized query.
      for (final keyword in keywords) {
        if (paddedQuery.contains(' $keyword ')) {
          score += 4;
          if (keyword.contains(' ')) {
            hasKeywordPhraseMatch = true;
          } else if (_specificSingleWordKeywords.contains(keyword)) {
            hasSpecificSingleKeywordMatch = true;
          }
        }
      }

      // Score distinct query words, not repeated occurrences.
      var matchedKeywordWordCount = 0;
      for (final word in queryWords) {
        if (topicWords.contains(word)) {
          score += 3;
        } else if (contentWords.contains(word)) {
          score += 1;
        }

        // A matching keyword word is useful, but does not
        // receive another full phrase-match score.
        if (keywordWords.contains(word)) {
          score += 1;
          matchedKeywordWordCount++;
        }
      }

      // One generic word such as "pregnancy" or "health" cannot make an
      // unrelated multiword question look relevant. Require a full keyword
      // phrase, two distinct keyword terms, or one exact specific keyword.
      final isRelevant =
          hasKeywordPhraseMatch ||
          hasSpecificSingleKeywordMatch ||
          matchedKeywordWordCount >= 2;
      if (score >= 3 && isRelevant) {
        results.add(
          RagResult(
            id: id,
            topic: topic,
            content: content,
            source: source,
            score: score,
            category: category,
            sourceUrl: sourceUrl,
            reviewStatus: reviewStatus,
            lastReviewed: lastReviewed,
          ),
        );
      }
    }

    // Stable tie-breaking makes results predictable in tests.
    results.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) return scoreComparison;
      return a.id.compareTo(b.id);
    });

    return results.take(limit).toList();
  }
}
