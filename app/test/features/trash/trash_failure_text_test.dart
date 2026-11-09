import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_failure_text.dart';

import '../../helpers/pump_app.dart';

void main() {
  const taskActions = [TrashAction.restoreTask, TrashAction.deleteTaskForever];
  const projectActions = [
    TrashAction.restoreProject,
    TrashAction.deleteProjectForever,
  ];

  for (final l10n in [en, de]) {
    group(l10n.localeName, () {
      String text(Object error, TrashAction action) =>
          trashFailureText(l10n, error, action);

      test('a delete still on its way asks to try again in a moment', () {
        for (final action in TrashAction.values) {
          expect(
            text(const TaskDeleteInFlight(7), action),
            l10n.trashDeleteStillSending,
            reason: '$action',
          );
        }
      });

      test('without a connection the restores say restoring needs one', () {
        for (final problem in [
          NetworkProblem.unreachable,
          NetworkProblem.timeout,
        ]) {
          final offline = NetworkFailure(problem);
          for (final action in [
            TrashAction.restoreTask,
            TrashAction.restoreProject,
          ]) {
            expect(
              text(offline, action),
              l10n.trashRestoreNeedsConnection,
              reason: '$action $problem',
            );
          }
          for (final action in [
            TrashAction.deleteTaskForever,
            TrashAction.deleteProjectForever,
            TrashAction.empty,
          ]) {
            expect(
              text(offline, action),
              l10n.trashNeedsConnection,
              reason: '$action $problem',
            );
          }
        }
      });

      test('a 404 without a code means the server has no bin', () {
        for (final action in TrashAction.values) {
          expect(
            text(const NotFound(), action),
            l10n.trashUnavailable,
            reason: '$action',
          );
        }
      });

      test('a refusal for permission, worded by action', () {
        const forbidden = Forbidden(message: 'forbidden');
        expect(
          text(forbidden, TrashAction.restoreTask),
          l10n.trashRestoreTaskForbidden,
        );
        expect(
          text(forbidden, TrashAction.restoreProject),
          l10n.trashRestoreProjectAdminOnly,
        );
        expect(
          text(forbidden, TrashAction.deleteTaskForever),
          l10n.trashDeleteTaskAdminOnly,
        );
        expect(
          text(forbidden, TrashAction.deleteProjectForever),
          l10n.trashDeleteProjectAdminOnly,
        );
        expect(
          text(
            const Forbidden(code: 1, message: "You're not allowed to do this."),
            TrashAction.empty,
          ),
          l10n.trashDeleteTaskAdminOnly,
        );
      });

      test('a task whose project is in the bin asks to restore that first, '
          'before the gone texts', () {
        const projectInTrash = NotFound(
          code: 3018,
          message: 'This project is in the trash.',
          trash: TrashDetails(id: 3, canRestore: true),
        );
        for (final action in taskActions) {
          expect(
            text(projectInTrash, action),
            l10n.trashTaskProjectInTrash,
            reason: '$action',
          );
        }
      });

      test('an item that is gone is no longer in the bin', () {
        for (final action in taskActions) {
          for (final gone in const [
            NotFound(code: 4002, message: 'This task does not exist'),
            NotFound(code: 4040, trash: TrashDetails(id: 7)),
          ]) {
            expect(text(gone, action), l10n.trashTaskGone, reason: '$action');
          }
        }
        for (final action in projectActions) {
          expect(
            text(const NotFound(code: 3001), action),
            l10n.trashProjectGone,
            reason: '$action',
          );
        }
        expect(
          text(const NotFound(code: 4002), TrashAction.empty),
          l10n.trashActionFailed,
        );
      });

      test('a task in an archived project (3008), worded by action', () {
        const archived = DomainError(
          412,
          code: 3008,
          message: 'This project is archived.',
        );
        expect(
          text(archived, TrashAction.restoreTask),
          l10n.trashRestoreArchived,
        );
        expect(
          text(archived, TrashAction.deleteTaskForever),
          l10n.trashDeleteArchived,
        );
      });

      test('a project whose parent is in the bin (3019)', () {
        expect(
          text(
            const DomainError(
              412,
              code: 3019,
              message: 'The parent project is in the trash.',
            ),
            TrashAction.restoreProject,
          ),
          l10n.trashRestoreParentInTrash,
        );
      });

      test('a project whose parent is archived (3016)', () {
        expect(
          text(
            const DomainError(
              412,
              code: 3016,
              message: 'The parent project is archived.',
            ),
            TrashAction.restoreProject,
          ),
          l10n.projectUnarchiveParentFirst,
        );
      });

      test("the shared texts, before the server's detail", () {
        expect(
          text(
            const ServerFailure(500, message: 'Internal Server Error'),
            TrashAction.empty,
          ),
          l10n.actionFailureServerError,
        );
        expect(
          text(
            const SessionEnded(SessionEndReason.expired, code: 16003),
            TrashAction.restoreProject,
          ),
          l10n.actionFailureSessionEnded,
        );
        expect(
          text(const LinkShareGone(), TrashAction.restoreTask),
          l10n.actionFailureGuestAccessEnded,
        );
        expect(
          text(
            const RateLimited(message: 'Too Many Requests'),
            TrashAction.deleteTaskForever,
          ),
          l10n.actionFailureRateLimited,
        );
      });

      test('an unmapped refusal keeps the server detail, trimmed', () {
        expect(
          text(
            const DomainError(
              412,
              code: 3021,
              message: ' The parent project does not exist. ',
            ),
            TrashAction.restoreProject,
          ),
          l10n.trashActionRefused('The parent project does not exist.'),
        );
      });

      test('anything else did not work', () {
        for (final error in <Object>[
          const DomainError(409, code: 4042),
          const DomainError(409, code: 4042, message: '   '),
          const ValidationFailed(),
          const UnexpectedResponse(502),
          StateError('x'),
        ]) {
          expect(
            text(error, TrashAction.restoreTask),
            l10n.trashActionFailed,
            reason: '$error',
          );
        }
      });
    });
  }
}
