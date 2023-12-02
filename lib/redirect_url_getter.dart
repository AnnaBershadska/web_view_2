import 'package:dio/dio.dart';
import 'package:fk_user_agent/fk_user_agent.dart';

class RedirectUrlGetter {
  static Future<String?> _getUserAgent() async {
    await FkUserAgent.init();
    final userAgent = FkUserAgent.userAgent;
    if (userAgent != null) {
      final trimIndex = userAgent.indexOf('(');
      if (trimIndex >= 0) {
        return 'Mozilla/5.0 ${userAgent.substring(trimIndex, userAgent.length)} AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36';
      } else {
        return userAgent;
      }
    }
    return null;
  }

  static Future<String> getRedirectUrl(String initialUrl) async {
    String? userAgent = await _getUserAgent();

    final response = await Dio().get(
      initialUrl,
      options: Options(
        headers: {
          "Accept": "application/json",
          if (userAgent != null) 'User-Agent': userAgent,
        },
        followRedirects: true,
      ),
    );
    if (response.redirects.isNotEmpty) {
      final RedirectRecord location = response.redirects.last;
      return location.location.toString();
    } else {
      return '';
    }
  }
}
