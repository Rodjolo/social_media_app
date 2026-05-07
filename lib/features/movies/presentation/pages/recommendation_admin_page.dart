import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socail_media_app/config/backend_config.dart';
import 'package:socail_media_app/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:socail_media_app/features/movies/data/recommendation_service_client.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_item.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_rebuild_status.dart';
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
  late final bool isAdmin =
      context.read<AuthCubit>().currentUser?.isAdmin ?? false;
  late final RecommendationServiceClient _serviceClient =
      RecommendationServiceClient();

  RecommendationRebuildStatus? _serviceStatus;
  bool _serviceHealthy = false;
  bool _serviceLoading = false;
  bool _serviceBusy = false;
  DateTime? _lastAppliedFinishedAt;
  Timer? _pollTimer;

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

    _refreshServiceState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshServiceState(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _serviceClient.dispose();
    super.dispose();
  }

  Future<void> _refreshServiceState({bool silent = false}) async {
    if (_serviceBusy) {
      return;
    }

    if (!silent && mounted) {
      setState(() => _serviceLoading = true);
    }

    try {
      final healthy = await _serviceClient.isHealthy();
      RecommendationRebuildStatus? status;
      if (healthy) {
        status = await _serviceClient.fetchStatus(widget.uid);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _serviceHealthy = healthy;
        _serviceStatus = status;
      });

      final shouldRefreshRecommendations = status != null &&
          status.state == 'completed' &&
          status.finishedAt != null &&
          status.finishedAt != _lastAppliedFinishedAt;
      if (shouldRefreshRecommendations) {
        _lastAppliedFinishedAt = status!.finishedAt;
        movieCubit.loadRecommendationsScreen(widget.uid);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _serviceHealthy = false;
      });
    } finally {
      if (mounted && !silent) {
        setState(() => _serviceLoading = false);
      }
    }
  }

  Future<void> _triggerRebuild() async {
    setState(() => _serviceBusy = true);
    try {
      await _serviceClient.triggerRebuild(userId: widget.uid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пересчет запущен через локальный сервис'),
        ),
      );
      await _refreshServiceState();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось запустить пересчет: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _serviceBusy = false);
      }
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
              onPressed: () async {
                await _refreshServiceState();
                await movieCubit.loadRecommendationsScreen(widget.uid);
              },
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
        final scriptCommand = _rebuildCommand(widget.uid);
        final serviceCommand = _serviceCommand();

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
              title: 'Локальный сервис пересчета',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _serviceHealthy
                        ? 'Сервис доступен: ${BackendConfig.recommendationServiceUrl}'
                        : 'Сервис недоступен. Сначала запустите его на компьютере.',
                  ),
                  if (_serviceStatus != null) ...[
                    const SizedBox(height: 8),
                    Text('Состояние: ${_serviceStateLabel(_serviceStatus!)}'),
                    if ((_serviceStatus?.message ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Сообщение: ${_serviceStatus!.message}'),
                    ],
                    if ((_serviceStatus?.details ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        'Детали: ${_serviceStatus!.details}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (_serviceStatus?.startedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Запущено: ${_formatDateTime(_serviceStatus!.startedAt!)}',
                      ),
                    ],
                    if (_serviceStatus?.finishedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Завершено: ${_formatDateTime(_serviceStatus!.finishedAt!)}',
                      ),
                    ],
                    if (_serviceStatus?.report != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _buildComparisonSummary(_serviceStatus!.report!),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: (!_serviceHealthy ||
                                _serviceBusy ||
                                _serviceLoading ||
                                ratingCount < _minimumRatingsForStart)
                            ? null
                            : _triggerRebuild,
                        icon: const Icon(Icons.auto_fix_high),
                        label: Text(
                          _serviceBusy ? 'Запуск...' : 'Сформировать рекомендации',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _serviceLoading ? null : _refreshServiceState,
                        icon: const Icon(Icons.sync),
                        label: const Text('Проверить статус'),
                      ),
                    ],
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
                  Text(
                    'Средний score рекомендаций: ${averageScore.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topGenres.isEmpty
                        ? 'Доминирующие жанры: пока нет данных'
                        : 'Доминирующие жанры: ${topGenres.join(', ')}',
                  ),
                  const SizedBox(height: 8),
                  Text('Сила профиля: ${_profileStrengthLabel(ratingCount)}'),
                  const SizedBox(height: 12),
                  Text(
                    _qualityAssessmentText(
                      state.recommendations.length,
                      ratingCount,
                    ),
                  ),
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
              title: 'Запуск сервиса и ручной fallback',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Для дипломной демонстрации можно один раз запустить локальный сервис на компьютере, а дальше запускать пересчет прямо из приложения.',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    serviceCommand,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Если сервис не запущен, остается доступен ручной сценарий через PowerShell-скрипт:',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    scriptCommand,
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
                          text: serviceCommand,
                          message: 'Команда запуска сервиса скопирована',
                        ),
                        icon: const Icon(Icons.memory),
                        label: const Text('Скопировать команду сервиса'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copyAndNotify(
                          context,
                          text: scriptCommand,
                          message: 'Команда скрипта скопирована',
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text('Скопировать fallback-команду'),
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

String _serviceStateLabel(RecommendationRebuildStatus status) {
  switch (status.state) {
    case 'running':
      return 'идет пересчет';
    case 'completed':
      return 'завершено успешно';
    case 'failed':
      return 'завершено с ошибкой';
    default:
      return 'ожидание';
  }
}

String _buildComparisonSummary(Map<String, dynamic> report) {
  final overlapRatio = report['overlapRatio']?.toString() ?? '0';
  final newMovieIds = (report['newMovieIds'] as List<dynamic>? ?? const [])
      .map((item) => item.toString())
      .toList();
  final currentTopGenres =
      (report['currentTopGenres'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList();

  return 'Сравнение с прошлым пересчетом: overlap = $overlapRatio, '
      'новые movieId = ${newMovieIds.isEmpty ? 'нет' : newMovieIds.join(', ')}, '
      'топ жанры = ${currentTopGenres.isEmpty ? 'нет данных' : currentTopGenres.join(', ')}.';
}

String _rebuildCommand(String uid) {
  return '.\\tools\\recommendation_pipeline\\rebuild_recommendations.ps1 `\n'
      '  -SuperuserEmail "admin@example.com" `\n'
      '  -SuperuserPassword "your_password" `\n'
      '  -UserId "$uid"';
}

String _serviceCommand() {
  return 'python .\\tools\\recommendation_pipeline\\recommendation_service.py `\n'
      '  --superuser-email "admin@example.com" `\n'
      '  --superuser-password "your_password"';
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
