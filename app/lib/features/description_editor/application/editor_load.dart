/// What the bridge reports about the current page load.
enum EditorLoadEvent { ready, failed, stopped }

/// Where the current page load of the editor stands; each Reload or Retry
/// starts again at [loading].
enum EditorLoad {
  loading,
  ready,

  /// Did not load in time, or reported a failure before it was ready.
  failed,

  /// The WebView's process ended after the page was ready.
  stopped;

  EditorLoad next(EditorLoadEvent event) => switch ((this, event)) {
    (stopped, _) || (_, EditorLoadEvent.stopped) => stopped,
    // A page that answers after the timeout is as good as one on time.
    (_, EditorLoadEvent.ready) => ready,
    // A ready page's failure is only logged.
    (ready, EditorLoadEvent.failed) => ready,
    (_, EditorLoadEvent.failed) => failed,
  };
}

/// Whether leaving loses something: a ready page knows whether its
/// document changed, else only the copy taken of it counts. A [restored]
/// edit counts as a change even while the page reports none.
bool hasUnsavedEdit({
  required EditorLoad load,
  required bool dirty,
  required String? restored,
  required String? copy,
}) => load == EditorLoad.ready ? dirty || restored != null : copy != null;
