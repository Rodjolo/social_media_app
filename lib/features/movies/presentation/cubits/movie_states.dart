import 'package:socail_media_app/features/movies/domain/entities/movie.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie_rating.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_item.dart';

abstract class MovieState {}

class MovieInitial extends MovieState {}

class MovieLoading extends MovieState {}

class MovieLoaded extends MovieState {
  final List<Movie> movies;
  final Map<String, MovieRating> ratingsByMovieId;
  final List<RecommendationItem> recommendations;

  MovieLoaded({
    required this.movies,
    required this.ratingsByMovieId,
    required this.recommendations,
  });

  MovieLoaded copyWith({
    List<Movie>? movies,
    Map<String, MovieRating>? ratingsByMovieId,
    List<RecommendationItem>? recommendations,
  }) {
    return MovieLoaded(
      movies: movies ?? this.movies,
      ratingsByMovieId: ratingsByMovieId ?? this.ratingsByMovieId,
      recommendations: recommendations ?? this.recommendations,
    );
  }
}

class MovieError extends MovieState {
  final String message;

  MovieError(this.message);
}
