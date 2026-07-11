import 'package:workmanager/workmanager.dart';

void initializeWorkmanager(void Function()? callbackDispatcher) {
  Workmanager().initialize(callbackDispatcher!);
}

void cancelAllWorkmanagerTasks() async {
  await Workmanager().cancelAll();
}

void registerPeriodicWorkmanagerTask({
  required String uniqueName,
  required String taskName,
  required Duration frequency,
  required Duration initialDelay,
  required Constraints? constraints,
}) {
  Workmanager().registerPeriodicTask(
    uniqueName,
    taskName,
    frequency: frequency,
    constraints: constraints,
    initialDelay: initialDelay,
  );
}
