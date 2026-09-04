import 'rag_retriever.dart';

class RagContext {
  final String query;
  final List<RagResult> sources;

  const RagContext({
    required this.query,
    required this.sources,
  });

  bool get hasSources => sources.isNotEmpty;

  String get formattedContext {
    if (sources.isEmpty) {
      return 'No relevant maternal-health knowledge was found.';
    }

    final buffer = StringBuffer();

    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];

      buffer.writeln(
        'SOURCE ${i + 1}: ${source.topic}',
      );
      buffer.writeln(
        'Evidence: ${source.content}',
      );
      buffer.writeln(
        'Source: ${source.source}',
      );
      buffer.writeln();

    }

    return buffer.toString().trim();
  }
}

class RagService {
  final RagRetriever _retriever = RagRetriever();

  RagContext retrieveKnowledge(
    String query, {
    int limit = 3,
  }) {
    final results = _retriever.retrieve(
      query,
      limit: limit,
    );

    return RagContext(
      query: query,
      sources: results,
    );
  }
}