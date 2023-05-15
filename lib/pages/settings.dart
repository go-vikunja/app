import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';


class SettingsPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  List<TaskList>? taskListList;
  int? defaultList;
  bool? ignoreCertificates;
  bool? getVersionNotifications;
  String? versionTag, newestVersionTag;
  late TextEditingController durationTextController;
  bool initialized = false;

  void init() {
    durationTextController = TextEditingController();

    VikunjaGlobal.of(context)
        .listService
        .getAll()
        .then((value) => setState(() => taskListList = value));

    VikunjaGlobal.of(context).listService.getDefaultList().then((value) =>
        setState(
            () => defaultList = value == null ? null : int.tryParse(value)));

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

    initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = VikunjaGlobal.of(context).currentUser;

    if (!initialized) init();
    return new Scaffold(
      body: Column(
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
          taskListList != null
              ? ListTile(
                  title: Text("Default List"),
                  trailing: DropdownButton<int>(
                    items: [
                      DropdownMenuItem(
                        child: Text("None"),
                        value: null,
                      ),
                      ...taskListList!
                          .map((e) => DropdownMenuItem(
                              child: Text(e.title), value: e.id))
                          .toList()
                    ],
                    value: defaultList,
                    onChanged: (int? value) {
                      setState(() => defaultList = value);
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
