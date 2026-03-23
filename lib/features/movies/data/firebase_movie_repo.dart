import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie_rating.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_item.dart';
import 'package:socail_media_app/features/movies/domain/repos/movie_repo.dart';

class FirebaseMovieRepo implements MovieRepo {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get moviesCollection =>
      firestore.collection('movies');

  CollectionReference<Map<String, dynamic>> get ratingsCollection =>
      firestore.collection('ratings');

  @override
  Future<List<Movie>> fetchMovies({int limit = 30}) async {
    try {
      final snapshot = await moviesCollection
          .orderBy('popularity', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Movie.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } catch (_) {
      final fallbackSnapshot = await moviesCollection.limit(limit).get();
      return fallbackSnapshot.docs
          .map((doc) => Movie.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    }
  }

  @override
  Future<List<MovieRating>> fetchUserRatings(String uid) async {
    final snapshot = await ratingsCollection.where('uid', isEqualTo: uid).get();

    return snapshot.docs
        .map((doc) => MovieRating.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> saveMovieRating(MovieRating rating) async {
    await ratingsCollection
        .doc(rating.id)
        .set(rating.toJson(), SetOptions(merge: true));
  }

  @override
  Future<List<RecommendationItem>> fetchRecommendations(
    String uid, {
    int limit = 10,
  }) async {
    final recommendationsSnapshot = await firestore
        .collection('recommendations')
        .doc(uid)
        .collection('items')
        .orderBy('score', descending: true)
        .limit(limit)
        .get();

    final List<RecommendationItem> items = [];

    for (final doc in recommendationsSnapshot.docs) {
      final data = doc.data();
      final movie = await _resolveMovie(data);
      if (movie == null) {
        continue;
      }

      items.add(RecommendationItem.fromJson(json: data, movie: movie));
    }

    return items;
  }

  Future<Movie?> _resolveMovie(Map<String, dynamic> recommendationData) async {
    final embeddedTitle = recommendationData['title']?.toString();
    if (embeddedTitle != null && embeddedTitle.isNotEmpty) {
      return Movie(
        id: recommendationData['movieId']?.toString() ?? '',
        title: embeddedTitle,
        genres: List<String>.from(recommendationData['genres'] ?? const []),
        posterUrl: recommendationData['posterUrl']?.toString() ?? '',
        overview: recommendationData['overview']?.toString() ?? '',
        year: (recommendationData['year'] as num?)?.toInt() ?? 0,
        popularity: (recommendationData['popularity'] as num?)?.toDouble() ?? 0,
      );
    }

    final movieId = recommendationData['movieId']?.toString();
    if (movieId == null || movieId.isEmpty) {
      return null;
    }

    final movieDoc = await moviesCollection.doc(movieId).get();
    if (!movieDoc.exists || movieDoc.data() == null) {
      return null;
    }

    return Movie.fromJson({'id': movieDoc.id, ...movieDoc.data()!});
  }
}
