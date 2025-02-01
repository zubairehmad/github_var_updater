import 'package:github_var_updater/utils/app_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// This class helps to store key-value pairs that persists
/// even after app is closed. They are stored locally and will
/// be cleared if app's data is cleared.
class Keystore {

  /// Stores the given key value pair. Doesn't throws exception
  static Future<void> savePair({required String key, required dynamic value}) async {
    try {
      SharedPreferences preference = await SharedPreferences.getInstance();

      // Value specific storage
      if (value is String) {
        preference.setString(key, value);
      } else if (value is int) {
        preference.setInt(key, value);
      } else if (value is bool) {
        preference.setBool(key, value);
      } else if (value is double) {
        preference.setDouble(key, value);
      } else if (value is List<String>) {
        preference.setStringList(key, value);
      } else {
        throw UnsupportedError('The type "${value.runtimeType}" isn\'t supported!');
      }
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: e.toString());
    }
  }

  /// Retrives the value associated with given key. Returns null if can't find.
  /// 
  /// Doesn't throw exception
  static Future<dynamic> getValueForKey({required String key}) async {
    try {
      SharedPreferences pref = await SharedPreferences.getInstance();
      return pref.get(key);
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: e.toString());
    }
    return null;
  }

  /// Tells whether given key is present in the keystore
  /// 
  /// Doesn't throw exception
  static Future<bool> contains({required String key}) async {
    try {
      SharedPreferences pref = await SharedPreferences.getInstance();
      return pref.containsKey(key);
    } catch (e) {
      AppNotifier.showErrorDialog(errorMessage: e.toString());
    }
    return false;
  }
}