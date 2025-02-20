import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:github_var_updater/utils/app_notifier.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  /// Represents jwd token
  final String idToken;
  /// Scopes granted to access token
  final String scope;

  OAuth2Token({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    required this.idToken,
    required this.scope
  });

  static OAuth2Token fromJson(Map<String, dynamic> json) {
    return OAuth2Token(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      expiresIn: json['expires_in'],
      tokenType: json['token_type'],
      idToken: json['id_token'],
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

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/youtube.upload'  // For uploading a youtube video
    ],
    serverClientId: clientId,
  );

  static Future<OAuth2Token?> getOuth2Token() async {

    if (clientId == 'ERROR' || clientSecret == 'ERROR' || redirectUri == 'ERROR') {
      AppNotifier.showErrorDialog(errorMessage: "Client id or secret or redirect url couldn't be loaded, hence cannot proceed furhter!");
      return null;
    }

    try {
      if (_googleSignIn.currentUser != null) {
        // Ensure refresh_token is included in every response
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
      }

      GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account != null) {
        String? authCode = account.serverAuthCode;

        if (authCode == null) {
          AppNotifier.showErrorDialog(errorMessage: 'Unable to get server auth code! Cannot proceed!');
          return null;
        }

        final response = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'), // token_uri
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'code' : authCode,
            'client_id': clientId,
            'client_secret': clientSecret,
            'redirect_uri': redirectUri,
            'grant_type' : 'authorization_code'
          }
        );

        if (response.statusCode == 200) {
          return OAuth2Token.fromJson(jsonDecode(response.body));
        } else {
          AppNotifier.showErrorDialog(
            errorMessage: 
                        'Error: ${response.statusCode} - ${response.reasonPhrase}'
                        '\nResponse body: ${response.body}'
          );
        }
      }
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured : ${e.toString()}');
    }
    return null;
  }
}