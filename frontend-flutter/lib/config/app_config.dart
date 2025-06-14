class AppConfig {
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL', 
    defaultValue: 'https://your-production-api.com');
  
  static const String _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID', 
    defaultValue: '');
  
  static String get apiBaseUrl => _baseUrl;
  static String get googleClientId => _googleClientId;
  
  // Different configs for different environments
  static bool get isProduction => _baseUrl.contains('your-production-api.com');
  static bool get isDevelopment => _baseUrl.contains('localhost');
}