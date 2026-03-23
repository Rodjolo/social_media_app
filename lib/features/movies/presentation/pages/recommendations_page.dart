import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/movies/presentation/components/recommendation_card.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_cubit.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_states.dart';
import 'package:socail_media_app/responsive/constrained_scaffold.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  late final MovieCubit movieCubit = context.read<MovieCubit>();
  late final String uid = context.read<AuthCubit>().currentUser!.uid;

  @override
  void initState() {
    super.initState();
    movieCubit.loadRecommendationsScreen(uid);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        actions: [
          IconButton(
            onPressed: () => movieCubit.loadRecommendationsScreen(uid),
            icon: const Icon(Icons.refresh),
          ),
        ],
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
            if (state.recommendations.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Recommendations are empty. Run the Python pipeline and write results to recommendations/{uid}/items.',
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => movieCubit.loadRecommendationsScreen(uid),
              child: ListView.builder(
                itemCount: state.recommendations.length,
                itemBuilder: (context, index) => RecommendationCard(
                  item: state.recommendations[index],
                ),
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
