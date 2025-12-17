import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const HekalApp());
}

class HekalApp extends StatelessWidget {
  const HekalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mr heikal',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _webViewController;
  double _loadingProgress = 0.0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasLoadedSuccessfully = false;
  final String _initialUrl = 'https://mr-heikal.anmka.com/student-login/';

  @override
  void initState() {
    super.initState();
    _initializeWebViewController();
    _initializeScreenProtector();
  }

  void _initializeWebViewController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('🚀 Page started loading: $url');
            debugPrint('📋 Request headers: X-App-Source: anmka');
            if (mounted) {
              setState(() {
                _loadingProgress = 0.0;
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (url) {
            debugPrint('✅ Page finished loading: $url');
            if (mounted) {
              setState(() {
                _loadingProgress = 1.0;
                _isLoading = false;
                _hasLoadedSuccessfully = true;
                _errorMessage = null;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint('❌ WebView Error: ${error.description}');
            if (!_hasLoadedSuccessfully) {
              if (mounted) {
                setState(() {
                  _errorMessage = 'خطأ في تحميل الصفحة: ${error.description}';
                  _isLoading = false;
                });
              }
            }
          },
          onNavigationRequest: (request) async {
            final url = request.url;
            debugPrint('🧭 Navigation request: $url');

            // Handle Android Intent URLs specially
            if (url.startsWith('intent://')) {
              try {
                // Parse the intent URL to extract the actual scheme and package
                // Format: intent://...#Intent;scheme=SCHEME;package=PACKAGE;end
                final intentMatch = RegExp(
                  r'intent://(.+)#Intent;scheme=([^;]+);package=([^;]+);end',
                ).firstMatch(url);

                if (intentMatch != null) {
                  final scheme = intentMatch.group(2);
                  final packageName = intentMatch.group(3);
                  final path = intentMatch.group(1);

                  // Try the app-specific scheme first (e.g., fb-messenger://)
                  final appUrl = '$scheme://$path';
                  debugPrint('🔄 Trying app URL: $appUrl');

                  try {
                    final uri = Uri.parse(appUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      debugPrint('✅ Opened with app scheme: $appUrl');
                      return NavigationDecision.prevent;
                    }
                  } catch (e) {
                    debugPrint('⚠️ App scheme failed, trying package: $e');
                  }

                  // If app scheme fails, try opening the package directly
                  final marketUrl = 'market://details?id=$packageName';
                  try {
                    final uri = Uri.parse(marketUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      debugPrint('✅ Opened Play Store for: $packageName');
                    }
                  } catch (e) {
                    debugPrint('❌ Could not open app or Play Store: $e');
                  }
                }
              } catch (e) {
                debugPrint('❌ Error parsing intent URL: $e');
              }
              return NavigationDecision.prevent;
            }

            // Check if it's a file download (APK, PDF, etc.)
            if (url.toLowerCase().endsWith('.apk') ||
                url.toLowerCase().endsWith('.pdf') ||
                url.toLowerCase().endsWith('.zip') ||
                url.toLowerCase().endsWith('.rar') ||
                url.toLowerCase().endsWith('.doc') ||
                url.toLowerCase().endsWith('.docx') ||
                url.toLowerCase().endsWith('.xls') ||
                url.toLowerCase().endsWith('.xlsx')) {
              debugPrint('📁 File download detected: $url');
              try {
                final uri = Uri.parse(url);

                // For APK files, try different launch modes
                if (url.toLowerCase().endsWith('.apk')) {
                  debugPrint('📱 APK file detected, trying download...');

                  // Try with external application mode first
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    debugPrint(
                      '✅ APK download started with external app mode: $url',
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم بدء تحميل التطبيق'),
                          duration: Duration(seconds: 3),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    return NavigationDecision.prevent;
                  } catch (e) {
                    debugPrint('⚠️ External app mode failed: $e');
                  }

                  // Try with platform default mode
                  try {
                    await launchUrl(uri, mode: LaunchMode.platformDefault);
                    debugPrint(
                      '✅ APK download started with platform default: $url',
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم بدء تحميل التطبيق'),
                          duration: Duration(seconds: 3),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    return NavigationDecision.prevent;
                  } catch (e) {
                    debugPrint('⚠️ Platform default mode failed: $e');
                  }

                  // If both fail, show error
                  debugPrint('❌ Cannot download APK file: $url');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'لا يمكن تحميل التطبيق. تأكد من وجود متصفح يدعم التحميل',
                        ),
                        duration: Duration(seconds: 5),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  // For other file types, use the original logic
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                    debugPrint('✅ File download started: $url');

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم بدء تحميل الملف'),
                          duration: Duration(seconds: 3),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    debugPrint('❌ Cannot download file: $url');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا يمكن تحميل الملف'),
                          duration: Duration(seconds: 3),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              } catch (e) {
                debugPrint('❌ Error downloading file: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في تحميل الملف: $e'),
                      duration: const Duration(seconds: 3),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
              return NavigationDecision.prevent;
            }

            // Check if it's an external URL scheme (WhatsApp, tel, mailto, etc.)
            if (url.startsWith('whatsapp://') ||
                url.startsWith('tel:') ||
                url.startsWith('mailto:') ||
                url.startsWith('sms:') ||
                url.startsWith('fb://') ||
                url.startsWith('fb-messenger://') ||
                url.startsWith('instagram://') ||
                url.startsWith('twitter://') ||
                url.startsWith('tg://')) {
              // Try to launch the external app
              try {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  debugPrint('✅ Opened external app: $url');
                } else {
                  debugPrint('❌ Cannot launch: $url');
                }
              } catch (e) {
                debugPrint('❌ Error launching URL: $e');
              }
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
      )
      ..setOnConsoleMessage((message) {
        debugPrint('🌐 Console: ${message.message}');
      })
      ..loadRequest(
        Uri.parse(_initialUrl),
        headers: {
          'X-App-Source': 'anmka', // <-- الهيدر اللي بيتأكد منه السيرفر
        },
      );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setOnShowFileSelector((params) async {
          debugPrint('📁 File selector: ${params.acceptTypes}');
          return [];
        });
    }

    _webViewController = controller;

    // Print header when app opens
    debugPrint('🔧 WebView initialized');
    debugPrint('📋 Headers being sent: X-App-Source: anmka');
    debugPrint('🌐 Loading URL: $_initialUrl');
    debugPrint('🎬 Media playback enabled');
  }

  /// Initialize screen protection on Android/iOS
  Future<void> _initializeScreenProtector() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('🛡️ Enabling Android screen protection...');
        await ScreenProtector.protectDataLeakageOn();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('🛡️ Enabling iOS screenshot prevention...');
        await ScreenProtector.preventScreenshotOn();
      }
    } catch (e) {
      debugPrint('❌ ScreenProtector init error: $e');
    }
  }

  void _refreshWebView() {
    debugPrint('🔄 Refreshing WebView...');
    if (mounted) {
      setState(() {
        _loadingProgress = 0.0;
        _isLoading = true;
        _errorMessage = null;
        _hasLoadedSuccessfully = false;
      });
    }
    _webViewController.reload();
  }

  @override
  void dispose() {
    // Disable screen protection when leaving
    if (defaultTargetPlatform == TargetPlatform.android) {
      ScreenProtector.protectDataLeakageOff();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      ScreenProtector.preventScreenshotOff();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshWebView();
          },
          child: Stack(
            children: [
              WebViewWidget(controller: _webViewController),
              if (_isLoading && _loadingProgress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadingProgress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue[700]!,
                    ),
                    minHeight: 3,
                  ),
                ),
              if (_errorMessage != null && !_isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _refreshWebView,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
