import 'package:http/http.dart' as http;

class RedirectUrlGetter {
  /// Call this with the URL you read from Firebase. This will follow all
  /// redirects and return you "binom link"
  ///
  /// If result is an empty list you should go to white immediately
  static Future<List<String>> getRedirectChain(
      String url, String forceWhiteUrl) async {
    if (url.contains(forceWhiteUrl)) {
      return [];
    }
    List<String> redirectChain = [url];
    while (true) {
      http.Response response = await http.get(Uri.parse(url));

      // Check the status code of the response
      if (response.statusCode == 301 || response.statusCode == 302) {
        String newUrl = response.headers['location'] ?? '';
        redirectChain.add(newUrl);
        url = newUrl;
      } else {
        break;
      }
    }
    return redirectChain;
  }
}
