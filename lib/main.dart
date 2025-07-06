import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:vikunja_app/api/task_implementation.dart';
import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/service/services.dart';
import 'package:vikunja_app/stores/project_store.dart';
import 'package:workmanager/workmanager.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/pages/home.dart';
import 'package:vikunja_app/pages/user/login.dart';
import 'package:vikunja_app/theme/theme.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_downloader/flutter_downloader.dart';

import 'api/user_implementation.dart';
import 'managers/notifications.dart';

class IgnoreCertHttpOverrides extends HttpOverrides {
  bool ignoreCerts = false;

  IgnoreCertHttpOverrides(bool _ignore) {
    ignoreCerts = _ignore;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => ignoreCerts;
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  if (kIsWeb) {
    return;
  }
  Workmanager().executeTask((task, inputData) async {
    print(
        "Native called background task: $task"); //simpleTask will be emitted here.
    if (task == "update-tasks" && inputData != null) {
      Client client = Client(null,
          token: inputData["client_token"],
          base: inputData["client_base"],
          authenticated: true);
      tz.initializeTimeZones();
      return SettingsManager(new FlutterSecureStorage())
          .getIgnoreCertificates()
          .then((value) async {
        print("ignoring: $value");
        client.reloadIgnoreCerts(value == "1");

        TaskAPIService taskService = TaskAPIService(client);
        NotificationClass nc = NotificationClass();
        await nc.notificationInitializer();
        return nc
            .scheduleDueNotifications(taskService)
            .then((value) => Future.value(true));
      });
    } else if (task == "refresh-token") {
      final FlutterSecureStorage _storage = new FlutterSecureStorage();

      var currentUser = await _storage.read(key: 'currentUser');
      if (currentUser == null) {
        return Future.value(true);
      }
      var token = await _storage.read(key: currentUser);

      var base = await _storage.read(key: '${currentUser}_base');
      if (token == null || base == null) {
        return Future.value(true);
      }
      Client client = Client(null);
      client.configure(token: token, base: base, authenticated: true);
      // load new token from server to avoid expiration
      String? newToken = await UserAPIService(client).getToken();
      if (newToken != null) {
        _storage.write(key: currentUser, value: newToken);
      }
      return Future.value(true);
    } else {
      return Future.value(true);
    }
  });
}

final globalSnackbarKey = GlobalKey<ScaffoldMessengerState>();
final globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });
  try {
    if (!kIsWeb) {
      await FlutterDownloader.initialize();
    }
  } catch (e) {
    print("Failed to initialize downloader: $e");
  }
  try {
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    }
  } catch (e) {
    print("Failed to initialize workmanager: $e");
  }
  runApp(ChangeNotifierProvider<ProjectProvider>(
      create: (_) => new ProjectProvider(),
      child: VikunjaGlobal(
        child: new VikunjaApp(
          home: HomePage(),
          key: UniqueKey(),
          navkey: globalNavigatorKey,
        ),
        login: new VikunjaApp(
          home: LoginPage(),
          key: UniqueKey(),
        ),
      )));
}

class ThemeModel with ChangeNotifier {
  FlutterThemeMode _themeMode = FlutterThemeMode.light;
  FlutterThemeMode get themeMode => _themeMode;

  void set themeMode(FlutterThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }

  ThemeData get themeData {
    switch (_themeMode) {
      case FlutterThemeMode.dark:
        return buildVikunjaDarkTheme();
      case FlutterThemeMode.materialYouLight:
        return buildVikunjaMaterialLightTheme();
      case FlutterThemeMode.materialYouDark:
        return buildVikunjaMaterialDarkTheme();
      default:
        return buildVikunjaTheme();
    }
  }

  ThemeData getWithColorScheme(
      ColorScheme? lightTheme, ColorScheme? darkTheme) {
    switch (_themeMode) {
      case FlutterThemeMode.dark:
        return buildVikunjaDarkTheme().copyWith(colorScheme: darkTheme);
      case FlutterThemeMode.materialYouLight:
        return buildVikunjaMaterialLightTheme()
            .copyWith(colorScheme: lightTheme);
      case FlutterThemeMode.materialYouDark:
        return buildVikunjaMaterialDarkTheme().copyWith(colorScheme: darkTheme);
      default:
        return buildVikunjaTheme().copyWith(colorScheme: lightTheme);
    }
  }
}

ThemeModel themeModel = ThemeModel();

class VikunjaApp extends StatelessWidget {
  final Widget home;
  final GlobalKey<NavigatorState>? navkey;
  bool sentryEnabled = false;
  bool sentyInitialized = false;

  VikunjaApp({Key? key, required this.home, this.navkey}) : super(key: key);

  Future<void> getLaunchData() async {
    try {
      SettingsManager manager = SettingsManager(new FlutterSecureStorage());
      await manager.getThemeMode().then((themeMode) {
        themeModel.themeMode = themeMode;
      });
      sentryEnabled = await manager.getSentryEnabled();
    } catch (e) {
      print("Failed to get theme mode: $e");
      return Future.value(false);
    }
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    return new ListenableBuilder(
        listenable: themeModel,
        builder: (_, mode) {
          return FutureBuilder<void>(
              future: getLaunchData(),
              builder: (BuildContext context, data) {
                if (data.hasData) {
                  return new DynamicColorBuilder(
                      builder: (lightTheme, darkTheme) {
                    if (sentryEnabled) {
                      if (!sentyInitialized) {
                        sentyInitialized = true;
                        print("sentry enabled");
                        SentryFlutter.init((options) {
                          options.dsn =
                              'https://a09618e3bb30e03b93233c21973df869@o1047380.ingest.us.sentry.io/4507995557134336';
                          options.tracesSampleRate = 1.0;
                          options.profilesSampleRate = 1.0;
                        }).then((_) {
                          FlutterError.onError = (details) async {
                            print("sending to sentry");
                            await Sentry.captureException(
                              details.exception,
                              stackTrace: details.stack,
                            );
                            FlutterError.presentError(details);
                          };
                          PlatformDispatcher.instance.onError = (error, stack) {
                            print("sending to sentry (platform)");
                            Sentry.captureException(error, stackTrace: stack);
                            FlutterError.presentError(FlutterErrorDetails(
                                exception: error, stack: stack));
                            return false;
                          };
                        });
                      }

                      return SentryWidget(
                          child: buildMaterialApp(themeModel.getWithColorScheme(
                              lightTheme, darkTheme)));
                    } else {
                      sentyInitialized = false;
                    }

                    return buildMaterialApp(
                        themeModel.getWithColorScheme(lightTheme, darkTheme));
                  });
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              });
        });
  }

  Widget buildMaterialApp(ThemeData? themeData) {
    return MaterialApp(
      title: 'Vikunja',
      theme: themeData,
      scaffoldMessengerKey: globalSnackbarKey,
      navigatorKey: navkey,
      // <= this
      home: this.home,
    );
  }
}
