import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/smart_lists/application/quiet_download.dart';

void main() {
  test('every state with tasks shown, stale, missing, gone and busy', () {
    const unopened = QuietDownloads.unopened;
    const watching = QuietDownloads.watching;
    const downloaded = QuietDownloads.downloadedWhileMissing;
    // (state, loaded, stale, listed, busy) -> (next, start)
    const table =
        <(QuietDownloads, bool, bool, bool, bool, QuietDownloads, bool)>[
          (unopened, true, false, true, false, watching, false),
          (unopened, true, true, true, false, watching, true),
          (unopened, true, true, true, true, watching, false),
          (unopened, true, true, false, false, watching, true),
          (unopened, false, false, true, false, downloaded, true),
          (unopened, false, false, true, true, downloaded, false),
          (unopened, false, false, false, false, watching, false),
          (watching, true, false, true, false, watching, false),
          (watching, true, true, true, false, watching, false),
          (watching, false, false, true, false, downloaded, true),
          (watching, false, false, true, true, downloaded, false),
          (watching, false, false, false, false, watching, false),
          (downloaded, false, false, true, false, downloaded, false),
          (downloaded, false, false, false, false, downloaded, false),
          (downloaded, true, false, true, false, watching, false),
          (downloaded, true, true, true, false, watching, false),
        ];
    for (final (state, loaded, stale, listed, busy, next, start) in table) {
      expect(
        quietDownloadStep(
          state,
          loaded: loaded,
          stale: stale,
          listed: listed,
          busy: busy,
        ),
        (next: next, start: start),
        reason:
            '$state loaded: $loaded stale: $stale listed: $listed '
            'busy: $busy',
      );
    }
  });

  test('tasks that go, show and go again download each time', () {
    var state = QuietDownloads.unopened;
    final starts = <bool>[];
    for (final loaded in [true, false, false, true, false]) {
      final step = quietDownloadStep(
        state,
        loaded: loaded,
        stale: false,
        listed: true,
        busy: false,
      );
      state = step.next;
      starts.add(step.start);
    }
    expect(starts, [false, true, false, false, true]);
  });
}
