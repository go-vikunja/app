/// What a task delete did here.
enum TaskDeletion {
  /// The task is not here, or its delete is queued already: nothing
  /// changed.
  none,

  /// The task is hidden here and its delete is queued;
  /// `TaskRepository.restoreTask` takes it back.
  queued,

  /// The task existed only here (the server refused its create) and is gone
  /// with its queued changes: nothing is sent and nothing brings it back.
  discarded,
}
