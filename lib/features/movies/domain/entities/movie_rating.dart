import 'package:cloud_firestore/cloud_firestore.dart';

class MovieRating {
  final String id;
  final String uid;
  final String movieId;
  final double rating;
  final bool liked;
  final DateTime timestamp;

  const MovieRating({
    required this.id,
    required this.uid,
    required this.movieId,
    required this.rating,
    required this.liked,
    required this.timestamp,
  });

  MovieRating copyWith({
    double? rating,
    bool? liked,
    DateTime? timestamp,
  }) {
    return MovieRating(
      id: id,
      uid: uid,
      movieId: movieId,
      rating: rating ?? this.rating,
      liked: liked ?? this.liked,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'movieId': movieId,
      'rating': rating,
      'liked': liked,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory MovieRating.fromJson(Map<String, dynamic> json) {
    return MovieRating(
      id: json['id']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
      movieId: json['movieId']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      liked: json['liked'] == true,
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
