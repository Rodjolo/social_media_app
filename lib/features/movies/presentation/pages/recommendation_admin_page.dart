import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_item.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_cubit.dart';
import 'package:socail_media_app/features/movies/presentation/cubits/movie_states.dart';
import 'package:socail_media_app/responsive/constrained_scaffold.dart';

const int _minimumRatingsForStart = 5;
const int _recommendedRatingsForQuality = 15;

class RecommendationAdminPage extends StatefulWidget {
  final String uid;

  const RecommendationAdminPage({
    super.key,
    required this.uid,
  });

  @override
  State<RecommendationAdminPage> createState() => _RecommendationAdminPageState();
}

class _RecommendationAdminPageState extends State<RecommendationAdminPage> {
  late final MovieCubit movieCubit = context.read<MovieCubit>();
  late final bool isAdmin = context.read<AuthCubit>().currentUser?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    if (!isAdmin) {
      return;
    }

    final state = movieCubit.state;
    if (state is! MovieLoaded) {
      movieCubit.loadRecommendationsScreen(widget.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      appBar: AppBar(
        title: const Text('Панель рекомендаций'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Обновить',
              onPressed: () => movieCubit.loadRecommendationsScreen(widget.uid),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: isAdmin ? _buildAdminBody(context) : _buildAccessDenied(),
    );
  }

  Widget _buildAdminBody(BuildContext context) {
    return BlocBuilder<MovieCubit, MovieState>(
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

        final ratingCount = state.ratingsByMovieId.length;
        final latestGeneratedAt = _latestGeneratedAt(state.recommendations);
        final averageScore = averageRecommendationScore(state.recommendations);
        final topGenres = topRecommendationGenres(state.recommendations);
        final command = _rebuildCommand(widget.uid);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(
              title: 'Статус данных',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UID пользователя: ${widget.uid}'),
                  const SizedBox(height: 8),
                  Text('Оценено фильмов: $ratingCount'),
                  const SizedBox(height: 8),
                  Text(
                    state.recommendations.isEmpty
                        ? 'Рекомендации еще не рассчитаны.'
                        : 'Количество рекомендаций: ${state.recommendations.length}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    latestGeneratedAt == null
                        ? 'Последний пересчет: нет данных'
                        : 'Последний пересчет: ${_formatDateTime(latestGeneratedAt)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'Краткая аналитика',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Средний score рекомендаций: ${averageScore.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  Text(
                    topGenres.isEmpty
                        ? 'Доминирующие жанры: пока нет данных'
                        : 'Доминирующие жанры: ${topGenres.join(', ')}',
                  ),
                  const SizedBox(height: 8),
                  Text('Сила профиля: ${_profileStrengthLabel(ratingCount)}'),
                  const SizedBox(height: 12),
                  Text(_qualityAssessmentText(state.recommendations.length, ratingCount)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'Готовность к пересчету',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ThresholdRow(
                    label: 'Минимум для старта',
                    current: ratingCount,
                    target: _minimumRatingsForStart,
                  ),
                  const SizedBox(height: 8),
                  _ThresholdRow(
                    label: 'Рекомендуемый минимум',
                    current: ratingCount,
                    target: _recommendedRatingsForQuality,
                  ),
                  const SizedBox(height: 12),
                  Text(_buildRecommendationHint(ratingCount)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'Как это работает',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Алгоритм использует item-based collaborative filtering: оценки пользователя объединяются с MovieLens, после чего система ищет фильмы с похожими паттернами оценок.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pipeline: оценки пользователя -> PocketBase -> Python -> MovieLens -> recommendations -> Flutter.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'MovieLens выбран как открытый исследовательский датасет с большим количеством оценок и удобной структурой для построения рекомендаций.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'Запуск пересчета',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'На мобильном устройстве PowerShell-скрипт запустить нельзя, поэтому пересчет выполняется на компьютере в корне проекта одной командой.',
                  ),
                  const SizedBox(height: 12),
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
                        onPressed: () => _copyAndNotify(
                          context,
                          text: command,
                          message: 'Команда скопирована',
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text('Сформировать на компьютере'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copyAndNotify(
                          context,
                          text: widget.uid,
                          message: 'UID скопирован',
                        ),
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('Скопировать UID'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccessDenied() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48),
            SizedBox(height: 12),
            Text(
              'Эта панель доступна только администратору.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _StatusCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  final String label;
  final int current;
  final int target;

  const _ThresholdRow({
    required this.label,
    required this.current,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final isReached = current >= target;

    return Row(
      children: [
        Icon(
          isReached ? Icons.check_circle : Icons.pending_outlined,
          color: isReached ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$label: $current / $target'),
        ),
      ],
    );
  }
}

DateTime? _latestGeneratedAt(List<RecommendationItem> recommendations) {
  if (recommendations.isEmpty) {
    return null;
  }

  return recommendations
      .map((item) => item.generatedAt)
      .reduce((current, next) => current.isAfter(next) ? current : next);
}

String _buildRecommendationHint(int ratingCount) {
  if (ratingCount < _minimumRatingsForStart) {
    return 'Пока оценок слишком мало. Сначала оцените хотя бы 5 фильмов, иначе рекомендации будут слишком слабыми.';
  }

  if (ratingCount < _recommendedRatingsForQuality) {
    return 'Пересчет уже можно запускать, но для более устойчивых рекомендаций желательно оценить хотя бы 15 фильмов.';
  }

  return 'Оценок достаточно. Можно пересчитывать рекомендации, качество персонализации должно быть хорошим.';
}

String _profileStrengthLabel(int ratingCount) {
  if (ratingCount < _minimumRatingsForStart) {
    return 'слабый';
  }
  if (ratingCount < _recommendedRatingsForQuality) {
    return 'средний';
  }
  return 'хороший';
}

String _qualityAssessmentText(int recommendationCount, int ratingCount) {
  if (recommendationCount == 0) {
    return 'Пока система не построила рекомендации. Для демонстрации диплома нужно сначала оценить фильмы и выполнить пересчет.';
  }
  if (ratingCount < _recommendedRatingsForQuality) {
    return 'Подборка уже сформирована, но после дополнительных оценок топ рекомендаций, скорее всего, заметно изменится.';
  }
  return 'Подборка выглядит устойчивой: профиль пользователя уже достаточно заполнен, поэтому рекомендации можно считать качественными для демонстрации.';
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

Future<void> _copyAndNotify(
  BuildContext context, {
  required String text,
  required String message,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
