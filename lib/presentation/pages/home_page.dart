import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/pages/project/project_list_page.dart';
import 'package:vikunja_app/presentation/pages/settings_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_list_page.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  static const platform = MethodChannel('vikunja');

  int _selectedDrawerIndex = 0, _previousDrawerIndex = 0;
  Widget? drawerItem;

  List<Widget> widgets = [TaskListPage(), ProjectListPage(), SettingsPage()];

  List<NavigationDestination> navbarItems = [
    NavigationDestination(icon: Icon(Icons.home), label: "Home"),
    NavigationDestination(icon: Icon(Icons.list), label: "Projects"),
    NavigationDestination(icon: Icon(Icons.settings), label: "Settings"),
  ];

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      scheduleIntent();
    });

    initNotifications();

    var settings = ref.read(settingsControllerProvider);
    settings.whenData((settings) {
      if (settings.versionNotifications) {
        postVersionCheckSnackbar();
      }
    });

    tz.initializeTimeZones();
  }

  Future<void> initNotifications() async {
    var notifGranted = await Permission.notification.isGranted;
    if (notifGranted) {
      NotificationHandler notificationClass = NotificationHandler();
      await notificationClass.initNotifications();
      ref.read(notificationProvider.notifier).set(notificationClass);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedDrawerIndex != _previousDrawerIndex || drawerItem == null) {
      drawerItem = _getDrawerItemWidget(_selectedDrawerIndex);
    }

    return Scaffold(
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: NavigationBar(
          destinations: navbarItems,
          selectedIndex: _selectedDrawerIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedDrawerIndex = index;
            });
          },
        ),
      ),
      body: drawerItem,
    );
  }

  Widget _getDrawerItemWidget(int pos) {
    _previousDrawerIndex = pos;
    return widgets[pos];
  }

  void scheduleIntent() async {
    try {
      String? argument = await platform.invokeMethod<String>("isQuickTile", "");

      return showAddItemDialog(argument);
    } catch (e) {
      developer.log("Error $e");
    }

    platform.setMethodCallHandler((call) async {
      return showAddItemDialog(call.arguments as String);
    });
  }

  Future<dynamic> showAddItemDialog(String? title) async {
    var response = await ref.read(userRepositoryProvider).getCurrentUser();
    if (response.isSuccessful) {
      var defaultProjectId = response
          .toSuccess()
          .body
          .settings
          ?.default_project_id;
      if (defaultProjectId == null || defaultProjectId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a default project in the settings'),
          ),
        );
      } else {
        _addItemDialog(context, defaultProjectId, title);
        return Future.value();
      }
    }
  }

  void _addItemDialog(
    BuildContext context,
    int defaultProjectId, [
    String? title = null,
  ]) {
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        onAddTask: (title, dueDate) =>
            _addTask(title, dueDate, defaultProjectId, context),
        title: title,
      ),
    );
  }

  Future<void> _addTask(
    String title,
    DateTime? dueDate,
    int defaultProjectId,
    BuildContext context,
  ) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      return;
    }

    var task = Task(
      title: title,
      dueDate: dueDate,
      createdBy: currentUser,
      projectId: defaultProjectId,
    );

    var success = await ref
        .read(taskPageControllerProvider.notifier)
        .addTask(defaultProjectId, task);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The task was added successfully!')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding the task!')));
    }
  }

  Future<void> postVersionCheckSnackbar() async {
    var latestVersionTag = await ref
        .read(versionRepositoryProvider)
        .getLatestVersionTag();
    ref.read(versionRepositoryProvider).isUpToDate().then((value) {
      if (!value) {
        // not up to date
        SnackBar snackBar = SnackBar(
          content: Text("New version available: $latestVersionTag"),
          action: SnackBarAction(
            label: "View on Github",
            onPressed: () => launchUrl(
              Uri.parse(repo),
              mode: LaunchMode.externalApplication,
            ),
          ),
        );
        globalSnackbarKey.currentState?.showSnackBar(snackBar);
      }
    });
  }
}
