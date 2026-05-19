import 'dart:async';
import 'dart:convert';

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
  late final RecommendationServiceClient serviceClient =
      RecommendationServiceClient();

  RecommendationRebuildStatus? serviceStatus;
  bool serviceHealthy = false;
  bool serviceLoading = false;
  bool serviceBusy = false;
  DateTime? lastAppliedFinishedAt;
  Timer? pollTimer;

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

    refreshServiceState();
    pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => refreshServiceState(silent: true),
    );
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    serviceClient.dispose();
    super.dispose();
  }

  Future<void> refreshServiceState({bool silent = false}) async {
    if (serviceBusy) {
      return;
    }

    if (!silent && mounted) {
      setState(() => serviceLoading = true);
    }

    try {
      final healthy = await serviceClient.isHealthy();
      RecommendationRebuildStatus? status;
      if (healthy) {
        status = await serviceClient.fetchStatus(widget.uid);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        serviceHealthy = healthy;
        serviceStatus = status;
      });

      final shouldRefreshRecommendations = status != null &&
          status.state == 'completed' &&
          status.finishedAt != null &&
          status.finishedAt != lastAppliedFinishedAt;
      if (shouldRefreshRecommendations) {
        lastAppliedFinishedAt = status!.finishedAt;
        await movieCubit.loadRecommendationsScreen(widget.uid);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        serviceHealthy = false;
      });
    } finally {
      if (mounted && !silent) {
        setState(() => serviceLoading = false);
      }
    }
  }

  Future<void> triggerRebuild() async {
    setState(() => serviceBusy = true);
    try {
      await serviceClient.triggerRebuild(userId: widget.uid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пересчет рекомендаций запущен через локальный сервис.'),
        ),
      );
      await refreshServiceState();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось запустить пересчет: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => serviceBusy = false);
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
                await refreshServiceState();
                await movieCubit.loadRecommendationsScreen(widget.uid);
              },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: isAdmin ? buildAdminBody(context) : buildAccessDenied(),
    );
  }

  Widget buildAdminBody(BuildContext context) {
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
        final latestRecommendationAt =
            latestGeneratedAt(state.recommendations);
        final averageScore = averageRecommendationScore(state.recommendations);
        final topGenres = topRecommendationGenres(state.recommendations);
        final scriptCommand = rebuildCommand(widget.uid);
        final serviceCommand = buildServiceCommand();
        final report = serviceStatus?.report;
        final comparisonReport = report?['comparison'] as Map<String, dynamic>?;
        final validationReport = report?['validation'] as Map<String, dynamic>?;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StatusCard(
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
                    latestRecommendationAt == null
                        ? 'Последний пересчет: нет данных'
                        : 'Последний пересчет: ${formatDateTime(latestRecommendationAt)}',
                  ),
                  if ((state.autoRebuildMessage ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(state.autoRebuildMessage!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            StatusCard(
              title: 'Локальный сервис пересчета',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceHealthy
                        ? 'Сервис доступен: ${BackendConfig.recommendationServiceUrl}'
                        : 'Сервис недоступен. Сначала запустите его на компьютере.',
                  ),
                  if (serviceStatus != null) ...[
                    const SizedBox(height: 8),
                    Text('Состояние: ${serviceStateLabel(serviceStatus!)}'),
                    if ((serviceStatus?.message ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Сообщение: ${serviceStatus!.message}'),
                    ],
                    if ((serviceStatus?.details ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        'Детали: ${serviceStatus!.details}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (serviceStatus?.startedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Запущено: ${formatDateTime(serviceStatus!.startedAt!)}',
                      ),
                    ],
                    if (serviceStatus?.finishedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Завершено: ${formatDateTime(serviceStatus!.finishedAt!)}',
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: (!serviceHealthy ||
                                serviceBusy ||
                                serviceLoading ||
                                ratingCount < _minimumRatingsForStart)
                            ? null
                            : triggerRebuild,
                        icon: const Icon(Icons.auto_fix_high),
                        label: Text(
                          serviceBusy ? 'Запуск...' : 'Сформировать рекомендации',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: serviceLoading ? null : refreshServiceState,
                        icon: const Icon(Icons.sync),
                        label: const Text('Проверить статус'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            StatusCard(
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
                  Text('Сила профиля: ${profileStrengthLabel(ratingCount)}'),
                  const SizedBox(height: 12),
                  Text(
                    qualityAssessmentText(
                      state.recommendations.length,
                      ratingCount,
                    ),
                  ),
                  if (comparisonReport != null) ...[
                    const SizedBox(height: 12),
                    Text(buildComparisonSummary(comparisonReport)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            StatusCard(
              title: 'Валидация качества',
              child: buildValidationSection(validationReport),
            ),
            const SizedBox(height: 12),
            StatusCard(
              title: 'Готовность к пересчету',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ThresholdRow(
                    label: 'Минимум для старта',
                    current: ratingCount,
                    target: _minimumRatingsForStart,
                  ),
                  const SizedBox(height: 8),
                  ThresholdRow(
                    label: 'Рекомендуемый минимум',
                    current: ratingCount,
                    target: _recommendedRatingsForQuality,
                  ),
                  const SizedBox(height: 12),
                  Text(buildRecommendationHint(ratingCount)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            StatusCard(
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
                    'Качество оценивается через holdout-валидацию: часть высоких оценок временно скрывается, и мы проверяем, возвращает ли алгоритм эти фильмы в топ рекомендаций.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            StatusCard(
              title: 'Запуск сервиса и ручной fallback',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Для демонстрации можно запустить локальный сервис один раз на компьютере, а дальше пересчитывать рекомендации прямо из приложения.',
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
                    'Если сервис не запущен, остается ручной сценарий через PowerShell-скрипт:',
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
                        onPressed: () => copyAndNotify(
                          context,
                          text: serviceCommand,
                          message: 'Команда запуска сервиса скопирована.',
                        ),
                        icon: const Icon(Icons.memory),
                        label: const Text('Скопировать команду сервиса'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => copyAndNotify(
                          context,
                          text: scriptCommand,
                          message: 'Команда fallback-скрипта скопирована.',
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

  Widget buildValidationSection(Map<String, dynamic>? validationReport) {
    if (validationReport == null) {
      return const Text(
        'После следующего пересчета здесь появятся метрики качества рекомендаций.',
      );
    }

    final status = validationReport['status']?.toString() ?? 'unknown';
    final message = normalizePossibleMojibake(
      validationReport['message']?.toString() ?? '',
    );

    if (status != 'ok') {
      return Text(
        message.isEmpty ? 'Недостаточно данных для валидации.' : message,
      );
    }

    final heldOutTitles =
        (validationReport['heldOutTitles'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
    final hitTitles =
        (validationReport['hitTitles'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Качество: ${normalizePossibleMojibake(validationReport['qualityLabel']?.toString() ?? 'нет данных')}',
        ),
        const SizedBox(height: 8),
        Text('Precision@K: ${validationReport['precisionAtK'] ?? 0}'),
        const SizedBox(height: 8),
        Text('Recall@K: ${validationReport['recallAtK'] ?? 0}'),
        const SizedBox(height: 8),
        Text('HitRate@K: ${validationReport['hitRateAtK'] ?? 0}'),
        const SizedBox(height: 8),
        Text('nDCG@K: ${validationReport['ndcgAtK'] ?? 0}'),
        const SizedBox(height: 8),
        Text('Контрольных фильмов: ${validationReport['holdoutCount'] ?? 0}'),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 12),
        Text(
          heldOutTitles.isEmpty
              ? 'Скрытые фильмы: нет данных'
              : 'Скрытые фильмы для проверки: ${heldOutTitles.map(normalizePossibleMojibake).join(', ')}',
        ),
        const SizedBox(height: 8),
        Text(
          hitTitles.isEmpty
              ? 'Совпадений в топе нет'
              : 'Алгоритм успешно вернул в топ: ${hitTitles.map(normalizePossibleMojibake).join(', ')}',
        ),
      ],
    );
  }

  Widget buildAccessDenied() {
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

String? tryDecodeWindows1251Mojibake(String value) {
  try {
    final decoded = utf8.decode(encodeWindows1251(value));
    return decoded == value ? null : decoded;
  } catch (_) {
    return null;
  }
}

List<int> encodeWindows1251(String value) {
  final bytes = <int>[];

  for (final codePoint in value.runes) {
    if (codePoint <= 0x7f) {
      bytes.add(codePoint);
      continue;
    }

    final index = windows1251CodePoints.indexOf(codePoint);
    if (index == -1) {
      throw const FormatException(
        'Character is not representable in Windows-1251',
      );
    }
    bytes.add(0x80 + index);
  }

  return bytes;
}

const windows1251CodePoints = <int>[
  0x0402,
  0x0403,
  0x201a,
  0x0453,
  0x201e,
  0x2026,
  0x2020,
  0x2021,
  0x20ac,
  0x2030,
  0x0409,
  0x2039,
  0x040a,
  0x040c,
  0x040b,
  0x040f,
  0x0452,
  0x2018,
  0x2019,
  0x201c,
  0x201d,
  0x2022,
  0x2013,
  0x2014,
  0x0000,
  0x2122,
  0x0459,
  0x203a,
  0x045a,
  0x045c,
  0x045b,
  0x045f,
  0x00a0,
  0x040e,
  0x045e,
  0x0408,
  0x00a4,
  0x0490,
  0x00a6,
  0x00a7,
  0x0401,
  0x00a9,
  0x0404,
  0x00ab,
  0x00ac,
  0x00ad,
  0x00ae,
  0x0407,
  0x00b0,
  0x00b1,
  0x0406,
  0x0456,
  0x0491,
  0x00b5,
  0x00b6,
  0x00b7,
  0x0451,
  0x2116,
  0x0454,
  0x00bb,
  0x0458,
  0x0405,
  0x0455,
  0x0457,
  0x0410,
  0x0411,
  0x0412,
  0x0413,
  0x0414,
  0x0415,
  0x0416,
  0x0417,
  0x0418,
  0x0419,
  0x041a,
  0x041b,
  0x041c,
  0x041d,
  0x041e,
  0x041f,
  0x0420,
  0x0421,
  0x0422,
  0x0423,
  0x0424,
  0x0425,
  0x0426,
  0x0427,
  0x0428,
  0x0429,
  0x042a,
  0x042b,
  0x042c,
  0x042d,
  0x042e,
  0x042f,
  0x0430,
  0x0431,
  0x0432,
  0x0433,
  0x0434,
  0x0435,
  0x0436,
  0x0437,
  0x0438,
  0x0439,
  0x043a,
  0x043b,
  0x043c,
  0x043d,
  0x043e,
  0x043f,
  0x0440,
  0x0441,
  0x0442,
  0x0443,
  0x0444,
  0x0445,
  0x0446,
  0x0447,
  0x0448,
  0x0449,
  0x044a,
  0x044b,
  0x044c,
  0x044d,
  0x044e,
  0x044f,
];

class StatusCard extends StatelessWidget {
  final String title;
  final Widget child;

  const StatusCard({
    super.key,
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

class ThresholdRow extends StatelessWidget {
  final String label;
  final int current;
  final int target;

  const ThresholdRow({
    super.key,
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

DateTime? latestGeneratedAt(List<RecommendationItem> recommendations) {
  if (recommendations.isEmpty) {
    return null;
  }

  return recommendations
      .map((item) => item.generatedAt)
      .reduce((current, next) => current.isAfter(next) ? current : next);
}

String buildRecommendationHint(int ratingCount) {
  if (ratingCount < _minimumRatingsForStart) {
    return 'Пока оценок слишком мало. Сначала оцените хотя бы 5 фильмов, иначе рекомендации будут слабыми.';
  }

  if (ratingCount < _recommendedRatingsForQuality) {
    return 'Пересчет уже можно запускать, но для более устойчивых рекомендаций желательно оценить хотя бы 15 фильмов.';
  }

  return 'Оценок достаточно. Можно пересчитывать рекомендации, качество персонализации должно быть хорошим.';
}

String profileStrengthLabel(int ratingCount) {
  if (ratingCount < _minimumRatingsForStart) {
    return 'слабый';
  }
  if (ratingCount < _recommendedRatingsForQuality) {
    return 'средний';
  }
  return 'хороший';
}

String qualityAssessmentText(int recommendationCount, int ratingCount) {
  if (recommendationCount == 0) {
    return 'Пока система не построила рекомендации. Для демонстрации сначала оцените фильмы и запустите пересчет.';
  }
  if (ratingCount < _recommendedRatingsForQuality) {
    return 'Подборка уже сформирована, но после дополнительных оценок топ рекомендаций, скорее всего, заметно изменится.';
  }
  return 'Подборка выглядит устойчивой: профиль пользователя уже достаточно заполнен, поэтому рекомендации можно считать качественными для демонстрации.';
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}

String serviceStateLabel(RecommendationRebuildStatus status) {
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

String buildComparisonSummary(Map<String, dynamic> comparisonReport) {
  final overlapRatio = comparisonReport['overlapRatio']?.toString() ?? '0';
  final newMovieIds =
      (comparisonReport['newMovieIds'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList();
  final currentTopGenres =
      (comparisonReport['currentTopGenres'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList();

  return 'Сравнение с прошлым пересчетом: overlap = $overlapRatio, '
      'новые movieId = ${newMovieIds.isEmpty ? 'нет' : newMovieIds.join(', ')}, '
      'топ жанры = ${currentTopGenres.isEmpty ? 'нет данных' : currentTopGenres.join(', ')}.';
}

String rebuildCommand(String uid) {
  return 'py .\\tools\\recommendation_pipeline\\rebuild_recommendations.ps1 `\n'
      '  -SuperuserEmail "admin@example.com" `\n'
      '  -SuperuserPassword "your_password" `\n'
      '  -UserId "$uid"';
}

String buildServiceCommand() {
  return 'py .\\tools\\recommendation_pipeline\\recommendation_service.py `\n'
      '  --superuser-email "admin@example.com" `\n'
      '  --superuser-password "your_password"';
}

Future<void> copyAndNotify(
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

String normalizePossibleMojibake(String value) {
  if (value.isEmpty) {
    return value;
  }

  final windows1251Decoded = tryDecodeWindows1251Mojibake(value);
  if (windows1251Decoded != null) {
    return windows1251Decoded;
  }

  const suspiciousFragments = [
    'РЎ',
    'Р',
    'СЃ',
    'СЂ',
    'В°',
    'вЂ',
  ];
  final looksBroken = suspiciousFragments.any(value.contains);
  if (!looksBroken) {
    return value;
  }

  try {
    return utf8.decode(encodeWindows1251(value));
  } catch (_) {
    try {
      return utf8.decode(latin1.encode(value));
    } catch (_) {
      return value;
    }
  }
}
