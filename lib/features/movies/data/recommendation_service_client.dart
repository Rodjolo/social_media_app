import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:socail_media_app/config/backend_config.dart';
import 'package:socail_media_app/features/movies/domain/entities/recommendation_rebuild_status.dart';

class RecommendationServiceClient {
  final http.Client _httpClient;

  RecommendationServiceClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Map<String, String> get _serviceHeaders {
    final token = BackendConfig.recommendationServiceToken.trim();
    if (token.isEmpty) {
      return const {};
    }

    return {
      'X-Recommendation-Service-Token': token,
    };
  }

  Future<RecommendationRebuildStatus?> fetchStatus(String userId) async {
    final uri = Uri.parse(
      '${BackendConfig.recommendationServiceUrl}/status?userId=$userId',
    );
    final response = await _httpClient.get(uri, headers: _serviceHeaders);

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to load rebuild status: ${response.body}');
    }

    return RecommendationRebuildStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> triggerRebuild({
    required String userId,
    int topN = 10,
  }) async {
    final uri = Uri.parse('${BackendConfig.recommendationServiceUrl}/rebuild');
    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ..._serviceHeaders,
      },
      body: jsonEncode({
        'userId': userId,
        'topN': topN,
      }),
    );

    if (response.statusCode != 202) {
      throw Exception('Failed to start rebuild: ${response.body}');
    }
  }

  Future<bool> isHealthy() async {
    final uri = Uri.parse('${BackendConfig.recommendationServiceUrl}/health');
    final response = await _httpClient.get(uri);
    return response.statusCode == 200;
  }

  void dispose() {
    _httpClient.close();
  }
}
