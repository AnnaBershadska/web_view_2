import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

abstract class NoInternetPageCreator {
  NoInternetPageCreator();

  /// Create a widget that will be showin in No internet dialog. It must have onTap parameter for
  /// ok button. Use onTap function from this class for that button
  Widget createNoInternetPage(final VoidCallback onConnectedCallback);

  void onTap(final VoidCallback onConnectedCallback) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult != ConnectivityResult.none) {
      onConnectedCallback();
      // SmartDialog.dismiss();
      await SystemChrome.setPreferredOrientations([]);
    }
  }
}
