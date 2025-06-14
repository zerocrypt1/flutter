import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'https://flutter-i29z.onrender.com';
  static String get authGoogleUrl => dotenv.env['AUTH_GOOGLE_URL'] ?? '${apiBaseUrl}/api/auth/google';
  static String get authSigninUrl => dotenv.env['AUTH_SIGNIN_URL'] ?? '${apiBaseUrl}/api/auth/signin';
  static String get authSignupUrl => dotenv.env['AUTH_SIGNUP_URL'] ?? '${apiBaseUrl}/api/auth/signup';
  static String get authSendVerificationEmailUrl => dotenv.env['AUTH_SEND_VERIFICATION_EMAIL_URL'] ?? '${apiBaseUrl}/api/auth/send-verification-email';
  static String get googleWebClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '654973870763-ebiusu3snpce7ojmfuot8kbhup6m4qi3.apps.googleusercontent.com';
}