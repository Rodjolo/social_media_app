import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/movies/data/recommendation_service_client.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie_rating.dart';
import 'package:socail_media_app/features/movies/domain/repos/movie_repo.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_states.dart';

class MovieCubit extends Cubit<MovieState> {
  final MovieRepo movieRepo;
  final RecommendationServiceClient recommendationServiceClient;
  final int minimumRatingsForAutoRebuild;

  Timer? _autoRebuildDebounce;

  MovieCubit({
    required this.movieRepo,
    RecommendationServiceClient? recommendationServiceClient,
    this.minimumRatingsForAutoRebuild = 5,
  })  : recommendationServiceClient =
            recommendationServiceClient ?? RecommendationServiceClient(),
        super(MovieInitial());

  @override
  Future<void> close() {
    _autoRebuildDebounce?.cancel();
    recommendationServiceClient.dispose();
    return super.close();
  }

  Future<void> loadMoviesScreen(String uid) async {
    final currentState = state;
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
          recommendations:
              currentState is MovieLoaded ? currentState.recommendations : const [],
          autoRebuildMessage: currentState is MovieLoaded
              ? currentState.autoRebuildMessage ?? _buildProfileHint(ratings.length)
              : _buildProfileHint(ratings.length),
          isAutoRebuilding:
              currentState is MovieLoaded && currentState.isAutoRebuilding,
          rebuildStatus:
              currentState is MovieLoaded ? currentState.rebuildStatus : null,
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
          autoRebuildMessage:
              currentState is MovieLoaded ? currentState.autoRebuildMessage : null,
          rebuildStatus:
              currentState is MovieLoaded ? currentState.rebuildStatus : null,
          isAutoRebuilding:
              currentState is MovieLoaded && currentState.isAutoRebuilding,
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
        final shouldAutoRebuild = rating != null &&
            (existing == null || existing.rating != updatedRating.rating);

        emit(
          currentState.copyWith(
            ratingsByMovieId: updatedRatings,
            autoRebuildMessage: _buildProfileHint(updatedRatings.length),
          ),
        );
        if (shouldAutoRebuild) {
          _scheduleAutoRebuild(uid);
        }
      } else {
        await loadMoviesScreen(uid);
      }
    } catch (e) {
      emit(MovieError('Failed to save movie feedback: $e'));
    }
  }

  void _scheduleAutoRebuild(String uid) {
    final currentState = state;
    if (currentState is! MovieLoaded) {
      return;
    }

    _autoRebuildDebounce?.cancel();

    if (currentState.ratingsByMovieId.length < minimumRatingsForAutoRebuild) {
      emit(
        currentState.copyWith(
          isAutoRebuilding: false,
          autoRebuildMessage: _buildProfileHint(currentState.ratingsByMovieId.length),
        ),
      );
      return;
    }

    emit(
      currentState.copyWith(
        isAutoRebuilding: true,
        autoRebuildMessage:
            'Новая оценка сохранена. Запускаем автоматический пересчет рекомендаций...',
      ),
    );

    _autoRebuildDebounce = Timer(
      const Duration(seconds: 2),
      () => _runAutoRebuild(uid),
    );
  }

  Future<void> _runAutoRebuild(String uid) async {
    final currentState = state;
    if (currentState is! MovieLoaded) {
      return;
    }

    try {
      final healthy = await recommendationServiceClient.isHealthy();
      if (!healthy) {
        emit(
          currentState.copyWith(
            isAutoRebuilding: false,
            autoRebuildMessage:
                'Локальный сервис пересчета недоступен. Оценка сохранена, рекомендации можно пересчитать позже.',
          ),
        );
        return;
      }

      await recommendationServiceClient.triggerRebuild(userId: uid);
      emit(
        currentState.copyWith(
          isAutoRebuilding: true,
          autoRebuildMessage:
              'Пересчет рекомендаций запущен автоматически. Ждем обновленный результат...',
        ),
      );

      await _waitForRebuildCompletion(uid);
    } catch (e) {
      if (state is! MovieLoaded) {
        return;
      }
      final latestState = state as MovieLoaded;
      emit(
        latestState.copyWith(
          isAutoRebuilding: false,
          autoRebuildMessage:
              'Автопересчет не удалось запустить: $e',
        ),
      );
    }
  }

  Future<void> _waitForRebuildCompletion(String uid) async {
    for (var attempt = 0; attempt < 45; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));

      final rebuildStatus = await recommendationServiceClient.fetchStatus(uid);
      final currentState = state;
      if (currentState is! MovieLoaded || rebuildStatus == null) {
        continue;
      }

      if (rebuildStatus.state == 'running') {
        emit(
          currentState.copyWith(
            isAutoRebuilding: true,
            rebuildStatus: rebuildStatus,
            autoRebuildMessage:
                'Сервис пересчитывает рекомендации. Последняя оценка уже учитывается.',
          ),
        );
        continue;
      }

      if (rebuildStatus.state == 'completed') {
        final recommendations = await movieRepo.fetchRecommendations(uid);
        final latestState = state;
        if (latestState is! MovieLoaded) {
          return;
        }

        emit(
          latestState.copyWith(
            recommendations: recommendations,
            isAutoRebuilding: false,
            rebuildStatus: rebuildStatus,
            autoRebuildMessage:
                'Рекомендации автоматически обновлены после новой оценки.',
          ),
        );
        return;
      }

      if (rebuildStatus.state == 'failed') {
        emit(
          currentState.copyWith(
            isAutoRebuilding: false,
            rebuildStatus: rebuildStatus,
            autoRebuildMessage:
                'Автопересчет завершился с ошибкой. Оценки сохранены, но рекомендации не обновились.',
          ),
        );
        return;
      }
    }

    final currentState = state;
    if (currentState is! MovieLoaded) {
      return;
    }

    emit(
      currentState.copyWith(
        isAutoRebuilding: false,
        autoRebuildMessage:
            'Автопересчет занял слишком много времени. Проверьте сервис пересчета и попробуйте еще раз.',
      ),
    );
  }

  String _buildProfileHint(int ratingCount) {
    if (ratingCount < minimumRatingsForAutoRebuild) {
      final remaining = minimumRatingsForAutoRebuild - ratingCount;
      return 'Оцените еще $remaining фильм(ов), и система сможет автоматически пересчитать рекомендации.';
    }

    return 'Профиль предпочтений уже достаточно заполнен для автоматического пересчета.';
  }
}
