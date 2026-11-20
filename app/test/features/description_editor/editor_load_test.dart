import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_load.dart';

void main() {
  test('every state and event', () {
    const loading = EditorLoad.loading;
    const ready = EditorLoad.ready;
    const failed = EditorLoad.failed;
    const stopped = EditorLoad.stopped;
    const table = <(EditorLoad, EditorLoadEvent, EditorLoad)>[
      (loading, EditorLoadEvent.ready, ready),
      (loading, EditorLoadEvent.failed, failed),
      (loading, EditorLoadEvent.stopped, stopped),
      (ready, EditorLoadEvent.ready, ready),
      (ready, EditorLoadEvent.failed, ready),
      (ready, EditorLoadEvent.stopped, stopped),
      // Ready after the load timeout or an early failure: the editor shows.
      (failed, EditorLoadEvent.ready, ready),
      (failed, EditorLoadEvent.failed, failed),
      (failed, EditorLoadEvent.stopped, stopped),
      // The bridge reports ready once, before any stop; a stopped page
      // stays stopped until Reload.
      (stopped, EditorLoadEvent.ready, stopped),
      (stopped, EditorLoadEvent.failed, stopped),
      (stopped, EditorLoadEvent.stopped, stopped),
    ];
    expect(table, hasLength(EditorLoad.values.length * 3));
    for (final (from, event, to) in table) {
      expect(from.next(event), to, reason: '$from + $event');
    }
  });

  group('hasUnsavedEdit', () {
    bool unsaved(
      EditorLoad load, {
      bool dirty = false,
      String? restored,
      String? copy,
    }) => hasUnsavedEdit(
      load: load,
      dirty: dirty,
      restored: restored,
      copy: copy,
    );

    test('a ready page counts its own changes and a restored edit, not the '
        'copy', () {
      expect(unsaved(EditorLoad.ready), isFalse);
      expect(unsaved(EditorLoad.ready, copy: '<p>old copy</p>'), isFalse);
      expect(unsaved(EditorLoad.ready, dirty: true), isTrue);
      expect(unsaved(EditorLoad.ready, restored: '<p>draft</p>'), isTrue);
    });

    test('otherwise only a copy counts', () {
      for (final load in [
        EditorLoad.loading,
        EditorLoad.failed,
        EditorLoad.stopped,
      ]) {
        expect(unsaved(load, dirty: true), isFalse, reason: '$load');
        expect(unsaved(load, restored: '<p>draft</p>'), isFalse);
        expect(unsaved(load, copy: '<p>copy</p>'), isTrue, reason: '$load');
      }
    });
  });
}
