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
  List<RagResult> retrieve(
    String query, {
    int limit = 3,
  }) {
    final normalizedQuery = query.toLowerCase().trim();

    if (normalizedQuery.isEmpty) {
      return [];
    }

    final queryWords = normalizedQuery
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty)
        .toSet();

    final results = <RagResult>[];

    for (final entry in MaternalKnowledge.entries) {
      final keywords =
          (entry['keywords'] as List<dynamic>)
              .map((keyword) => keyword.toString().toLowerCase())
              .toList();

      var score = 0;

      for (final keyword in keywords) {
        if (normalizedQuery.contains(keyword)) {
          score += 3;
        }

        if (queryWords.contains(keyword)) {
          score += 2;
        }
      }

      final topic =
          entry['topic'].toString().toLowerCase();

      final content =
          entry['content'].toString().toLowerCase();

      for (final word in queryWords) {
        if (topic.contains(word)) {
          score += 2;
        }

        if (content.contains(word)) {
          score += 1;
        }
      }

      if (score > 0) {
        results.add(
          RagResult(
            id: entry['id'].toString(),
            topic: entry['topic'].toString(),
            content: entry['content'].toString(),
            source: entry['source'].toString(),
            score: score,
          ),
        );
      }
    }

    results.sort(
      (a, b) => b.score.compareTo(a.score),
    );

    return results.take(limit).toList();
  }
}