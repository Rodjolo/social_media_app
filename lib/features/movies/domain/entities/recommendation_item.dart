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
