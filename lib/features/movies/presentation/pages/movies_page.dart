import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/movies/presentation/components/movie_card.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_cubit.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_states.dart';
import 'package:socail_media_app/responsive/constrained_scaffold.dart';

class MoviesPage extends StatefulWidget {
  const MoviesPage({super.key});

  @override
  State<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends State<MoviesPage> {
  late final MovieCubit movieCubit = context.read<MovieCubit>();
  late final String uid = context.read<AuthCubit>().currentUser!.uid;

  @override
  void initState() {
    super.initState();
    movieCubit.loadMoviesScreen(uid);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: const Text('Фильмы'),
      ),
      body: BlocConsumer<MovieCubit, MovieState>(
        listener: (context, state) {
          if (state is MovieError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is MovieLoading || state is MovieInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MovieLoaded) {
            if (state.movies.isEmpty) {
              return const Center(
                child: Text(
                  'Фильмы не найдены. Загрузите данные в коллекцию movies.',
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => movieCubit.loadMoviesScreen(uid),
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Оцените как минимум 15 фильмов, чтобы сформировать профиль предпочтений.',
                    ),
                  ),
                  if ((state.autoRebuildMessage ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Card(
                        color: state.isAutoRebuilding
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                state.isAutoRebuilding
                                    ? Icons.autorenew
                                    : Icons.info_outline,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(state.autoRebuildMessage!),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ...state.movies.map(
                    (movie) => MovieCard(
                      movie: movie,
                      userRating: state.ratingsByMovieId[movie.id],
                      onRatingSelected: (rating) => movieCubit.saveMovieFeedback(
                        uid: uid,
                        movie: movie,
                        rating: rating,
                      ),
                      onLikePressed: () => movieCubit.saveMovieFeedback(
                        uid: uid,
                        movie: movie,
                        liked:
                            !(state.ratingsByMovieId[movie.id]?.liked ?? false),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is MovieError) {
            return Center(child: Text(state.message));
          }

          return const SizedBox();
        },
      ),
    );
  }
}
