import 'package:shared_preferences/shared_preferences.dart';

// This class helps to store key-value pairs that persists
// even after app is closed. They are stored locally.
class Keystore {

  // Stores the given key value pair
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
      print('Exception occured: ${e.toString()}');
    }
  }

  // Retrives the value associated with given key. Returns null if can't find.
  static Future<dynamic> getValueForKey({required String key}) async {
    try {
      SharedPreferences pref = await SharedPreferences.getInstance();
      return pref.get(key);
    } catch (e) {
      print('Exception occured: ${e.toString()}');
    }
    return null;
  }

  // Tells whether given key is present in the keystore
  static Future<bool> contains({required String key}) async {
    return (await SharedPreferences.getInstance()).containsKey(key);
  }
}