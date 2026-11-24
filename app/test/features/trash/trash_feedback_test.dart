import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_failure_text.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_feedback.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<ScaffoldMessengerState> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(body: SizedBox.expand()),
      ),
    );
    return tester.state(find.byType(ScaffoldMessenger));
  }

  List<Object?> recordHaptics(WidgetTester tester) {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  SnackBar shown(WidgetTester tester) => tester.widget(find.byType(SnackBar));

  void useScreenReader(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          supportsAnnounce: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  group('showDeletedSnackBar', () {
    testWidgets('replaces a snackbar still up and offers Undo for 10 s', (
      tester,
    ) async {
      final messenger = await pump(tester);
      messenger.showSnackBar(const SnackBar(content: Text('Earlier')));
      await tester.pumpAndSettle();
      var undos = 0;

      showDeletedSnackBar(
        messenger,
        text: en.taskMovedToTrash,
        undoLabel: en.undo,
        persist: false,
        onUndo: () => undos++,
      );
      await tester.pumpAndSettle();

      expect(find.text('Earlier'), findsNothing);
      expect(find.text(en.taskMovedToTrash), findsOneWidget);
      expect(shown(tester).duration, deletedSnackBarDuration);
      expect(deletedSnackBarDuration, const Duration(seconds: 10));
      expect(shown(tester).persist, isFalse);

      await tester.pump(const Duration(seconds: 9));
      expect(find.text(en.taskMovedToTrash), findsOneWidget);
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();
      expect(undos, 1);
      expect(find.text(en.taskMovedToTrash), findsNothing);
    });

    testWidgets('goes after 10 s unless it persists', (tester) async {
      final messenger = await pump(tester);

      showDeletedSnackBar(
        messenger,
        text: en.taskMovedToTrash,
        undoLabel: en.undo,
        persist: false,
        onUndo: () {},
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(find.text(en.taskMovedToTrash), findsNothing);

      showDeletedSnackBar(
        messenger,
        text: en.taskMovedToTrash,
        undoLabel: en.undo,
        persist: true,
        onUndo: () {},
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text(en.taskMovedToTrash), findsOneWidget);
      expect(shown(tester).persist, isTrue);
    });

    testWidgets('persists only with an Undo, as nothing else would close '
        'it', (tester) async {
      final messenger = await pump(tester);

      final controller = showDeletedSnackBar(
        messenger,
        text: en.taskDeleted,
        undoLabel: en.undo,
        persist: true,
      );
      await tester.pumpAndSettle();

      expect(shown(tester).persist, isFalse);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(find.text(en.taskDeleted), findsNothing);
      expect(await controller.closed, SnackBarClosedReason.timeout);
    });

    testWidgets('holds what the Undo restores until the snackbar is closed: '
        'past 10 s under a screen reader, at its timeout otherwise', (
      tester,
    ) async {
      useScreenReader(tester);
      final messenger = await pump(tester);
      final holds = _Holds();

      showDeletedSnackBar(
        messenger,
        text: en.taskMovedToTrash,
        undoLabel: en.undo,
        persist: true,
        onUndo: () {},
        hold: holds.take,
      );
      await tester.pumpAndSettle();
      await tester.pump(deletedSnackBarDuration * 3);
      await tester.pumpAndSettle();

      expect(holds.open, 1);
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();
      expect(holds.open, 0);

      showDeletedSnackBar(
        messenger,
        text: en.taskMovedToTrash,
        undoLabel: en.undo,
        persist: false,
        onUndo: () {},
        hold: holds.take,
      );
      await tester.pumpAndSettle();
      expect(holds.open, 1);
      await tester.pump(deletedSnackBarDuration + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(holds.open, 0);
      expect(holds.taken, 2);

      showDeletedSnackBar(
        messenger,
        text: en.taskDeleted,
        undoLabel: en.undo,
        persist: true,
        hold: holds.take,
      );
      await tester.pumpAndSettle();
      expect(holds.taken, 2);
    });

    testWidgets('has no action without onUndo', (tester) async {
      final messenger = await pump(tester);

      final controller = showDeletedSnackBar(
        messenger,
        text: en.taskDeleted,
        undoLabel: en.undo,
        persist: false,
      );
      await tester.pumpAndSettle();

      expect(find.text(en.taskDeleted), findsOneWidget);
      expect(shown(tester).action, isNull);
      expect(find.text(en.undo), findsNothing);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(await controller.closed, SnackBarClosedReason.timeout);
    });
  });

  group('runUndo', () {
    testWidgets('restores, then says so after a selection haptic, once the '
        'snackbar still up has gone', (tester) async {
      final haptics = recordHaptics(tester);
      final messenger = await pump(tester);
      messenger.showSnackBar(const SnackBar(content: Text('Earlier')));
      await tester.pumpAndSettle();
      var restores = 0;

      await runUndo(
        messenger,
        en,
        restore: () async => restores++,
        restored: en.taskRestored,
        action: TrashAction.restoreTask,
      );
      await tester.pumpAndSettle();

      expect(restores, 1);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.text(en.taskRestored), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Earlier'), findsNothing);
      expect(find.text(en.taskRestored), findsOneWidget);
      expect(shown(tester).action, isNull);
    });

    testWidgets('a snackbar shown while the restore runs keeps its Undo', (
      tester,
    ) async {
      final messenger = await pump(tester);
      final restore = Completer<void>();
      var newerUndos = 0;

      final undo = runUndo(
        messenger,
        en,
        restore: () => restore.future,
        restored: en.taskRestored,
        action: TrashAction.restoreTask,
      );
      showDeletedSnackBar(
        messenger,
        text: 'Newer',
        undoLabel: en.undo,
        persist: false,
        onUndo: () => newerUndos++,
      );
      await tester.pumpAndSettle();
      restore.complete();
      await undo;
      await tester.pumpAndSettle();

      expect(find.text('Newer'), findsOneWidget);
      expect(find.text(en.taskRestored), findsNothing);
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();
      expect(newerUndos, 1);
      expect(find.text(en.taskRestored), findsOneWidget);
    });

    for (final failure in [
      const TaskDeleteInFlight(7) as Object,
      const NetworkFailure(NetworkProblem.unreachable),
    ]) {
      testWidgets('a restore that may work a little later ($failure) offers '
          'Undo again, which runs the same restore', (tester) async {
        final messenger = await pump(tester);
        var restores = 0;

        await runUndo(
          messenger,
          en,
          restore: () async {
            if (++restores == 1) {
              Error.throwWithStackTrace(failure, StackTrace.current);
            }
            return null;
          },
          restored: en.taskRestored,
          action: TrashAction.restoreTask,
        );
        await tester.pumpAndSettle();

        expect(
          find.text(trashFailureText(en, failure, TrashAction.restoreTask)),
          findsOneWidget,
        );
        expect(shown(tester).duration, deletedSnackBarDuration);
        expect(shown(tester).persist, isFalse);
        await tester.tap(find.text(en.undo));
        await tester.pumpAndSettle();

        expect(restores, 2);
        expect(find.text(en.taskRestored), findsOneWidget);
        expect(find.text(en.undo), findsNothing);
      });
    }

    testWidgets('under a screen reader that Undo waits for the user', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            supportsAnnounce: true,
          );
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final messenger = await pump(tester);

      await runUndo(
        messenger,
        en,
        restore: () async => throw const TaskDeleteInFlight(7),
        restored: en.taskRestored,
        action: TrashAction.restoreTask,
      );
      await tester.pumpAndSettle();
      await tester.pump(deletedSnackBarDuration * 3);
      await tester.pumpAndSettle();

      expect(find.text(en.trashDeleteStillSending), findsOneWidget);
      expect(shown(tester).persist, isTrue);
      expect(find.text(en.undo), findsOneWidget);
    });

    testWidgets('holds what it restores from before the restore until it is '
        'over, and under a screen reader until the Undo offered again is '
        'closed', (tester) async {
      useScreenReader(tester);
      final messenger = await pump(tester);
      final holds = _Holds();
      final heldAtRestore = <int>[];
      var restores = 0;

      await runUndo(
        messenger,
        en,
        restore: () async {
          heldAtRestore.add(holds.open);
          if (++restores == 1) throw const TaskDeleteInFlight(7);
          return null;
        },
        restored: en.taskRestored,
        action: TrashAction.restoreTask,
        hold: holds.take,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();

      expect(heldAtRestore, [1]);
      expect(holds.open, 1);
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();

      expect(heldAtRestore, [1, 2]);
      expect(find.text(en.taskRestored), findsOneWidget);
      expect(holds.open, 0);
      expect(holds.taken, 2);

      await runUndo(
        messenger,
        en,
        restore: () async => throw const DomainError(412, code: 3008),
        restored: en.taskRestored,
        action: TrashAction.restoreTask,
        hold: holds.take,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(en.trashRestoreArchived), findsOneWidget);
      expect(holds.open, 0);
    });

    for (final (error, action, message) in [
      (
        const DomainError(412, code: 3008) as Object,
        TrashAction.restoreTask,
        en.trashRestoreArchived,
      ),
      (
        const Forbidden(),
        TrashAction.restoreProject,
        en.trashRestoreProjectAdminOnly,
      ),
      (
        const NetworkFailure(NetworkProblem.unreachable),
        TrashAction.restoreTask,
        en.trashRestoreNeedsConnection,
      ),
      (StateError('broken'), TrashAction.restoreProject, en.trashActionFailed),
    ]) {
      testWidgets('a failing restore ($error) says why after a heavy haptic', (
        tester,
      ) async {
        final haptics = recordHaptics(tester);
        final messenger = await pump(tester);

        await runUndo(
          messenger,
          en,
          restore: () async =>
              Error.throwWithStackTrace(error, StackTrace.current),
          restored: en.taskRestored,
          action: action,
        );
        await tester.pumpAndSettle();

        expect(haptics, [
          'HapticFeedbackType.selectionClick',
          'HapticFeedbackType.heavyImpact',
        ]);
        expect(find.text(message), findsOneWidget);
        expect(find.text(en.taskRestored), findsNothing);
        expect(
          find.text(en.undo),
          error is NetworkFailure ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('a restore that throws at once does not throw either', (
      tester,
    ) async {
      final messenger = await pump(tester);

      await runUndo(
        messenger,
        en,
        restore: () => throw const NotFound(code: 4002),
        restored: en.taskRestored,
        action: TrashAction.restoreTask,
      );
      await tester.pumpAndSettle();

      expect(find.text(en.trashTaskGone), findsOneWidget);
    });

    testWidgets('says nothing once the messenger is gone', (tester) async {
      final messenger = await pump(tester);
      final restore = Completer<void>();

      final undo = runUndo(
        messenger,
        en,
        restore: () => restore.future,
        restored: en.taskRestored,
        action: TrashAction.restoreTask,
      );
      await tester.pumpWidget(const SizedBox());
      restore.complete();
      await undo;
      await tester.pumpAndSettle();

      expect(messenger.mounted, isFalse);
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('does nothing on a messenger that is gone', (tester) async {
      final messenger = await pump(tester);
      await tester.pumpWidget(const SizedBox());
      var restores = 0;

      await runUndo(
        messenger,
        en,
        restore: () async => restores++,
        restored: en.taskRestored,
        action: TrashAction.restoreTask,
      );

      expect(restores, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is in German', (tester) async {
      final messenger = await pump(tester);

      await runUndo(
        messenger,
        de,
        restore: () async => throw const Forbidden(),
        restored: de.taskRestored,
        action: TrashAction.restoreTask,
      );
      await tester.pumpAndSettle();

      expect(find.text(de.trashRestoreTaskForbidden), findsOneWidget);
    });
  });
}

final class _Holds {
  /// Holds not let go yet.
  int open = 0;

  /// Every hold taken.
  int taken = 0;

  void Function() take() {
    open++;
    taken++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      open--;
    };
  }
}
