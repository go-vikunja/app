import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/user_implementation.dart';
import 'package:vikunja_app/constants.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/pages/user/login_webview.dart';
import 'package:vikunja_app/pages/user/register.dart';
import 'package:vikunja_app/service/services.dart';
import 'package:vikunja_app/theme/button.dart';
import 'package:vikunja_app/theme/buttonText.dart';
import 'package:vikunja_app/theme/constants.dart';
import 'package:vikunja_app/utils/validator.dart';

import '../../models/server.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _rememberMe = false;
  bool init = false;
  List<String> pastServers = [];
  int amountTaps = 0;
  DateTime? lastTap;
  bool _showXClientTokent = false;

  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _xClientTokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      if (VikunjaGlobal.of(context).expired) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Login has expired. Please reenter your details!")));
        setState(() {
          _serverController.text = VikunjaGlobal.of(context).client.base;
          _usernameController.text =
              VikunjaGlobal.of(context).currentUser?.username ?? "";
        });
      }
      final client = VikunjaGlobal.of(context).client;
      await VikunjaGlobal.of(context)
          .settingsManager
          .getIgnoreCertificates()
          .then((value) =>
              setState(() => client.ignoreCertificates = value == "1"));

      await VikunjaGlobal.of(context)
          .settingsManager
          .getPastServers()
          .then((value) {
        print(value);
        if (value != null) setState(() => pastServers = value);
      });
    });
  }

  @override
  Widget build(BuildContext ctx) {
    Client client = VikunjaGlobal.of(context).client;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Builder(
            builder: (BuildContext context) => Form(
              autovalidateMode: AutovalidateMode.always,
              key: _formKey,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: GestureDetector(
                        onTap: _handleLogoTap,
                        child: Image(
                          image: Theme.of(context).brightness == Brightness.dark
                              ? AssetImage('assets/vikunja_logo_full_white.png')
                              : AssetImage('assets/vikunja_logo_full.png'),
                          height: 80.0,
                          semanticLabel: 'Vikunja Logo',
                        ),
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: Row(children: [
                        Expanded(
                          child: TypeAheadField(
                            controller: _serverController,
                            builder: (context, controller, focusnode) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusnode,
                                enabled: !_loading,
                                validator: (address) {
                                  return (isUrl(address) ||
                                          address != null ||
                                          address!.isEmpty)
                                      ? null
                                      : 'Invalid URL';
                                },
                                decoration: new InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Server Address'),
                              );
                            },
                            onSelected: (suggestion) {
                              _serverController.text = suggestion;
                              setState(
                                  () => _serverController.text = suggestion);
                            },
                            itemBuilder:
                                (BuildContext context, Object? itemData) {
                              return Card(
                                  child: Container(
                                      padding: EdgeInsets.all(10),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(itemData.toString()),
                                          IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  pastServers.remove(
                                                      itemData.toString());
                                                  //_serverSuggestionController.suggestionsBox?.close();
                                                  VikunjaGlobal.of(context)
                                                      .settingsManager
                                                      .setPastServers(
                                                          pastServers);
                                                });
                                              },
                                              icon: Icon(Icons.clear))
                                        ],
                                      )));
                            },
                            suggestionsCallback: (String pattern) {
                              List<String> matches = <String>[];
                              matches.addAll(pastServers);
                              matches.retainWhere((s) {
                                return s
                                    .toLowerCase()
                                    .contains(pattern.toLowerCase());
                              });
                              return matches;
                            },
                          ),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
                        enabled: !_loading,
                        controller: _usernameController,
                        autofillHints: [AutofillHints.username],
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Username'),
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
                        enabled: !_loading,
                        controller: _passwordController,
                        autofillHints: [AutofillHints.password],
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Password'),
                        obscureText: true,
                      ),
                    ),
                    if (_showXClientTokent)
                      Padding(
                        padding: vStandardVerticalPadding,
                        child: TextFormField(
                          enabled: !_loading,
                          controller: _xClientTokenController,
                          decoration: new InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'X-Client-Token'),
                        ),
                      ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: CheckboxListTile(
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value ?? false),
                        title: Text("Remember me"),
                      ),
                    ),
                    Builder(
                        builder: (context) => FancyButton(
                              onPressed: !_loading ? _doLogin(context) : null,
                              child: _loading
                                  ? CircularProgressIndicator()
                                  : VikunjaButtonText('Login'),
                            )),
                    Builder(
                        builder: (context) => FancyButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => RegisterPage())),
                              child: VikunjaButtonText('Register'),
                            )),
                    Builder(
                      builder: (context) => FancyButton(
                        onPressed: _loginWithFrontend,
                        child: VikunjaButtonText("Login with Frontend"),
                      ),
                    ),
                    CheckboxListTile(
                        title: Text("Ignore Certificates"),
                        value: client.ignoreCertificates,
                        onChanged: (value) {
                          setState(
                              () => client.reloadIgnoreCerts(value ?? false));
                          VikunjaGlobal.of(context)
                              .settingsManager
                              .setIgnoreCertificates(value ?? false);
                          VikunjaGlobal.of(context).client.ignoreCertificates =
                              value ?? false;
                        })
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _doLogin(BuildContext context) {
    return () {
      if (_formKey.currentState!.validate()) {
        Form.of(context).save();
        _loginUser(context);
      }
    };
  }

  _loginWithFrontend() {
    if (_formKey.currentState!.validate() &&
        _serverController.text.isNotEmpty) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  LoginWithWebView(_serverController.text))).then((btp) {
        if (btp != null) _loginUserByClientToken(btp);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter your frontend url"),
        ),
      );
    }
  }

  _loginUser(BuildContext context) async {
    String _server = _serverController.text;
    String _username = _usernameController.text;
    String _password = _passwordController.text;
    String _xClientToken = _xClientTokenController.text;

    if (_server.isEmpty) return;
    if (!pastServers.contains(_server)) pastServers.add(_server);
    await VikunjaGlobal.of(context).settingsManager.setPastServers(pastServers);

    setState(() => _loading = true);
    try {
      var vGlobal = VikunjaGlobal.of(context);
      vGlobal.client.showSnackBar = false;
      vGlobal.client.configure(base: _server, xClientToken: _xClientToken);
      Server? info = await vGlobal.serverService.getInfo();
      if (info == null) throw Exception("Getting server info failed");

      UserTokenPair newUser;

      Client client = Client(
        vGlobal.snackbarKey,
        base: _server,
        xClientToken: _xClientToken,
      );
      UserService userService = UserAPIService(client);
      newUser = await userService.login(
        _username,
        _password,
        rememberMe: this._rememberMe,
        xClientToken: _xClientToken,
      );

      if (newUser.error == ErrorCodeOtpRequired) {
        TextEditingController totpController = TextEditingController();
        bool dismissed = true;
        await showDialog(
          context: context,
          builder: (context) => new AlertDialog(
            title: Text("Enter One Time Passcode"),
            content: TextField(
              controller: totpController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    dismissed = false;
                    Navigator.pop(context);
                  },
                  child: Text("Login"))
            ],
          ),
        );
        if (!dismissed) {
          newUser = await userService.login(
            _username,
            _password,
            rememberMe: this._rememberMe,
            totp: totpController.text,
          );
        } else {
          throw Exception();
        }
      }
      if (newUser.error > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newUser.errorString),
          ),
        );
      }

      if (newUser.error == 0)
        vGlobal.changeUser(
          newUser.user!,
          token: newUser.token,
          base: _server,
          xClientToken: _xClientToken,
        );
    } catch (ex) {
      print(ex);
    } finally {
      VikunjaGlobal.of(context).client.showSnackBar = true;
      setState(() {
        _loading = false;
      });
    }
  }

  _loginUserByClientToken(BaseTokenPair baseTokenPair) async {
    VikunjaGlobalState vGS = VikunjaGlobal.of(context);

    vGS.client.configure(
        token: baseTokenPair.token,
        base: baseTokenPair.base,
        authenticated: true);
    setState(() => _loading = true);
    try {
      var newUser = await vGS.newUserService?.getCurrentUser();
      if (newUser != null)
        vGS.changeUser(newUser,
            token: baseTokenPair.token, base: baseTokenPair.base);
    } catch (e) {
      log("failed to change to user by client token");
      log(e.toString());
    }
    setState(() => _loading = false);
  }

  void _handleLogoTap() {
    if (lastTap != null &&
        DateTime.now().difference(lastTap!) < Duration(seconds: 2)) {
      amountTaps++;
    } else {
      amountTaps = 1;
    }
    lastTap = DateTime.now();
    if (amountTaps == 5) {
      // Show X-Client-Token field
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "X-Client-Token " + (_showXClientTokent ? "hidden" : "shown"),
          ),
        ),
      );
      setState(() {
        _showXClientTokent = !_showXClientTokent;
      });
      amountTaps = 0;
      lastTap = null;
    }
  }
}
