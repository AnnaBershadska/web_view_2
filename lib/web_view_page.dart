import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_view_package/no_internet_page_creator.dart';
import 'package:web_view_package/redirect_url_getter.dart';
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

  /// This is url read from Firebase
  final String initialUrl;

  const WebViewPage(
      {super.key,
      required this.noInternetPageCreator,
      required this.forceWhiteUrl,
      required this.navigateToWhite,
      required this.initialUrl});

  static const routeName = '/webview';

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  WebViewController? _webViewController;
  StreamSubscription? subscription;
  bool? _targetRedirectReached;
  String _savedRedirectUrl = '';
  String _savedLastUrl = '';
  final SharedPrefsManager _sharedPrefsManager = SharedPrefsManager();
  String _targetRedirectUrl = '';

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
    _webViewController?.loadRequest(Uri.parse(url));
  }

  @override
  void initState() {
    super.initState();
    _sharedPrefsManager.init().then((value) {
      _savedRedirectUrl = _sharedPrefsManager.getRedirectUrl();
      _savedLastUrl = _sharedPrefsManager.getLastUrl();

      //If initial url has changed erase all saved urls. Start from the first page
      if (_savedRedirectUrl != widget.initialUrl) {
        _sharedPrefsManager.saveRedirectUrl(widget.initialUrl);
        _sharedPrefsManager.saveLastUrl('');
        _savedLastUrl = '';
        _savedRedirectUrl = widget.initialUrl;
      }
    });
    RedirectUrlGetter.getRedirectUrl(widget.initialUrl)
        .then((String value) => _targetRedirectUrl = value);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await SystemChrome.setPreferredOrientations([]);

      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        _showNoWifiDialog();
      } else {
        setState(() {
          _createWebViewController(widget.initialUrl);
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
              _createWebViewController(widget.initialUrl);
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
    //one - open initial link casinomate.xxxx
    //two - open redirect link slotking.xxx
    // switch (++_loadCounter) {
    //   case 1:
    //     if (_savedRedirectUrl != url) {
    //       _sharedPrefsManager.saveRedirectUrl(url);
    //       _sharedPrefsManager.saveLastUrl('');
    //       _savedLastUrl = '';
    //       _savedRedirectUrl = url;
    //     }
    //     break;
    //
    //   case 2:
    //     if (_savedLastUrl.isNotEmpty) {
    //       return _savedLastUrl;
    //     }
    //     break;
    //   default:
    //     _webViewController?.currentUrl().then((String? value) {
    //       _sharedPrefsManager.saveLastUrl(value ?? '');
    //     });
    // }

    if (_targetRedirectReached == null) {
      //Check if all redirects processed
      _targetRedirectReached ??= url == _targetRedirectUrl;
      if (_savedLastUrl.isNotEmpty) {
        //Check if we have usr saved from the last session
        return _savedLastUrl;
      }
    } else {
      //Save current url as last url
      _webViewController?.currentUrl().then((String? value) {
        _sharedPrefsManager.saveLastUrl(value ?? '');
      });
    }

    return url;
  }

  Future<NavigationDecision> _overrideUrlLoading(
      NavigationRequest request) async {
    String initialUrl = request.url.toString();
    String processedUrl = _processLastUrl(initialUrl);
    Uri uri = Uri.parse(processedUrl);
    if (processedUrl != initialUrl) {
      _webViewController?.loadRequest(uri);
      return NavigationDecision.prevent;
    }

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

    if (processedUrl.contains(widget.forceWhiteUrl)) {
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
