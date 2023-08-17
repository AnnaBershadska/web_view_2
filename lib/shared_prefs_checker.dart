import 'package:shared_preferences/shared_preferences.dart';

const String TERMS_KEY = 'show_terms';

class SharedPrefsChecker {
  Future<bool> isShowTermsView() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(TERMS_KEY) ?? true;
  }

  Future<void> setShowTermsView(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TERMS_KEY, value);
  }
}
