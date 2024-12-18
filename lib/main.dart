import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:webview_flutter/webview_flutter.dart';
import 'pull_to_refresh.dart';

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
  final openPage = 'http://192.168.0.201/cbt/';
  // final openPage = "https://youtube.com/";
  late final Stream<KioskMode> currentMode = watchKioskMode();
  double progress = 0;
  late WebViewController webCtr;
  late DragGesturePullToRefresh dragGesturePullToRefresh;

  @override
  void initState() {
    super.initState();
    dragGesturePullToRefresh = DragGesturePullToRefresh();
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
          onPageStarted: (String url) {
            dragGesturePullToRefresh.started();
          },
          onPageFinished: (String url) {
            dragGesturePullToRefresh.finished();
          },
          onHttpError: (HttpResponseError error) {
            // final errCode = error.response?.statusCode;
            // if (errCode == 404) webCtr.loadFlutterAsset("assets/404.html");
            // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            //     content: Text(
            //         "HTTP error with code $errCode. Ignore this message if page works normally."),
            //     duration: const Duration(seconds: 15),
            //     action: SnackBarAction(
            //       label: 'Dismiss',
            //       onPressed: () =>
            //           ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            //     )));
          },
          onWebResourceError: (WebResourceError error) {
            // webCtr.loadFlutterAsset("assets/404.html");
            // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            //  content: Text(error.description),
            //  duration: const Duration(seconds: 15),
            //  action: SnackBarAction(
            //    label: "Dismiss",
            //    onPressed: () =>
            //        ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            //  ),
            //));
            dragGesturePullToRefresh.finished();
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
    dragGesturePullToRefresh
        .setController(webCtr)
        .setDragHeightEnd(200)
        .setDragStartYDiff(10)
        .setWaitToRestart(3000);
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
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                        "Kiosk Mode disabled. Start again the Kiosk Mode to open."),
                    const SizedBox(height: 10,),
                    ElevatedButton(
                        onPressed: () {
                          startKioskMode();
                        },
                        child: const Text("Start Kiosk Mode"))
                  ],
                ),
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
                                        Navigator.pop(context);
                                      })
                                ],
                              );
                            });
                      }),
                  // actions: [
                  //   IconButton(
                  //       icon: const Icon(Icons.arrow_back),
                  //       onPressed: () async {
                  //         if (await webCtr.canGoBack()) {
                  //           await webCtr.goBack();
                  //         }
                  //       }),
                  //   IconButton(
                  //       icon: const Icon(Icons.refresh),
                  //       onPressed: () async {
                  //         await webCtr.currentUrl() == openPage
                  //             ? await webCtr.reload()
                  //             : await webCtr.loadRequest(Uri.parse(openPage));
                  //       }),
                  //   IconButton(
                  //       icon: const Icon(Icons.arrow_forward),
                  //       onPressed: () async {
                  //         if (await webCtr.canGoForward()) {
                  //           await webCtr.goForward();
                  //         }
                  //       })
                  // ],
                ),
                body: Column(children: [
                  LinearProgressIndicator(
                    value: progress,
                    color: Colors.greenAccent,
                    backgroundColor: Colors.grey,
                  ),
                  Expanded(
                      child: RefreshIndicator(
                    onRefresh: dragGesturePullToRefresh.refresh,
                    triggerMode: RefreshIndicatorTriggerMode.onEdge,
                    child: Builder(builder: (context) {
                      dragGesturePullToRefresh.setContext(context);
                      return WebViewWidget(
                          controller: webCtr,
                          gestureRecognizers: {
                            Factory(() => dragGesturePullToRefresh)
                          });
                    }),
                  ))
                ]),
              ),
              onPopInvoked: (didPop) async {
                if (didPop) return;
                if (await webCtr.canGoBack()) {
                  await webCtr.goBack();
                } else {
                  showDialog(
                      // ignore: use_build_context_synchronously
                      context: context,
                      builder: (context) {
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
                                  await WebViewCookieManager().clearCookies();
                                  await stopKioskMode();
                                  Navigator.pop(context);
                                })
                          ],
                        );
                      });
                }
              });
        });
  }
}
