import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_view_package/no_internet_page_creator.dart';
import 'package:web_view_package/shared_prefs_checker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class WebViewPage extends StatefulWidget {
  final NoInternetPageCreator noInternetPageCreator;

  /// If we receive this url we force open white app
  /// Example 'https://dev.reallyappd.com'
  final String forceWhiteUrl;

  /// If we want app to force open white app we call this function to
  /// perform an actual navigation
  /// Example:
  ///       Navigator.pushReplacement(
  ///         context,
  ///         PageRouteBuilder(
  ///           pageBuilder: (context, animation1, animation2) =>
  ///           const PreloaderPage(),
  ///           transitionDuration: Duration.zero,
  ///           reverseTransitionDuration: Duration.zero,
  ///         ),
  ///       );
  final Function(BuildContext context) navigateToWhite;

  final String initialUrl;

  const WebViewPage(
      {Key? key,
      required this.noInternetPageCreator,
      required this.forceWhiteUrl,
      required this.navigateToWhite,
      required this.initialUrl})
      : super(key: key);

  static const routeName = '/webview';

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  WebViewController? _webViewController;
  StreamSubscription? subscription;
  bool _isShowingTerms = false; // are we showing terms in widget right now
  bool _needShowTerms = true; // if false we automatically go to white part when reach terms url
  SharedPrefsChecker sharedPrefsChecker = SharedPrefsChecker();

  Future<bool> _onWillPop() async {
    if ((await _webViewController?.canGoBack()) == true) {
      await _webViewController?.goBack();
    } else {
      await _webViewController?.reload();
    }
    return false;
  }

  void _createWebViewController() {
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _webViewController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: _overrideUrlLoading,
        ),
      );

    if (_webViewController?.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      AndroidWebViewController androidWebViewController =
          (_webViewController!.platform as AndroidWebViewController);

      androidWebViewController.setMediaPlaybackRequiresUserGesture(false);

      androidWebViewController.setOnShowFileSelector((params) async {
        //TODO do everything here
        // Control and show your picker
        // and return a list of Uris.
        final ImagePicker picker = ImagePicker();
        final XFile? photo =
            await picker.pickImage(source: ImageSource.gallery);

        return photo?.path != null
            ? [Uri.file(photo!.path).toString()]
            : []; // Uris
      });
    }
    _webViewController?.loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      _needShowTerms = await sharedPrefsChecker.isShowTermsView();
      await SystemChrome.setPreferredOrientations([]);

      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        _showNoWifiDialog();
      } else {
        setState(() {
          _createWebViewController();
        });
      }

      subscription = Connectivity()
          .onConnectivityChanged
          .listen((ConnectivityResult result) {
        if (result == ConnectivityResult.none) {
          _showNoWifiDialog();
        } else {
          if (_webViewController == null) {
            setState(() {
              _createWebViewController();
            });
          }
          SmartDialog.dismiss();
        }
      });
    });
  }

  @override
  dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.transparent,
              body: _webViewController != null
                  ? SafeArea(
                      child: WebViewWidget(controller: _webViewController!),
                    )
                  : const SizedBox(),
            ),
            if (_isShowingTerms)
              Align(
                alignment: Alignment.bottomCenter,
                child: TextButton(
                    onPressed: () {
                      sharedPrefsChecker.setShowTermsView(false);
                      widget.navigateToWhite(context);
                    },
                    child: const Text('Accept')),
              )
          ],
        ),
      ),
    );
  }

  Future<NavigationDecision> _overrideUrlLoading(
      NavigationRequest request) async {
    var url = request.url.toString();

    var uri = Uri.parse(url);

    if (!["http", "https", "file", "chrome", "data", "javascript", "about"]
        .contains(uri.scheme)) {
      if (await canLaunchUrl(uri)) {
        // Launch the App
        await launchUrl(uri);
        // and cancel the request
      }
      _webViewController = null;
      return NavigationDecision.prevent;
    }

    if (url.contains('terms')) {
      if (_needShowTerms) {
        setState(() {
          _isShowingTerms = true;
        });
        return NavigationDecision.navigate;
      } else {
        if (context.mounted) {
          widget.navigateToWhite(context);
        }
        return NavigationDecision.prevent;
      }
    }

    if (url.contains(widget.forceWhiteUrl)) {
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
      if (context.mounted) {
        widget.navigateToWhite(context);
      }
      _webViewController = null;
      return NavigationDecision.prevent;
    } else {
      return NavigationDecision.navigate;
    }
  }

  Future<void> _showNoWifiDialog() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SmartDialog.show<String>(
      builder: (_) => widget.noInternetPageCreator.createNoInternetPage(() {
        SmartDialog.dismiss();
      }),
      animationType: SmartAnimationType.centerFade_otherSlide,
      keepSingle: true,
    );
  }
}
