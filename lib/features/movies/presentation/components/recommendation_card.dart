import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_item.dart';

class RecommendationCard extends StatelessWidget {
  final RecommendationItem item;

  const RecommendationCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 84,
                height: 120,
                child: item.movie.posterUrl.isEmpty
                    ? _FallbackPoster(title: item.movie.title)
                    : CachedNetworkImage(
                        imageUrl: item.movie.posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (_, __, ___) =>
                            _FallbackPoster(title: item.movie.title),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.movie.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text('Score: ${item.score.toStringAsFixed(2)}'),
                  if (item.reason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(item.reason),
                  ],
                  if (item.movie.genres.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(item.movie.genres.join(', ')),
                  ],
                  if (item.movie.overview.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      item.movie.overview,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackPoster extends StatelessWidget {
  final String title;

  const _FallbackPoster({required this.title});

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
