import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie_rating.dart';
import 'package:socail_media_app/features/movies/domain/repos/movie_repo.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_states.dart';

class MovieCubit extends Cubit<MovieState> {
  final MovieRepo movieRepo;

  MovieCubit({required this.movieRepo}) : super(MovieInitial());

  Future<void> loadMoviesScreen(String uid) async {
    try {
      emit(MovieLoading());

      final movies = await movieRepo.fetchMovies();
      final ratings = await movieRepo.fetchUserRatings(uid);

      emit(
        MovieLoaded(
          movies: movies,
          ratingsByMovieId: {
            for (final rating in ratings) rating.movieId: rating,
          },
          recommendations: const [],
        ),
      );
    } catch (e) {
      emit(MovieError('Failed to load movies: $e'));
    }
  }

  Future<void> loadRecommendationsScreen(String uid) async {
    final currentState = state;
    try {
      if (currentState is! MovieLoaded) {
        emit(MovieLoading());
      }

      final movies = currentState is MovieLoaded
          ? currentState.movies
          : await movieRepo.fetchMovies(limit: 15);
      final ratings = currentState is MovieLoaded
          ? currentState.ratingsByMovieId
          : {
              for (final rating in await movieRepo.fetchUserRatings(uid))
                rating.movieId: rating,
            };
      final recommendations = await movieRepo.fetchRecommendations(uid);

      emit(
        MovieLoaded(
          movies: movies,
          ratingsByMovieId: ratings,
          recommendations: recommendations,
        ),
      );
    } catch (e) {
      emit(MovieError('Failed to load recommendations: $e'));
    }
  }

  Future<void> saveMovieFeedback({
    required String uid,
    required Movie movie,
    double? rating,
    bool? liked,
  }) async {
    final existing = state is MovieLoaded
        ? (state as MovieLoaded).ratingsByMovieId[movie.id]
        : null;

    final updatedRating = MovieRating(
      id: '${uid}_${movie.id}',
      uid: uid,
      movieId: movie.id,
      rating: rating ?? existing?.rating ?? 0,
      liked: liked ?? existing?.liked ?? false,
      timestamp: DateTime.now(),
    );

    try {
      await movieRepo.saveMovieRating(updatedRating);

      final currentState = state;
      if (currentState is MovieLoaded) {
        final updatedRatings =
            Map<String, MovieRating>.from(currentState.ratingsByMovieId);
        updatedRatings[movie.id] = updatedRating;
        emit(currentState.copyWith(ratingsByMovieId: updatedRatings));
      } else {
        await loadMoviesScreen(uid);
      }
    } catch (e) {
      emit(MovieError('Failed to save movie feedback: $e'));
    }
  }
}
