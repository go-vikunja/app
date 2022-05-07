import 'dart:math';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/label_task.dart';
import 'package:vikunja_app/api/label_task_bulk.dart';
import 'package:vikunja_app/api/labels.dart';
import 'package:vikunja_app/api/list_implementation.dart';
import 'package:vikunja_app/api/namespace_implementation.dart';
import 'package:vikunja_app/api/server_implementation.dart';
import 'package:vikunja_app/api/task_implementation.dart';
import 'package:vikunja_app/api/user_implementation.dart';
import 'package:vikunja_app/managers/notifications.dart';
import 'package:vikunja_app/managers/user.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/service/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'as notifs;


class VikunjaGlobal extends StatefulWidget {
  final Widget child;
  final Widget login;

  VikunjaGlobal({this.child, this.login});

  @override
  VikunjaGlobalState createState() => VikunjaGlobalState();

  static VikunjaGlobalState of(BuildContext context) {
    var widget =
        context.dependOnInheritedWidgetOfExactType<_VikunjaGlobalInherited>();
    return widget.data;
  }
}

class VikunjaGlobalState extends State<VikunjaGlobal> {
  final FlutterSecureStorage _storage = new FlutterSecureStorage();

  User _currentUser;
  bool _loading = true;
  bool expired = false;
  Client _client;
  UserService _newUserService;


  User get currentUser => _currentUser;

  Client get client => _client;

  UserManager get userManager => new UserManager(_storage);

  UserService get newUserService => _newUserService;

  ServerService get serverService => new ServerAPIService(client);

  NamespaceService get namespaceService => new NamespaceAPIService(client);

  TaskService get taskService => new TaskAPIService(client);

  ListService get listService => new ListAPIService(client, _storage);

  notifs.FlutterLocalNotificationsPlugin get notificationsPlugin => new notifs.FlutterLocalNotificationsPlugin();

  TaskServiceOptions get taskServiceOptions => new TaskServiceOptions();

  NotificationClass get notifications => new NotificationClass();

  notifs.NotificationAppLaunchDetails notifLaunch;

  LabelService get labelService => new LabelAPIService(client);

  LabelTaskService get labelTaskService => new LabelTaskAPIService(client);

  LabelTaskBulkAPIService get labelTaskBulkService =>
      new LabelTaskBulkAPIService(client);

  var androidSpecificsDueDate = notifs.AndroidNotificationDetails(
      "Vikunja1",
      "Due Date Notifications",
      channelDescription: "description",
      icon: 'ic_launcher_foreground',
      importance: notifs.Importance.high
  );
  var androidSpecificsReminders = notifs.AndroidNotificationDetails(
      "Vikunja2",
      "Reminder Notifications",
      channelDescription: "description",
      icon: 'ic_launcher_foreground',
      importance: notifs.Importance.high
  );
  notifs.IOSNotificationDetails iOSSpecifics;
  notifs.NotificationDetails platformChannelSpecificsDueDate;
  notifs.NotificationDetails platformChannelSpecificsReminders;

  String currentTimeZone;



  @override
  void initState() {
    super.initState();
    _client = Client(this);
    _newUserService = UserAPIService(client);
    _loadCurrentUser();
    tz.initializeTimeZones();
    iOSSpecifics = notifs.IOSNotificationDetails();
    platformChannelSpecificsDueDate = notifs.NotificationDetails(
        android: androidSpecificsDueDate, iOS: iOSSpecifics);
    platformChannelSpecificsReminders = notifs.NotificationDetails(
        android: androidSpecificsReminders, iOS: iOSSpecifics);
    notificationInitializer();
  }

  void changeUser(User newUser, {String token, String base}) async {
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
    currentTimeZone = await FlutterNativeTimezone.getLocalTimezone();
    notifLaunch = await notificationsPlugin.getNotificationAppLaunchDetails();
    await notifications.initNotifications(notificationsPlugin);
    requestIOSPermissions(notificationsPlugin);
  }

  void scheduleDueNotifications() {
    notificationsPlugin.cancelAll().then((value) {
      taskService.getAll().then((value) =>
          value.forEach((task) {
            if(task.reminderDates != null)
              task.reminderDates.forEach((reminder) {
                scheduleNotification("Reminder", "This is your reminder for '" + task.title + "'",
                    notificationsPlugin,
                    reminder,
                    currentTimeZone,
                    platformChannelSpecifics: platformChannelSpecificsReminders,
                    id: (reminder.millisecondsSinceEpoch/1000).floor());
              });
            if(task.dueDate != null)
              scheduleNotification("Due Reminder","The task '" + task.title + "' is due.",
                  notificationsPlugin,
                  task.dueDate,
                  currentTimeZone,
                  platformChannelSpecifics: platformChannelSpecificsDueDate,
                  id: task.id);
          })
      );
    });
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
    var loadedCurrentUser;
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
      loadedCurrentUser = User(int.tryParse(currentUser), "", "");
    } catch (otherExceptions) {
      loadedCurrentUser = User(int.tryParse(currentUser), "", "");
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
    if(client != null && client.authenticated) {
      scheduleDueNotifications();
    }
    return new _VikunjaGlobalInherited(
      data: this,
      child: client == null || !client.authenticated ? widget.login : widget.child,
    );
  }
}

class _VikunjaGlobalInherited extends InheritedWidget {
  final VikunjaGlobalState data;

  _VikunjaGlobalInherited({Key key, this.data, Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(_VikunjaGlobalInherited oldWidget) {
    return (data.currentUser != null &&
            data.currentUser.id != oldWidget.data.currentUser.id) ||
        data.client != oldWidget.data.client;
  }
}
