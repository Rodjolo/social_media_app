class RecommendationRebuildStatus {
  final String userId;
  final String state;
  final bool isRunning;
  final String? message;
  final String? details;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? exitCode;
  final Map<String, dynamic>? report;

  const RecommendationRebuildStatus({
    required this.userId,
    required this.state,
    required this.isRunning,
    this.message,
    this.details,
    this.startedAt,
    this.finishedAt,
    this.exitCode,
    this.report,
  });

  factory RecommendationRebuildStatus.fromJson(Map<String, dynamic> json) {
    return RecommendationRebuildStatus(
      userId: json['userId']?.toString() ?? '',
      state: json['state']?.toString() ?? 'idle',
      isRunning: json['isRunning'] == true,
      message: json['message']?.toString(),
      details: json['details']?.toString(),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
      finishedAt: DateTime.tryParse(json['finishedAt']?.toString() ?? ''),
      exitCode: (json['exitCode'] as num?)?.toInt(),
      report: json['report'] is Map<String, dynamic>
          ? json['report'] as Map<String, dynamic>
          : null,
    );
  }
}
