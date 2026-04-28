import 'package:socail_media_app/features/movies/domain/entities/movie.dart';

class RecommendationItem {
  final String movieId;
  final double score;
  final String reason;
  final DateTime generatedAt;
  final Movie movie;

  const RecommendationItem({
    required this.movieId,
    required this.score,
    required this.reason,
    required this.generatedAt,
    required this.movie,
  });

  factory RecommendationItem.fromJson({
    required Map<String, dynamic> json,
    required Movie movie,
  }) {
    final generatedAtRaw = json['generatedAt'];

    return RecommendationItem(
      movieId: json['movieId']?.toString() ?? movie.id,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      reason: json['reason']?.toString() ?? '',
      generatedAt:
          DateTime.tryParse(generatedAtRaw?.toString() ?? '') ?? DateTime.now(),
      movie: movie,
    );
  }
}

double averageRecommendationScore(List<RecommendationItem> items) {
  if (items.isEmpty) {
    return 0;
  }

  final total = items.fold<double>(0, (sum, item) => sum + item.score);
  return total / items.length;
}

List<String> topRecommendationGenres(
  List<RecommendationItem> items, {
  int limit = 3,
}) {
  final counts = <String, int>{};

  for (final item in items) {
    for (final genre in item.movie.genres) {
      final normalized = genre.trim();
      if (normalized.isEmpty) {
        continue;
      }
      counts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
    }
  }

  final sorted = counts.entries.toList()
    ..sort((a, b) {
      final countCompare = b.value.compareTo(a.value);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.key.compareTo(b.key);
    });

  return sorted.take(limit).map((entry) => entry.key).toList();
}
