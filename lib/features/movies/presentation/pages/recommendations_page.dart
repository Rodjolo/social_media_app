import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_item.dart';
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
        title: const Text('Рекомендации'),
        actions: [
          IconButton(
            tooltip: 'Как пересчитать',
            onPressed: () => _showRebuildHelp(context),
            icon: const Icon(Icons.info_outline),
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

          if (state is MovieLoaded) {
            return RefreshIndicator(
              onRefresh: () => movieCubit.loadRecommendationsScreen(uid),
              child: ListView(
                children: [
                  _RecommendationStatusCard(
                    uid: uid,
                    recommendations: state.recommendations,
                    onOpenHelp: () => _showRebuildHelp(context),
                  ),
                  if (state.recommendations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Рекомендации пока пусты. Сначала оцените фильмы, затем запустите пересчет через PowerShell-скрипт.',
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
          }

          if (state is MovieError) {
            return Center(child: Text(state.message));
          }

          return const SizedBox();
        },
      ),
    );
  }

  Future<void> _showRebuildHelp(BuildContext context) {
    final command = _rebuildCommand(uid);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Пересчет рекомендаций',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Скрипт уже описан в README. Для пересчета откройте PowerShell в корне проекта и выполните команду ниже.',
                ),
                const SizedBox(height: 16),
                SelectableText(
                  command,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: command));
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Команда скопирована'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Скопировать команду'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: uid));
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('UID скопирован'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Скопировать UID'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecommendationStatusCard extends StatelessWidget {
  final String uid;
  final List<RecommendationItem> recommendations;
  final VoidCallback onOpenHelp;

  const _RecommendationStatusCard({
    required this.uid,
    required this.recommendations,
    required this.onOpenHelp,
  });

  @override
  Widget build(BuildContext context) {
    final latestGeneratedAt = recommendations.isEmpty
        ? null
        : recommendations
            .map((item) => item.generatedAt)
            .reduce(
              (current, next) => current.isAfter(next) ? current : next,
            );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Статус рекомендаций',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text('UID пользователя: $uid'),
              const SizedBox(height: 6),
              Text(
                recommendations.isEmpty
                    ? 'Рекомендации еще не рассчитаны.'
                    : 'Количество рекомендаций: ${recommendations.length}',
              ),
              const SizedBox(height: 6),
              Text(
                latestGeneratedAt == null
                    ? 'Последний пересчет: нет данных'
                    : 'Последний пересчет: ${_formatDateTime(latestGeneratedAt)}',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onOpenHelp,
                  icon: const Icon(Icons.terminal),
                  label: const Text('Как пересчитать'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}

String _rebuildCommand(String uid) {
  return '.\\tools\\recommendation_pipeline\\rebuild_recommendations.ps1 `\n'
      '  -SuperuserEmail "admin@example.com" `\n'
      '  -SuperuserPassword "your_password" `\n'
      '  -UserId "$uid"';
}
