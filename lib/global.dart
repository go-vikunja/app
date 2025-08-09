import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vikunja_app/data/data_sources/bucket_data_source.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/task_label_data_source.dart';
import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/data_sources/project_view_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_label_bulk_data_source.dart';
import 'package:vikunja_app/data/data_sources/label_data_source.dart';
import 'package:vikunja_app/data/data_sources/server_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/data_sources/user_data_source.dart';
import 'package:vikunja_app/data/data_sources/version_data_source.dart';
import 'package:vikunja_app/data/repositories/bucket_repository_impl.dart';
import 'package:vikunja_app/data/repositories/label_repository_impl.dart';
import 'package:vikunja_app/data/repositories/project_repository_impl.dart';
import 'package:vikunja_app/data/repositories/project_view_repository_impl.dart';
import 'package:vikunja_app/data/repositories/server_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_label_bulk_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_label_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/data/repositories/user_repository_impl.dart';
import 'package:vikunja_app/data/repositories/version_repository_impl.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/repositories/bucket_repository.dart';
import 'package:vikunja_app/domain/repositories/label_repository.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';
import 'package:vikunja_app/domain/repositories/project_view_repository.dart';
import 'package:vikunja_app/domain/repositories/server_repository.dart';
import 'package:vikunja_app/domain/repositories/task_label_bulk_repository.dart';
import 'package:vikunja_app/domain/repositories/task_label_repository.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/domain/repositories/user_repository.dart';
import 'package:vikunja_app/domain/repositories/version_repository.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:vikunja_app/core/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'main.dart';

class VikunjaGlobal extends StatefulWidget {
  final Widget child;
  final Widget login;

  VikunjaGlobal({required this.child, required this.login});

  @override
  VikunjaGlobalState createState() => VikunjaGlobalState();

  static VikunjaGlobalState of(BuildContext context) {
    var widget =
        context.dependOnInheritedWidgetOfExactType<VikunjaGlobalInherited>();
    return widget!.data;
  }
}

class VikunjaGlobalState extends State<VikunjaGlobal> {
  final FlutterSecureStorage _storage = new FlutterSecureStorage();

  User? _currentUser;
  bool _loading = true;
  bool expired = false;
  late Client _client;
  UserRepository? _newUserService;
  NotificationClass _notificationClass = NotificationClass();

  User? get currentUser => _currentUser;

  Client get client => _client;

  GlobalKey<ScaffoldMessengerState> get snackbarKey => globalSnackbarKey;

  UserRepository? get newUserService => _newUserService;

  ServerRepository get serverService =>
      ServerRepositoryImpl(ServerDataSource(client));

  SettingsManager get settingsManager => new SettingsManager(_storage);

  VersionRepository get versionChecker =>
      VersionRepositoryImpl(VersionDataSource(snackbarKey));

  ProjectRepository get projectService =>
      ProjectRepositoryImpl(ProjectDataSource(client, _storage));

  ProjectViewRepository get projectViewService =>
      ProjectViewRepositoryImpl(ProjectViewDataSource(client));

  TaskRepository get taskService => TaskRepositoryImpl(TaskDataSource(client));

  BucketRepository get bucketService =>
      new BucketRepositoryImpl(BucketDataSource(client));

  TaskServiceOptions get taskServiceOptions => new TaskServiceOptions();

  NotificationClass get notifications => _notificationClass;

  LabelRepository get labelService =>
      LabelRepositoryImpl(LabelDataSource(client));

  TaskLabelRepository get labelTaskService =>
      TaskLabelRepositoryImpl(TaskLabelDataSource(client));

  TaskLabelBulkRepository get labelTaskBulkService =>
      TaskLabelBulkRepositoryImpl(TaskLabelBulkDataSource(client));

  late String currentTimeZone;

  void updateWorkmanagerDuration() {
    if (kIsWeb) {
      return;
    }
    Workmanager().cancelAll().then((value) {
      settingsManager.getWorkmanagerDuration().then((duration) {
        if (duration.inMinutes > 0) {
          Workmanager().registerPeriodicTask("update-tasks", "update-tasks",
              frequency: duration,
              constraints: Constraints(networkType: NetworkType.connected),
              initialDelay: Duration(seconds: 15),
              inputData: {
                "client_token": client.token,
                "client_base": client.base
              });
        }

        Workmanager().registerPeriodicTask("refresh-token", "refresh-token",
            frequency: Duration(hours: 12),
            constraints: Constraints(
                networkType: NetworkType.connected, requiresDeviceIdle: true),
            initialDelay: Duration(seconds: 15));
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _client = Client(snackbarKey);
    settingsManager
        .getIgnoreCertificates()
        .then((value) => client.reloadIgnoreCerts(value == "1"));
    _newUserService = UserRepositoryImpl(UserDataSource(client));
    _loadCurrentUser();
    tz.initializeTimeZones();
    notifications.notificationInitializer();
    settingsManager.getVersionNotifications().then((value) {
      if (value == "1") {
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
    updateWorkmanagerDuration();

    setState(() {
      _currentUser = newUser;
      _loading = false;
    });
  }

  void logoutUser(BuildContext context) async {
//    _storage.deleteAll().then((_) {
    var userId = await _storage.read(key: "currentUser");
    await _storage.delete(key: userId!); //delete token
    await _storage.delete(key: "${userId}_base");
    setState(() {
      client.reset();
      _currentUser = null;
    });
    /*   }).catchError((err) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('An error occurred while logging out!'),
      ));
    });*/
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
      loadedCurrentUser =
          await UserRepositoryImpl(UserDataSource(client)).getCurrentUser();
      // load new token from server to avoid expiration
      String? newToken = await newUserService?.getToken();
      if (newToken != null) {
        _storage.write(key: currentUser, value: newToken);
        client.configure(token: newToken);
      }
    } on ApiException catch (e) {
      dev.log("Error code: " + e.errorCode.toString(), level: 1000);
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
    updateWorkmanagerDuration();
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
    if (client.authenticated) {
      notifications.scheduleDueNotifications(taskService);
    }
    return new VikunjaGlobalInherited(
      data: this,
      key: UniqueKey(),
      child: !client.authenticated ? widget.login : widget.child,
    );
  }
}

class VikunjaGlobalInherited extends InheritedWidget {
  final VikunjaGlobalState data;

  VikunjaGlobalInherited({Key? key, required this.data, required Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(VikunjaGlobalInherited oldWidget) {
    return (data.currentUser != null &&
            data.currentUser!.id != oldWidget.data.currentUser!.id) ||
        data.client != oldWidget.data.client;
  }
}
