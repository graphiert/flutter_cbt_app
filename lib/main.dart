import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:webview_flutter/webview_flutter.dart';

import 'package:kiosk_mode/kiosk_mode.dart';

import 'package:flutter_windowmanager/flutter_windowmanager.dart';

void main() {
  runApp(MaterialApp(
    title: "Web App",
    theme: ThemeData(primarySwatch: Colors.lightGreen),
    home: const HomePageWeb(),
  ));
}

class HomePageWeb extends StatefulWidget {
  const HomePageWeb({super.key});

  @override
  State<HomePageWeb> createState() => _HomePageWebState();
}

class _HomePageWebState extends State<HomePageWeb> {
  final openPage = 'https://graphiert.blue/';
  late final Stream<KioskMode> currentMode = watchKioskMode();
  double progress = 0;
  late WebViewController webCtr;

  @override
  void initState() {
    super.initState();
    webCtr = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              this.progress = progress / 100;
            });
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onHttpError: (HttpResponseError error) {
            final errCode = error.response?.statusCode;
            if (errCode == 404) webCtr.loadFlutterAsset("assets/404.html");
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("HTTP error with code $errCode. Ignore this message if page works normally."),
              duration: const Duration(seconds: 15),
              action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              )));
          },
          onWebResourceError: (WebResourceError error) {
            webCtr.loadFlutterAsset("assets/404.html");
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(error.description),
              duration: const Duration(seconds: 15),
              action: SnackBarAction(
                label: "Dismiss",
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ));
          },
          onNavigationRequest: (NavigationRequest request) {
            //  if (request.url.startsWith('https://www.youtube.com/')) {
            //    return NavigationDecision.prevent;
            //  }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..clearCache()
      ..loadRequest(Uri.parse(openPage));
    startKioskMode();
    FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<KioskMode>(
        stream: currentMode,
        builder: (context, snapshot) {
          final mode = snapshot.data;
          if (mode == null || mode == KioskMode.disabled) {
            webCtr.clearCache();
            WebViewCookieManager().clearCookies();
            return const Scaffold(
              body: Center(
                child: Text(
                    "Kiosk Mode disabled. Reopen the app, then try again."),
              ),
            );
          }
          return PopScope(
              canPop: false,
              child: Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () async {
                        await showDialog(
                            context: context,
                            builder: (builder) {
                              return AlertDialog(
                                title: const Text("Exit"),
                                content: const Text("Are you sure to exit?"),
                                actions: [
                                  TextButton(
                                    child: const Text("No"),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  TextButton(
                                      child: const Text("Yes"),
                                      onPressed: () async {
                                        await webCtr.clearCache();
                                        await WebViewCookieManager()
                                            .clearCookies();
                                        await stopKioskMode();
                                        Platform.isIOS
                                            ? exit(0)
                                            : SystemChannels.platform
                                                .invokeMethod(
                                                    'SystemNavigator.pop');
                                      })
                                ],
                              );
                            });
                      }),
                  actions: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () async {
                          if (await webCtr.canGoBack()) {
                            await webCtr.goBack();
                          }
                        }),
                    IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          await webCtr.currentUrl() == openPage
                              ? await webCtr.reload()
                              : await webCtr.loadRequest(Uri.parse(openPage));
                        }),
                    IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () async {
                          if (await webCtr.canGoForward()) {
                            await webCtr.goForward();
                          }
                        })
                  ],
                ),
                body: Column(children: [
                  LinearProgressIndicator(
                    value: progress,
                    color: Colors.greenAccent,
                    backgroundColor: Colors.grey,
                  ),
                  Expanded(
                    child: WebViewWidget(
                      controller: webCtr,
                    ),
                  )
                ]),
              ),
              onPopInvoked: (didPop) async {
                if (didPop) return;
                if (await webCtr.canGoBack()) {
                  await webCtr.goBack();
                }
              });
        });
  }
}
