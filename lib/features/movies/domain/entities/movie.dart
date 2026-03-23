class Movie {
  final String id;
  final String title;
  final List<String> genres;
  final String posterUrl;
  final String overview;
  final int year;
  final double popularity;

  const Movie({
    required this.id,
    required this.title,
    required this.genres,
    required this.posterUrl,
    required this.overview,
    required this.year,
    this.popularity = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'genres': genres,
      'posterUrl': posterUrl,
      'overview': overview,
      'year': year,
      'popularity': popularity,
    };
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown movie',
      genres: List<String>.from(json['genres'] ?? const []),
      posterUrl: json['posterUrl']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
    );
  }
}
