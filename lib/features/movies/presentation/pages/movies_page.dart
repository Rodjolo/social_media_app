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
        title: const Text('Movies'),
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
                    'No movies found. Add documents to movies collection.'),
              );
            }

            return RefreshIndicator(
              onRefresh: () => movieCubit.loadMoviesScreen(uid),
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Rate at least 15 movies to build your recommendation profile.',
                    ),
                  ),
                  ...state.movies.map(
                    (movie) => MovieCard(
                      movie: movie,
                      userRating: state.ratingsByMovieId[movie.id],
                      onRatingSelected: (rating) =>
                          movieCubit.saveMovieFeedback(
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
