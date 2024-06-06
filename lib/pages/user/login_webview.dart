import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LoginWithWebView extends StatefulWidget {
  String frontEndUrl;

  LoginWithWebView(this.frontEndUrl);

  @override
  State<StatefulWidget> createState() => LoginWithWebViewState();
}

class LoginWithWebViewState extends State<LoginWithWebView> {
  WebViewWidget? webView;
  late WebViewController webViewController;
  bool destroyed = false;

  @override
  void initState() {
    super.initState();
    webViewController = WebViewController()
      ..clearLocalStorage()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          "Mozilla/5.0 (Linux; Android 8.0; Pixel 2 Build/OPD3.170816.012) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Mobile Safari/537.36")
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (value) => _handlePageFinished(value),
      ))
      ..loadRequest(Uri.parse(widget.frontEndUrl)).then((value) => {
            webViewController.runJavaScript(
                "localStorage.clear(); location.href=location.href;")
          });

    /*
    webView = WebViewWidget(
      initialUrl: widget.frontEndUrl,
      javascriptMode: JavascriptMode.unrestricted,
      onPageFinished: (value) => _handlePageFinished(value),
      userAgent: "Mozilla/5.0 (Linux; Android 8.0; Pixel 2 Build/OPD3.170816.012) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Mobile Safari/537.36",
      onWebViewCreated: (controller) {
        webViewController = controller;
        webViewController!.runJavaScript("localStorage.clear(); location.href=location.href;");
        },
    );
    */
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
          appBar: AppBar(),
          body: WebViewWidget(
            controller: webViewController,
          )),
      onWillPop: () async {
        String? currentUrl = await webViewController.currentUrl();
        if (currentUrl != null) {
          bool hasPopped = await _handlePageFinished(currentUrl);
          return Future.value(!hasPopped);
        }
        return Future.value(false);
      },
    );
  }

  Future<bool> _handlePageFinished(String pageLocation) async {
    log("handlePageFinished");
    String localStorage = (await webViewController
            .runJavaScriptReturningResult("JSON.stringify(localStorage);"))
        .toString();

    String apiUrl =
        (await webViewController.runJavaScriptReturningResult("API_URL"))
            .toString();
    String token = (await webViewController
            .runJavaScriptReturningResult("localStorage['token']"))
        .toString();
    if (localStorage.toString() != "{}") {
      apiUrl = apiUrl.replaceAll("\"", "");
      token = token.replaceAll("\"", "");
      if (!apiUrl.startsWith("http")) {
        if (pageLocation.endsWith("/"))
          pageLocation = pageLocation.substring(0, pageLocation.length - 1);
        apiUrl = pageLocation + apiUrl;
      }

      if (apiUrl != "null" && token != "null") {
        BaseTokenPair baseTokenPair = BaseTokenPair(apiUrl, token);
        if (destroyed) return true;
        destroyed = true;
        print("pop now");
        Navigator.pop(context, baseTokenPair);

        return true;
      }
    }
    return false;
  }
}
