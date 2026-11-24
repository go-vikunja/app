/// How long a delete's Undo is offered, as on the web.
const deleteUndoWindow = Duration(seconds: 10);

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

/// Whether the server has a task, as far as this device knows, and so
/// whether its delete moves it to the server's trash.
enum TaskOnServer {
  /// A server id, also one a temporary id was answered with meanwhile.
  yes,

  /// A create on its way, or sent without an answer: the server may have
  /// it.
  maybe,

  /// A create the server was never asked for, or refused: its delete goes
  /// without a request.
  no,
}
