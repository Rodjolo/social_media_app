import 'package:pocketbase/pocketbase.dart';
import 'package:socail_media_app/config/backend_config.dart';
import 'package:socail_media_app/config/pocketbase_client.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie_rating.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_item.dart';
import 'package:socail_media_app/features/movies/domain/repos/movie_repo.dart';

class PocketBaseMovieRepo implements MovieRepo {
  @override
  Future<List<Movie>> fetchMovies({int limit = 30}) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      final result =
          await pb.collection(BackendConfig.moviesCollection).getList(
                page: 1,
                perPage: limit,
                sort: '-popularity',
              );

      final dedupedMovies = <String, Movie>{};
      for (final record in result.items) {
        final movie = Movie.fromJson({
          'id': record.data['movieId']?.toString() ?? record.id,
          ...record.toJson(),
          'posterUrl': _normalizePosterUrl(record.data['posterUrl']),
        });
        dedupedMovies[movie.id] = movie;
      }

      return dedupedMovies.values.toList();
    } on ClientException catch (e) {
      throw Exception(
          _formatPocketBaseError(e, fallback: 'Failed to fetch movies'));
    } catch (e) {
      throw Exception('Failed to fetch movies: $e');
    }
  }

  @override
  Future<List<MovieRating>> fetchUserRatings(String uid) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      final result =
          await pb.collection(BackendConfig.ratingsCollection).getFullList(
                filter: 'uid = "$uid"',
                sort: '-timestamp',
              );

      return result
          .map((record) =>
              MovieRating.fromJson({'id': record.id, ...record.toJson()}))
          .toList();
    } on ClientException catch (e) {
      throw Exception(
        _formatPocketBaseError(e, fallback: 'Failed to fetch ratings'),
      );
    } catch (e) {
      throw Exception('Failed to fetch ratings: $e');
    }
  }

  @override
  Future<void> saveMovieRating(MovieRating rating) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      final existing =
          await pb.collection(BackendConfig.ratingsCollection).getFirstListItem(
                'uid = "${rating.uid}" && movieId = "${rating.movieId}"',
              );

      await pb.collection(BackendConfig.ratingsCollection).update(
            existing.id,
            body: rating.toJson()..remove('id'),
          );
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        final pb = await PocketBaseClient.getInstance();
        await pb.collection(BackendConfig.ratingsCollection).create(
              body: rating.toJson()..remove('id'),
            );
        return;
      }

      throw Exception(
        _formatPocketBaseError(e, fallback: 'Failed to save movie rating'),
      );
    } catch (e) {
      throw Exception('Failed to save movie rating: $e');
    }
  }

  @override
  Future<List<RecommendationItem>> fetchRecommendations(
    String uid, {
    int limit = 10,
  }) async {
    try {
      final pb = await PocketBaseClient.getInstance();
      final moviesByMovieId = await _fetchMoviesByMovieId(pb, limit: 500);
      final result =
          await pb.collection(BackendConfig.recommendationsCollection).getList(
                page: 1,
                perPage: limit,
                filter: 'uid = "$uid"',
                sort: '-score',
              );

      return result.items.map((record) {
        final data = {'id': record.id, ...record.toJson()};
        final movieId = data['movieId']?.toString() ?? '';
        final fallbackMovie = moviesByMovieId[movieId];
        final movie = Movie(
          id: movieId,
          title: _pickString(
            primary: data['title'],
            fallback: fallbackMovie?.title,
            defaultValue: 'Unknown movie',
          ),
          genres: _pickGenres(
            primary: data['genres'],
            fallback: fallbackMovie?.genres,
          ),
          posterUrl: _pickPosterUrl(
            primary: data['posterUrl'],
            fallback: fallbackMovie?.posterUrl,
          ),
          overview: _pickString(
            primary: data['overview'],
            fallback: fallbackMovie?.overview,
          ),
          year: _pickInt(
            primary: data['year'],
            fallback: fallbackMovie?.year,
          ),
          popularity: _pickDouble(
            primary: data['popularity'],
            fallback: fallbackMovie?.popularity,
          ),
        );

        return RecommendationItem.fromJson(json: data, movie: movie);
      }).toList();
    } on ClientException catch (e) {
      throw Exception(
        _formatPocketBaseError(e, fallback: 'Failed to fetch recommendations'),
      );
    } catch (e) {
      throw Exception('Failed to fetch recommendations: $e');
    }
  }

  String _formatPocketBaseError(
    ClientException error, {
    required String fallback,
  }) {
    final response = error.response;
    final message = response['message']?.toString();
    final data = response['data'];

    if (data is Map && data.isNotEmpty) {
      return '$fallback: $message | $data';
    }

    return message?.isNotEmpty == true ? '$fallback: $message' : fallback;
  }

  Future<Map<String, Movie>> _fetchMoviesByMovieId(
    PocketBase pb, {
    int limit = 500,
  }) async {
    final result = await pb.collection(BackendConfig.moviesCollection).getList(
          page: 1,
          perPage: limit,
          sort: '-popularity',
        );

    final moviesByMovieId = <String, Movie>{};
    for (final record in result.items) {
      final movie = Movie.fromJson({
        'id': record.data['movieId']?.toString() ?? record.id,
        ...record.toJson(),
        'posterUrl': _normalizePosterUrl(record.data['posterUrl']),
      });
      moviesByMovieId[movie.id] = movie;
    }
    return moviesByMovieId;
  }

  String _normalizePosterUrl(dynamic rawValue) {
    final value = rawValue?.toString().trim() ?? '';
    if (value.isEmpty) {
      return '';
    }

    return value
        .replaceFirst('http://127.0.0.1:8090', BackendConfig.pocketBaseUrl)
        .replaceFirst('http://localhost:8090', BackendConfig.pocketBaseUrl);
  }

  String _pickString({
    required dynamic primary,
    required String? fallback,
    String defaultValue = '',
  }) {
    final primaryValue = primary?.toString().trim() ?? '';
    if (primaryValue.isNotEmpty) {
      return primaryValue;
    }
    final fallbackValue = fallback?.trim() ?? '';
    if (fallbackValue.isNotEmpty) {
      return fallbackValue;
    }
    return defaultValue;
  }

  List<String> _pickGenres({
    required dynamic primary,
    required List<String>? fallback,
  }) {
    if (primary is List && primary.isNotEmpty) {
      return primary.map((item) => item.toString()).toList();
    }
    return fallback ?? const [];
  }

  String _pickPosterUrl({
    required dynamic primary,
    required String? fallback,
  }) {
    final normalizedPrimary = _normalizePosterUrl(primary);
    if (normalizedPrimary.isNotEmpty) {
      return normalizedPrimary;
    }
    return fallback ?? '';
  }

  int _pickInt({
    required dynamic primary,
    required int? fallback,
  }) {
    final primaryValue = (primary as num?)?.toInt() ?? 0;
    if (primaryValue > 0) {
      return primaryValue;
    }
    return fallback ?? 0;
  }

  double _pickDouble({
    required dynamic primary,
    required double? fallback,
  }) {
    final primaryValue = (primary as num?)?.toDouble() ?? 0;
    if (primaryValue > 0) {
      return primaryValue;
    }
    return fallback ?? 0;
  }
}
