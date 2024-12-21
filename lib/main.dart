// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:webview_flutter/webview_flutter.dart';
import 'pull_to_refresh.dart';

import 'package:kiosk_mode/kiosk_mode.dart';

import 'package:flutter_windowmanager/flutter_windowmanager.dart';

void main() {
  runApp(MaterialApp(
    title: "SMAN 1 Gubug CBT App",
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
            //
          },
          onWebResourceError: (WebResourceError error) {
            if (error.description == "net::ERR_INTERNET_DISCONNECTED" ||
                error.description == "net::ERR_ADDRESS_UNREACHABLE" ||
                error.description == "net::ERR_CONNECTION_ABORTED") {
              webCtr.loadFlutterAsset("assets/404.html");
            }
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(error.description),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: "Dismiss",
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ));
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
    dragGesturePullToRefresh
        .setController(webCtr)
        .setDragHeightEnd(600)
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
              appBar: AppBar(title: const Text("SMAN 1 Gubug CBT App")),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                        "Untuk membuka halaman, mohon untuk memasang pin pada aplikasi."),
                    const SizedBox(height: 5),
                    const Text("Atau, buka Kiosk Mode melalui tombol dibawah ini 👇."),
                    const SizedBox(height: 10),
                    ElevatedButton(
                        onPressed: () {
                          startKioskMode();
                          FlutterWindowManager.addFlags(
                              FlutterWindowManager.FLAG_SECURE);
                        },
                        child: const Text("Masuki Kiosk Mode"))
                  ],
                ),
              ),
            );
          }
          return PopScope(
              canPop: false,
              child: Scaffold(
                appBar: AppBar(title: const Text("SMAN 1 Gubug CBT App")),
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
                                  FlutterWindowManager.clearFlags(
                                      FlutterWindowManager.FLAG_SECURE);
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
