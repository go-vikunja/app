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
      onWebViewCreated: (controller) => webViewController = controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: webView
    );
  }

  void _handlePageFinished(String value) {
    log("handlePageFinished");
    if(webView != null)
      webViewController.runJavascriptReturningResult("JSON.stringify(localStorage);").then((value) {
        if(value != "null") {
          value = value.replaceAll("\\", "");
          value = value.substring(1,value.length-1);
          var json =  jsonDecode(value);
        if (json["API_URL"] != null && json["token"] != null) {
          Client client = Client(json["token"], json["API_URL"]);
          Navigator.pop(context, client);
        }
      }
    });
  }

}