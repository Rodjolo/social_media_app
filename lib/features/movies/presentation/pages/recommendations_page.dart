import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/movies/presentation/components/recommendation_card.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_cubit.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_states.dart';
import 'package:socail_media_app/features/movies/presentation/pages/recommendation_admin_page.dart';
import 'package:socail_media_app/responsive/constrained_scaffold.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  late final MovieCubit movieCubit = context.read<MovieCubit>();
  late final authUser = context.read<AuthCubit>().currentUser!;
  late final String uid = authUser.uid;
  late final bool isAdmin = authUser.isAdmin;

  @override
  void initState() {
    super.initState();
    movieCubit.loadRecommendationsScreen(uid);
  }

  void _openAdminPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecommendationAdminPage(uid: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: const Text('Рекомендации'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Панель пересчета',
              onPressed: _openAdminPanel,
              icon: const Icon(Icons.tune),
            ),
          IconButton(
            tooltip: 'Обновить',
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

          if (state is MovieError) {
            return Center(child: Text(state.message));
          }

          if (state is! MovieLoaded) {
            return const SizedBox();
          }

          return RefreshIndicator(
            onRefresh: () => movieCubit.loadRecommendationsScreen(uid),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Подборка рекомендаций',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.recommendations.isEmpty
                                ? 'Рекомендации пока не рассчитаны.'
                                : 'Найдено рекомендаций: ${state.recommendations.length}',
                          ),
                          if (isAdmin) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: _openAdminPanel,
                                icon: const Icon(Icons.terminal),
                                label: const Text('Открыть панель пересчета'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (state.recommendations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Сначала оцените фильмы, затем выполните пересчет рекомендаций через PowerShell-скрипт.',
                        ),
                      ),
                    ),
                  )
                else
                  ...state.recommendations.map(
                    (item) => RecommendationCard(item: item),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
