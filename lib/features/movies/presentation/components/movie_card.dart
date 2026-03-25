import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie.dart';
import 'package:socail_media_app/features/movies/domain/entities/movie_rating.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final MovieRating? userRating;
  final ValueChanged<double> onRatingSelected;
  final VoidCallback onLikePressed;

  const MovieCard({
    super.key,
    required this.movie,
    required this.userRating,
    required this.onRatingSelected,
    required this.onLikePressed,
  });

  @override
  Widget build(BuildContext context) {
    final currentRating = userRating?.rating ?? 0;
    final isLiked = userRating?.liked ?? false;
    final posterUrl = movie.posterUrl.trim();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 84,
                    height: 120,
                    child: !_hasUsablePosterUrl(posterUrl)
                        ? _PosterPlaceholder(title: movie.title)
                        : CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (_, __, ___) =>
                                _PosterPlaceholder(title: movie.title),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (movie.year > 0) ...[
                        const SizedBox(height: 4),
                        Text('Год: ${movie.year}'),
                      ],
                      if (movie.genres.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: movie.genres
                              .map(
                                (genre) => Chip(
                                  label: Text(genre),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (movie.overview.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                movie.overview,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ...List.generate(
                  5,
                  (index) => IconButton(
                    icon: Icon(
                      index < currentRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => onRatingSelected(index + 1.0),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onLikePressed,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : null,
                  ),
                  label: Text(isLiked ? 'В избранном' : 'В избранное'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

bool _hasUsablePosterUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

class _PosterPlaceholder extends StatelessWidget {
  final String title;

  const _PosterPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        title,
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
