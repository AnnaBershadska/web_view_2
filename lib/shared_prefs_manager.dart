import 'package:shared_preferences/shared_preferences.dart';

const String REDIRECT_URL_KEY = 'redirect_url';
const String LAST_URL_KEY = 'last_url';

class SharedPrefsManager {
  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveRedirectUrl(String url) async {
    if (url != getLastUrl()) { //only update if changed
      await _prefs.setString(REDIRECT_URL_KEY, url);
    }
  }

  String getRedirectUrl() {
    return _prefs.getString(REDIRECT_URL_KEY) ?? '';
  }

  Future<void> saveLastUrl(String url) async {
    await _prefs.setString(LAST_URL_KEY, url);
  }

  String getLastUrl() {
    return _prefs.getString(LAST_URL_KEY) ?? '';
  }
}
