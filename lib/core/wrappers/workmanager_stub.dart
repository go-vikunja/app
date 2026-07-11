void initializeWorkmanager(void Function()? callbackDispatcher) {
  // Workmanager is not supported on web
}

void cancelAllWorkmanagerTasks() async {
  // Workmanager is not supported on web
}

void registerPeriodicWorkmanagerTask({
  required String uniqueName,
  required String taskName,
  required Duration frequency,
  required Duration initialDelay,
  required dynamic constraints,
}) {
  // Workmanager is not supported on web
}
