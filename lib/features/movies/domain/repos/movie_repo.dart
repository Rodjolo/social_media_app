import 'package:socail_media_app/features/movies/domain/entities/movie.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie_rating.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_item.dart';

abstract class MovieRepo {
  Future<List<Movie>> fetchMovies({int limit = 30});
  Future<List<MovieRating>> fetchUserRatings(String uid);
  Future<void> saveMovieRating(MovieRating rating);
  Future<List<RecommendationItem>> fetchRecommendations(
    String uid, {
    int limit = 10,
  });
}
