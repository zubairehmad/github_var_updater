import 'package:google_sign_in/google_sign_in.dart';
import 'package:github_var_updater/utils/app_notifier.dart';

/// Provides a method to get access token for any google account
/// which is selected when google sign in dialog is shown
class GoogleUtils {

  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static Future<String?> getAccessTokenForGoogleAccount() async {
    try {

      if (_googleSignIn.currentUser != null) {
        // Ensure user is asked about what account to choose everytime
        await _googleSignIn.signOut();
      }

      GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        return (await account.authentication).accessToken;
      }
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: 'Unexpected error occured : ${e.toString()}');
    }
    return null;
  }
}