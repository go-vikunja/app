import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/api/client.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LoginWithWebView extends StatefulWidget {
  String frontEndUrl;

  LoginWithWebView(this.frontEndUrl);

  @override
  State<StatefulWidget> createState() => LoginWithWebViewState();
}

class LoginWithWebViewState extends State<LoginWithWebView> {

  WebView webView;
  WebViewController webViewController;

  @override
  void initState() {
    super.initState();
    webView = WebView(
      initialUrl: widget.frontEndUrl,
      javascriptMode: JavascriptMode.unrestricted,
      onPageFinished: (value) => _handlePageFinished(value),
      userAgent: "Mozilla/5.0 (Linux; Android 8.0; Pixel 2 Build/OPD3.170816.012) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Mobile Safari/537.36",
      onWebViewCreated: (controller) {
        webViewController = controller;
        webViewController.runJavascript("localStorage.clear(); location.href=location.href;");
        },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(child: Scaffold(
      appBar: AppBar(),
      body: webView
    ),
    onWillPop: () async {
      bool hasPopped = await _handlePageFinished("");
      return Future.value(!hasPopped);
      },);
  }

  Future<bool> _handlePageFinished(String pageLocation) async {
    log("handlePageFinished");
    if(webViewController != null) {
      String localStorage = await webViewController
          .runJavascriptReturningResult("JSON.stringify(localStorage);");

      String apiUrl = await webViewController.runJavascriptReturningResult("API_URL");
      if (localStorage != "{}") {
        apiUrl = apiUrl.replaceAll("\"", "");
        localStorage = localStorage.replaceAll("\\", "");
        localStorage = localStorage.substring(1, localStorage.length - 1);
        var json = jsonDecode(localStorage);
        if (apiUrl  != "null" && json["token"] != null) {
          BaseTokenPair baseTokenPair = BaseTokenPair(
              apiUrl, json["token"]);
          Navigator.pop(context, baseTokenPair);
          return true;
        }
      }
    }
    return false;
  }

}