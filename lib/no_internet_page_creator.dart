import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:web_view_package/internet_helper.dart';

abstract class NoInternetPageCreator {
  NoInternetPageCreator();

  /// Create a widget that will be showin in No internet dialog. It must have onTap parameter for
  /// ok button. Use onTap function from this class for that button
  Widget createNoInternetPage(final VoidCallback onConnectedCallback);

  void onTap(final VoidCallback onConnectedCallback) async {
    final hasInternet = await InternetHelper.checkInternetConnection();
    if (hasInternet) {
      onConnectedCallback();
      await SystemChrome.setPreferredOrientations([]);
    }
  }
}
