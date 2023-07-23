import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';

import '../main.dart';
import '../models/project.dart';
import '../service/services.dart';


class SettingsPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  List<Project>? projectList;
  int? defaultProject;
  bool? ignoreCertificates;
  bool? getVersionNotifications;
  String? versionTag, newestVersionTag;
  late TextEditingController durationTextController;
  bool initialized = false;
  FlutterThemeMode? themeMode;


  void init() {
    durationTextController = TextEditingController();

    VikunjaGlobal.of(context)
        .projectService
        .getAll()
        .then((value) => setState(() => projectList = value));

    VikunjaGlobal.of(context).projectService.getDefaultList().then((value) =>
        setState(
            () => defaultProject = value == null ? null : int.tryParse(value)));

    VikunjaGlobal.of(context).settingsManager.getIgnoreCertificates().then(
        (value) =>
            setState(() => ignoreCertificates = value == "1" ? true : false));

    VikunjaGlobal.of(context).settingsManager.getVersionNotifications().then(
        (value) => setState(
            () => getVersionNotifications = value == "1" ? true : false));

    VikunjaGlobal.of(context)
        .versionChecker
        .getCurrentVersionTag()
        .then((value) => setState(() => versionTag = value));

    VikunjaGlobal.of(context)
        .settingsManager
        .getWorkmanagerDuration()
        .then((value) => setState(() => durationTextController.text = (value.inMinutes.toString())));

    VikunjaGlobal.of(context).settingsManager.getThemeMode().then((value) => setState(() => themeMode = value));

    initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = VikunjaGlobal.of(context).currentUser;

    if (!initialized) init();
    return new Scaffold(
      appBar: AppBar(title: Text("Settings"),),

      body: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: currentUser != null ? Text(currentUser.username) : null,
            accountEmail: currentUser != null ? Text(currentUser.name) : null,
            currentAccountPicture: currentUser == null
                ? null
                : CircleAvatar(
              backgroundImage: NetworkImage(currentUser.avatarUrl(context)),
            ),
            decoration: BoxDecoration(
              image: DecorationImage(
                  image: AssetImage("assets/graphics/hypnotize.png"),
                  repeat: ImageRepeat.repeat,
                  colorFilter: ColorFilter.mode(
                      Theme.of(context).primaryColor, BlendMode.multiply)),
            ),
          ),
          projectList != null
              ? ListTile(
                  title: Text("Default List"),
                  trailing: DropdownButton<int>(
                    items: [
                      DropdownMenuItem(
                        child: Text("None"),
                        value: null,
                      ),
                      ...projectList!
                          .map((e) => DropdownMenuItem(
                              child: Text(e.title), value: e.id))
                          .toList()
                    ],
                    value: defaultProject,
                    onChanged: (int? value) {
                      setState(() => defaultProject = value);
                      VikunjaGlobal.of(context)
                          .listService
                          .setDefaultList(value);
                    },
                  ),
                )
              : ListTile(
                  title: Text("..."),
                ),
          Divider(),
          ListTile(
            title: Text("Theme"),
            trailing: DropdownButton<FlutterThemeMode>(
              items: [
                DropdownMenuItem(
                  child: Text("System"),
                  value: FlutterThemeMode.system,
                ),
                DropdownMenuItem(
                  child: Text("Light"),
                  value: FlutterThemeMode.light,
                ),
                DropdownMenuItem(
                  child: Text("Dark"),
                  value: FlutterThemeMode.dark,
                ),
                DropdownMenuItem(
                  child: Text("Material You Light"),
                  value: FlutterThemeMode.materialYouLight,
                ),
                DropdownMenuItem(
                  child: Text("Material You Dark"),
                  value: FlutterThemeMode.materialYouDark,
                ),
              ],
              value: themeMode,
              onChanged: (FlutterThemeMode? value) {
                VikunjaGlobal.of(context)
                    .settingsManager
                    .setThemeMode(value!);
                setState(() => themeMode = value);
                updateTheme.value = true;
              },
            ),
          ),
          Divider(),
          ignoreCertificates != null
              ? CheckboxListTile(
                  title: Text("Ignore Certificates"),
                  value: ignoreCertificates,
                  onChanged: (value) {
                    setState(() => ignoreCertificates = value);
                    VikunjaGlobal.of(context).client.reload_ignore_certs(value);
                  })
              : ListTile(title: Text("...")),
              Divider(),
              Padding(padding: EdgeInsets.only(left: 15, right: 15),
              child: Row(children: [
                  Flexible(
                      child: TextField(
                    controller: durationTextController,
                    decoration: InputDecoration(
                      labelText: 'Background Refresh Interval (minutes): ',
                      helperText: 'Minimum: 15, Set limit of 0 for no refresh',
                    ),
                  )),
                  TextButton(
                      onPressed: () => VikunjaGlobal.of(context)
                          .settingsManager
                          .setWorkmanagerDuration(Duration(
                              minutes: int.parse(durationTextController.text))).then((value) => VikunjaGlobal.of(context).updateWorkmanagerDuration()),
                      child: Text("Save")),
                ])),
          Divider(),
          getVersionNotifications != null
              ? CheckboxListTile(
                  title: Text("Get Version Notifications"),
                  value: getVersionNotifications,
                  onChanged: (value) {
                    setState(() => getVersionNotifications = value);
                    if (value != null)
                      VikunjaGlobal.of(context)
                          .settingsManager
                          .setVersionNotifications(value);
                  })
              : ListTile(title: Text("...")),
          TextButton(
              onPressed: () async {
                await Permission.notification.isDenied.then((value) {
                  if (value) {
                    Permission.notification.request();
                  }
                });
                VikunjaGlobal.of(context).notifications.sendTestNotification();
              },
              child: Text("Send test notification")),
          TextButton(
              onPressed: () => VikunjaGlobal.of(context)
                  .versionChecker
                  .getLatestVersionTag()
                  .then((value) => setState(() => newestVersionTag = value)),
              child: Text("Check for latest version")),
          Text("Current version: ${versionTag ?? "loading"}"),
          Text(newestVersionTag != null
              ? "Latest version: $newestVersionTag"
              : ""),
          Divider(),
          TextButton(
              onPressed: () => VikunjaGlobal.of(context).logoutUser(context),
              child: Text("Logout")),
        ],
      ),
    );
  }
}
