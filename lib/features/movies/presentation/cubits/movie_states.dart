import 'package:socail_media_app/features/movies/domain/entities/movie.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie_rating.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_item.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_rebuild_status.dart';

abstract class MovieState {}

class MovieInitial extends MovieState {}

class MovieLoading extends MovieState {}

class MovieLoaded extends MovieState {
  final List<Movie> movies;
  final Map<String, MovieRating> ratingsByMovieId;
  final List<RecommendationItem> recommendations;
  final bool isAutoRebuilding;
  final String? autoRebuildMessage;
  final RecommendationRebuildStatus? rebuildStatus;

  MovieLoaded({
    required this.movies,
    required this.ratingsByMovieId,
    required this.recommendations,
    this.isAutoRebuilding = false,
    this.autoRebuildMessage,
    this.rebuildStatus,
  });

  MovieLoaded copyWith({
    List<Movie>? movies,
    Map<String, MovieRating>? ratingsByMovieId,
    List<RecommendationItem>? recommendations,
    bool? isAutoRebuilding,
    String? autoRebuildMessage,
    bool clearAutoRebuildMessage = false,
    RecommendationRebuildStatus? rebuildStatus,
    bool clearRebuildStatus = false,
  }) {
    return MovieLoaded(
      movies: movies ?? this.movies,
      ratingsByMovieId: ratingsByMovieId ?? this.ratingsByMovieId,
      recommendations: recommendations ?? this.recommendations,
      isAutoRebuilding: isAutoRebuilding ?? this.isAutoRebuilding,
      autoRebuildMessage: clearAutoRebuildMessage
          ? null
          : autoRebuildMessage ?? this.autoRebuildMessage,
      rebuildStatus:
          clearRebuildStatus ? null : rebuildStatus ?? this.rebuildStatus,
    );
  }
}

class MovieError extends MovieState {
  final String message;

  MovieError(this.message);
}
