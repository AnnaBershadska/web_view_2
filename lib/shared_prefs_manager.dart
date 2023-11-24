import 'package:shared_preferences/shared_preferences.dart';

const String REDIRECT_URL_KEY = 'redirect_url';
const String LAST_URL_KEY = 'last_url';

class SharedPrefsManager {
  static Future<void> saveRedirectUrl(String url) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(REDIRECT_URL_KEY, url);
  }

  static Future<String> getRedirectUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(REDIRECT_URL_KEY) ?? '';
  }

  static Future<void> saveLastUrl(String url) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(LAST_URL_KEY, url);
  }

  static Future<String> getLastUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(LAST_URL_KEY) ?? '';
  }
}