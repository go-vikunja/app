/// Where a saved filter's screen stands with downloading its tasks by
/// itself.
enum QuietDownloads {
  /// Its tasks have not shown yet.
  unopened,

  /// Opened; the next time its tasks are missing they download.
  watching,

  /// A download ran since the tasks last showed; another starts only once
  /// they show and go again.
  downloadedWhileMissing,
}

/// One look at a saved filter's downloaded tasks: on opening, a download
/// when they are missing or [stale], and later whenever they go while the
/// filter is still [listed] (the sync purged them). A filter no longer
/// listed was deleted on the web: the server would only say not found.
/// While [busy] with a download or a refresh, none starts, but the look
/// still counts.
({QuietDownloads next, bool start}) quietDownloadStep(
  QuietDownloads state, {
  required bool loaded,
  required bool stale,
  required bool listed,
  required bool busy,
}) {
  if (loaded) {
    final opening = state == QuietDownloads.unopened;
    return (next: QuietDownloads.watching, start: opening && stale && !busy);
  }
  if (state == QuietDownloads.downloadedWhileMissing || !listed) {
    return (
      next: state == QuietDownloads.unopened ? QuietDownloads.watching : state,
      start: false,
    );
  }
  return (next: QuietDownloads.downloadedWhileMissing, start: !busy);
}
