class BackendConfig {
  // For Android emulator use 10.0.2.2 instead of localhost.
  static const String pocketBaseUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'http://10.0.2.2:8090',
  );

  static const String recommendationServiceUrl = String.fromEnvironment(
    'RECOMMENDATION_SERVICE_URL',
    defaultValue: 'http://10.0.2.2:8091',
  );

  static const String recommendationServiceToken = String.fromEnvironment(
    'RECOMMENDATION_SERVICE_TOKEN',
    defaultValue: 'local-recommendation-service',
  );

  static const String usersCollection = 'users';
  static const String postsCollection = 'posts';
  static const String ratingsCollection = 'ratings';
  static const String moviesCollection = 'movies';
  static const String recommendationsCollection = 'recommendations';
  static const String mediaCollection = 'media';
}
