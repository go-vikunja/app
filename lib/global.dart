import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vikunja_app/api/bucket_implementation.dart';
import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/label_task.dart';
import 'package:vikunja_app/api/label_task_bulk.dart';
import 'package:vikunja_app/api/labels.dart';
import 'package:vikunja_app/api/list_implementation.dart';
import 'package:vikunja_app/api/namespace_implementation.dart';
import 'package:vikunja_app/api/server_implementation.dart';
import 'package:vikunja_app/api/task_implementation.dart';
import 'package:vikunja_app/api/user_implementation.dart';
import 'package:vikunja_app/api/version_check.dart';
import 'package:vikunja_app/managers/notifications.dart';
import 'package:vikunja_app/managers/user.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/service/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'as notifs;


class VikunjaGlobal extends StatefulWidget {
  final Widget child;
  final Widget login;

  VikunjaGlobal({required this.child, required this.login});

  @override
  VikunjaGlobalState createState() => VikunjaGlobalState();

  static VikunjaGlobalState of(BuildContext context) {
    var widget =
        context.dependOnInheritedWidgetOfExactType<_VikunjaGlobalInherited>();
    return widget!.data;
  }
}

class VikunjaGlobalState extends State<VikunjaGlobal> {
  final FlutterSecureStorage _storage = new FlutterSecureStorage();

  User? _currentUser;
  bool _loading = true;
  bool expired = false;
  late Client _client;
  UserService? _newUserService;


  User? get currentUser => _currentUser;

  Client get client => _client;

  final GlobalKey<ScaffoldMessengerState> snackbarKey =
  GlobalKey<ScaffoldMessengerState>();

  UserManager get userManager => new UserManager(_storage);

  UserService? get newUserService => _newUserService;

  ServerService get serverService => new ServerAPIService(client);

  SettingsManager get settingsManager => new SettingsManager(_storage);

  VersionChecker get versionChecker => new VersionChecker(snackbarKey);

  NamespaceService get namespaceService => new NamespaceAPIService(client);

  TaskService get taskService => new TaskAPIService(client);

  BucketService get bucketService => new BucketAPIService(client);

  ListService get listService => new ListAPIService(client, _storage);

  notifs.FlutterLocalNotificationsPlugin get notificationsPlugin => new notifs.FlutterLocalNotificationsPlugin();

  TaskServiceOptions get taskServiceOptions => new TaskServiceOptions();

  NotificationClass get notifications => new NotificationClass();

  notifs.NotificationAppLaunchDetails? notifLaunch;

  LabelService get labelService => new LabelAPIService(client);

  LabelTaskService get labelTaskService => new LabelTaskAPIService(client);

  LabelTaskBulkAPIService get labelTaskBulkService =>
      new LabelTaskBulkAPIService(client);

  var androidSpecificsDueDate = notifs.AndroidNotificationDetails(
      "Vikunja1",
      "Due Date Notifications",
      channelDescription: "description",
      icon: 'vikunja_notification_logo',
      importance: notifs.Importance.high
  );
  var androidSpecificsReminders = notifs.AndroidNotificationDetails(
      "Vikunja2",
      "Reminder Notifications",
      channelDescription: "description",
      icon: 'vikunja_notification_logo',
      importance: notifs.Importance.high
  );
  late notifs.IOSNotificationDetails iOSSpecifics;
  late notifs.NotificationDetails platformChannelSpecificsDueDate;
  late notifs.NotificationDetails platformChannelSpecificsReminders;

  late String currentTimeZone;



  @override
  void initState() {
    super.initState();
    _client = Client(snackbarKey);
    settingsManager.getIgnoreCertificates().then((value) => client.reload_ignore_certs(value == "1"));
    _newUserService = UserAPIService(client);
    _loadCurrentUser();
    tz.initializeTimeZones();
    iOSSpecifics = notifs.IOSNotificationDetails();
    platformChannelSpecificsDueDate = notifs.NotificationDetails(
        android: androidSpecificsDueDate, iOS: iOSSpecifics);
    platformChannelSpecificsReminders = notifs.NotificationDetails(
        android: androidSpecificsReminders, iOS: iOSSpecifics);
    notificationInitializer();
    settingsManager.getVersionNotifications().then((value) {
      if(value == "1") {
        versionChecker.postVersionCheckSnackbar();
      }
    });
  }

  void changeUser(User newUser, {String? token, String? base}) async {
    setState(() {
      _loading = true;
    });
    if (token == null) {
      token = await _storage.read(key: newUser.id.toString());
    } else {
      // Write new token to secure storage
      await _storage.write(key: newUser.id.toString(), value: token);
    }
    if (base == null) {
      base = await _storage.read(key: "${newUser.id.toString()}_base");
    } else {
      // Write new base to secure storage
      await _storage.write(key: "${newUser.id.toString()}_base", value: base);
    }
    // Set current user in storage
    await _storage.write(key: 'currentUser', value: newUser.id.toString());
    client.configure(token: token, base: base, authenticated: true);
    setState(() {
      _currentUser = newUser;
      _loading = false;
    });
  }

  void notificationInitializer() async {
    currentTimeZone = await FlutterTimezone.getLocalTimezone();
    notifLaunch = await notificationsPlugin.getNotificationAppLaunchDetails();
    await notifications.initNotifications(notificationsPlugin);
    requestIOSPermissions(notificationsPlugin);
  }

  Future<void> scheduleDueNotifications() async {
    final tasks = await taskService.getAll();
    if(tasks == null) {
      dev.log("did not receive tasks on notification update");
      return;
    }
    await notificationsPlugin.cancelAll();
    for (final task in tasks) {
      for (final reminder in task.reminderDates) {
        scheduleNotification(
          "Reminder",
          "This is your reminder for '" + task.title + "'",
          notificationsPlugin,
          reminder,
          currentTimeZone,
          platformChannelSpecificsReminders,
          id: (reminder.millisecondsSinceEpoch / 1000).floor(),
        );
      }
      if (task.hasDueDate) {
        scheduleNotification(
          "Due Reminder",
          "The task '" + task.title + "' is due.",
          notificationsPlugin,
          task.dueDate!,
          currentTimeZone,
          platformChannelSpecificsDueDate,
          id: task.id,
        );
      }
    }
  }


  void logoutUser(BuildContext context) {
    _storage.deleteAll().then((_) {
      Navigator.pop(context);
      setState(() {
        client.reset();
        _currentUser = null;
      });
    }).catchError((err) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('An error occured while logging out!'),
      ));
    });
  }

  void _loadCurrentUser() async {
    var currentUser = await _storage.read(key: 'currentUser');
    if (currentUser == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    var token = await _storage.read(key: currentUser);
    var base = await _storage.read(key: '${currentUser}_base');
    if (token == null || base == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    client.configure(token: token, base: base, authenticated: true);
    User loadedCurrentUser;
    try {
      loadedCurrentUser = await UserAPIService(client).getCurrentUser();
    } on ApiException catch (e) {
      dev.log("Error code: " + e.errorCode.toString(),level: 1000);
      if (e.errorCode ~/ 100 == 4) {
        client.authenticated = false;
        if (e.errorCode == 401) {
          // token has expired, but we can reuse username and base. user just has to enter password again
          expired = true;
        }
        setState(() {
          client.authenticated = false;
          _currentUser = null;
          _loading = false;
        });
        return;
      }
      loadedCurrentUser = User(id: int.parse(currentUser), username: '');
    } catch (otherExceptions) {
      loadedCurrentUser = User(id: int.parse(currentUser), username: '');
    }
    setState(() {
      _currentUser = loadedCurrentUser;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return new Center(child: new CircularProgressIndicator());
    }
    if(client.authenticated) {
      scheduleDueNotifications();
    }
    return new _VikunjaGlobalInherited(
      data: this,
      key: UniqueKey(),
      child: !client.authenticated ? widget.login : widget.child,
    );
  }
}

class _VikunjaGlobalInherited extends InheritedWidget {
  final VikunjaGlobalState data;

  _VikunjaGlobalInherited({Key? key, required this.data, required Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(_VikunjaGlobalInherited oldWidget) {
    return (data.currentUser != null &&
            data.currentUser!.id != oldWidget.data.currentUser!.id) ||
        data.client != oldWidget.data.client;
  }
}
