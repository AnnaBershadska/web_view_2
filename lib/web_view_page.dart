import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_view_package/no_internet_page_creator.dart';
import 'package:web_view_package/shared_prefs_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

const List<String> allowedSchemes = [
  "http",
  "https",
  "file",
  "chrome",
  "data",
  "javascript",
  "about"
];

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

  const WebViewPage(
      {Key? key,
      required this.noInternetPageCreator,
      required this.forceWhiteUrl,
      required this.navigateToWhite})
      : super(key: key);

  static const routeName = '/webview';

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  WebViewController? _webViewController;
  StreamSubscription? subscription;
  String? _uwr;
  int _loadCounter = 0;
  String _savedRedirectUrl = '';
  String _savedLastUrl = '';

  Future<bool> _onWillPop() async {
    if ((await _webViewController?.canGoBack()) == true) {
      await _webViewController?.goBack();
    } else {
      await _webViewController?.reload();
    }
    return false;
  }

  void _createWebViewController(String url) {
    if (context.mounted && url == widget.forceWhiteUrl) {
      widget.navigateToWhite(context);
    }
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
    _loadCounter = 0;
    _webViewController?.loadRequest(Uri.parse(url));
  }

  @override
  void initState() {
    super.initState();
    SharedPrefsManager.getRedirectUrl()
        .then((String value) => _savedRedirectUrl = value);
    SharedPrefsManager.getLastUrl()
        .then((String value) => _savedLastUrl = value);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await SystemChrome.setPreferredOrientations([]);

      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        _showNoWifiDialog();
      } else {
        _uwr = context.mounted
            ? ModalRoute.of(context)?.settings.arguments as String
            : '';
        setState(() {
          _createWebViewController(_uwr ?? '');
        });
      }

      subscription = Connectivity()
          .onConnectivityChanged
          .listen((ConnectivityResult result) {
        if (result == ConnectivityResult.none) {
          _showNoWifiDialog();
        } else {
          if (_uwr == null && _webViewController == null) {
            setState(() {
              _uwr = ModalRoute.of(context)?.settings.arguments as String;
              _createWebViewController(_uwr ?? '');
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
          ],
        ),
      ),
    );
  }

  /// Here we will check if binom link matches previous one
  /// and save loaded url as last loaded
  ///
  /// Return:
  /// Url to load further. This can be last loaded url of the previous session
  String _processLastUrl(String url) {
    //one - open initial link
    //two - open redirect link
    if (++_loadCounter == 2) {
      if (_savedRedirectUrl != url || _savedLastUrl.isEmpty) {
        SharedPrefsManager.saveRedirectUrl(url);
        SharedPrefsManager.saveLastUrl('');
        _savedLastUrl = '';
        _savedRedirectUrl = url;
      } else {
        return _savedLastUrl;
      }
    }

    if (_loadCounter > 2) {
      SharedPrefsManager.saveLastUrl(url);
    }
    return url;
  }

  Future<NavigationDecision> _overrideUrlLoading(
      NavigationRequest request) async {
    String url = request.url.toString();

    Uri uri = Uri.parse(_processLastUrl(url));

    if (!allowedSchemes.contains(uri.scheme)) {
      //This is a custom deeplink scheme
      if (await canLaunchUrl(uri)) {
        // Launch the target app
        await launchUrl(uri);
      }
      // and cancel the request
      _webViewController = null;
      return NavigationDecision.prevent;
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
        if (_uwr == null) {
          setState(() {
            _uwr = ModalRoute.of(context)?.settings.arguments as String;
          });
        }
        SmartDialog.dismiss();
      }),
      animationType: SmartAnimationType.centerFade_otherSlide,
      keepSingle: true,
    );
  }
}
