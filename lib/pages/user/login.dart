import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/user_implementation.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/pages/user/login_webview.dart';
import 'package:vikunja_app/pages/user/register.dart';
import 'package:vikunja_app/theme/button.dart';
import 'package:vikunja_app/theme/buttonText.dart';
import 'package:vikunja_app/theme/constants.dart';
import 'package:vikunja_app/utils/validator.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/server.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _rememberMe = false;
  bool ignoreCertificates;

  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
      Future.delayed(Duration.zero, () {
        if(VikunjaGlobal.of(context).expired) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
              SnackBar(
                  content: Text(
                      "Login has expired. Please reenter your details!")));
          setState(() {
            _serverController.text = VikunjaGlobal.of(context)?.client?.base;
            _usernameController.text = VikunjaGlobal.of(context)?.currentUser?.username;
          });
        }
      });
  }



  @override
  Widget build(BuildContext ctx) {
    if(ignoreCertificates == null)
      VikunjaGlobal.of(context).settingsManager.getIgnoreCertificates().then((value) => setState(() => ignoreCertificates = value == "1" ? true:false));

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
                      child: Image(
                        image: Theme.of(context).brightness == Brightness.dark
                            ? AssetImage('assets/vikunja_logo_full_white.png')
                            : AssetImage('assets/vikunja_logo_full.png'),
                        height: 85.0,
                        semanticLabel: 'Vikunja Logo',
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
                        enabled: !_loading,
                        controller: _serverController,
                        autocorrect: false,
                        validator: (address) {
                          return isUrl(address) || address.isEmpty ? null : 'Invalid URL';
                        },
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Server Address'),
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: TextFormField(
                        enabled: !_loading,
                        controller: _usernameController,
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
                        decoration: new InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Password'),
                        obscureText: true,
                      ),
                    ),
                    Padding(
                      padding: vStandardVerticalPadding,
                      child: CheckboxListTile(
                        value: _rememberMe,
                        onChanged: (value) => setState( () =>_rememberMe = value),
                        title: Text("Remember me"),
                      ),
                    ),
                    Builder(
                        builder: (context) => FancyButton(
                              onPressed: !_loading
                                  ? () {
                                      if (_formKey.currentState.validate()) {
                                        Form.of(context).save();
                                        _loginUser(context);
                                      }
                                    }
                                  : null,
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
                    Builder(builder: (context) => FancyButton(
                        onPressed: () {
                          if(_formKey.currentState.validate() && _serverController.text.isNotEmpty) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) =>
                                    LoginWithWebView(_serverController.text))).then((btp) { if(btp != null) _loginUserByClientToken(btp);});
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please enter your frontend url")));
                          }
                        },
                        child: VikunjaButtonText("Login with Frontend"))),
                    ignoreCertificates != null ?
                    CheckboxListTile(title: Text("Ignore Certificates"), value: ignoreCertificates, onChanged: (value) {
                      setState(() => ignoreCertificates = value);
                      VikunjaGlobal.of(context).settingsManager.setIgnoreCertificates(value);
                      VikunjaGlobal.of(context).client.ignoreCertificates = value;
                    }) : ListTile(title: Text("..."))
            ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _loginUser(BuildContext context) async {
    String _server = _serverController.text;
    String _username = _usernameController.text;
    String _password = _passwordController.text;
    if(_server.isEmpty)
      return;
    setState(() => _loading = true);
    try {
      var vGlobal = VikunjaGlobal.of(context);
      if(_server.endsWith("/"))
        _server = _server.substring(0,_server.length-1);
      vGlobal.client.configure(base: _server);
      Server info = await vGlobal.serverService.getInfo();


      UserTokenPair newUser;

      try {
        newUser =
        await vGlobal.newUserService.login(
            _username, _password, rememberMe: this._rememberMe);
      } catch (e) {
        if (e.runtimeType == InvalidRequestApiException && e.errorCode == 412) {
          TextEditingController totpController = TextEditingController();
          await showDialog(context: context, builder: (context) =>
          new AlertDialog(
            title: Text("Enter One Time Passcode"),
            content: TextField(controller: totpController,keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context), child: Text("Login"))
            ],
          ));
          newUser =
          await vGlobal.newUserService.login(
              _username, _password, rememberMe: this._rememberMe,
              totp: totpController.text);
        } else {
          throw e;
        }
    }
      vGlobal.changeUser(newUser.user, token: newUser.token, base: _server);
    } catch (ex) {
      showDialog(
          context: context,
          builder: (context) => new AlertDialog(
                title: Text(
                    'Login failed! Please check your server url and credentials. ' +
                        ex.toString()),
                actions: <Widget>[
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ],
              ));
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  _loginUserByClientToken(BaseTokenPair baseTokenPair) async {
    VikunjaGlobalState vGS = VikunjaGlobal.of(context);

    vGS.client.configure(token: baseTokenPair.token, base: baseTokenPair.base, authenticated: true);
    setState(() => _loading = true);
    try {
      var newUser = await vGS.newUserService.getCurrentUser();
      vGS.changeUser(newUser, token: baseTokenPair.token, base: baseTokenPair.base);
    } catch (e) {
      log(e.toString());
    }
    setState(() => _loading = false);
  }
}
