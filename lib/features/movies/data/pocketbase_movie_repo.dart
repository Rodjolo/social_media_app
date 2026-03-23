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

      return result.items
          .map((record) => Movie.fromJson({
                'id': record.data['movieId']?.toString() ?? record.id,
                ...record.toJson(),
              }))
          .toList();
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
      final result =
          await pb.collection(BackendConfig.recommendationsCollection).getList(
                page: 1,
                perPage: limit,
                filter: 'uid = "$uid"',
                sort: '-score',
              );

      return result.items.map((record) {
        final data = {'id': record.id, ...record.toJson()};
        final movie = Movie(
          id: data['movieId']?.toString() ?? '',
          title: data['title']?.toString() ?? 'Unknown movie',
          genres: List<String>.from(data['genres'] ?? const []),
          posterUrl: data['posterUrl']?.toString() ?? '',
          overview: data['overview']?.toString() ?? '',
          year: (data['year'] as num?)?.toInt() ?? 0,
          popularity: (data['popularity'] as num?)?.toDouble() ?? 0,
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
}
