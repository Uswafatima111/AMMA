
import 'knowledge/maternal_knowledge.dart';

class RagResult {
  final String id;
  final String topic;
  final String content;
  final String source;
  final int score;

  const RagResult({
    required this.id,
    required this.topic,
    required this.content,
    required this.source,
    required this.score,
  });
}

class RagRetriever {
  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'am',
    'i', 'me', 'my', 'we', 'our', 'you', 'your', 'he',
    'she', 'it', 'they', 'to', 'of', 'in', 'on', 'at',
    'for', 'and', 'or', 'but', 'do', 'does', 'did',
    'how', 'what', 'when', 'where', 'why', 'who',
    'can', 'could', 'would', 'should', 'tell', 'about',
    'please', 'during', 'with', 'isnt', 'dont', 'doesnt',
  };

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
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

      final keywords = (entry['keywords'] as List<dynamic>)
          .map((keyword) => _normalize(keyword.toString()))
          .where((keyword) => keyword.isNotEmpty)
          .toSet();

      final topicWords = _words(topic);
      final contentWords = _words(content);

      var score = 0;

      // Exact phrase/word matches against the normalized query.
      for (final keyword in keywords) {
        if (paddedQuery.contains(' $keyword ')) {
          score += 4;
        }
      }

      // Score distinct query words, not repeated occurrences.
      for (final word in queryWords) {
        if (topicWords.contains(word)) {
          score += 3;
        } else if (contentWords.contains(word)) {
          score += 1;
        }

        // A matching keyword word is useful, but does not
        // receive another full phrase-match score.
        if (keywords.any((keyword) => _words(keyword).contains(word))) {
          score += 1;
        }
      }

      // Reject weak matches instead of returning unrelated content.
      if (score >= 3) {
        results.add(
          RagResult(
            id: id,
            topic: topic,
            content: content,
            source: source,
            score: score,
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
