import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:github_var_updater/utils/app_notifier.dart';
import 'package:github_var_updater/utils/local_server.dart';
import 'package:http/http.dart' as http;

class OAuth2Token{
  /// Represents access token (short lived)
  final String accessToken;
  /// Represents refresh token (long lived)
  final String refreshToken;
  /// Represents the time (in seconds) in which, the access token will expire
  final int expiresIn;
  /// Represents token type i.e., Bearer
  final String tokenType;
  /// Scopes granted to access token
  final String scope;

  OAuth2Token({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    required this.scope
  });

  static OAuth2Token fromJson(Map<String, dynamic> json) {
    return OAuth2Token(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      expiresIn: json['expires_in'],
      tokenType: json['token_type'],
      scope: json['scope']
    );
  }
}

/// Provides a method to get access token for any google account
/// which is selected when google sign in dialog is shown
class GoogleUtils {

  // They should be present, but if they aren't then its an error
  static String clientId = dotenv.env['CLIENT_ID'] ?? 'ERROR';
  static String clientSecret = dotenv.env['CLIENT_SECRET'] ?? 'ERROR';
  static String redirectUri = dotenv.env['REDIRECT_URI'] ?? 'ERROR';

  static const List<String> scopes = [
    'https://www.googleapis.com/auth/youtube.upload'
  ];

  static bool _hasRequiredScopes(OAuth2Token token) {
    List<String> grantedScopes = token.scope.split(' ');
    return scopes.every((scope) => grantedScopes.contains(scope));
  }

  static Future<OAuth2Token?> getOuth2Token() async {

    if (clientId == 'ERROR' || clientSecret == 'ERROR' || redirectUri == 'ERROR') {
      AppNotifier.showErrorDialog(errorMessage: "Client id or secret or redirect url couldn't be loaded, hence cannot proceed furhter!");
      return null;
    }

    try {
      final authUrl = Uri(
        scheme: 'https',
        host: 'accounts.google.com',
        path: '/o/oauth2/auth',
        queryParameters: {
          'client_id' : clientId,
          'response_type' : 'code',
          'redirect_uri' : redirectUri,
          'scope': scopes.join(' '),
          'access_type': 'offline',
          'prompt': 'consent'
        }
      );

      await LocalServer.initiateAuthentication(authUrl);
      bool timeoutOccured = await LocalServer.waitForAuth();

      if (timeoutOccured) {
        AppNotifier.notifyUserAboutInfo(info: 'Authentication failed because timeout occured!');
        return null;
      } else if (LocalServer.googleAuthCode == null) {
        return null;
      }

      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'), // token_uri
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'code' : LocalServer.googleAuthCode,
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirectUri,
          'grant_type' : 'authorization_code'
        }
      );

      if (response.statusCode == 200) {
        OAuth2Token token = OAuth2Token.fromJson(jsonDecode(response.body));

        if (_hasRequiredScopes(token)) {
          return token;
        } else {
          AppNotifier.notifyUserAboutError(
            errorMessage: 'You have not granted app all permissions! Please try again but this time tick all checkboxes.',
            duration: const Duration(seconds: 8),
          );
        }
      } else {
        AppNotifier.showErrorDialog(
          errorMessage: 
                      'Error: ${response.statusCode} - ${response.reasonPhrase}'
                      '\nResponse body: ${response.body}'
        );
      }
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured : ${e.toString()}');
    }

    return null;
  }
}