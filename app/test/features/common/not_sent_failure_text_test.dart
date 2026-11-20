import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_security_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_failure.dart';
import 'package:vikunja_mobile/features/attachments/presentation/attachment_messages.dart';
import 'package:vikunja_mobile/features/common/presentation/action_failure_text.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_change_failure.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/column_changes.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_change_failure.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_move_failure.dart';
import 'package:vikunja_mobile/features/sharing/presentation/share_texts.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/saved_filter_failure.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_messages.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_detail_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_view.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_failure.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_failure_text.dart';

import '../../helpers/pump_app.dart';

// A request that got no token was never sent (D59): no text may call it an
// unconfirmed change or a missing connection.
void main() {
  const unreadable = NetworkFailure(
    NetworkProblem.unreachable,
    cause: SecureStorageUnreadable(PlatformException),
  );
  const race = NetworkFailure(
    NetworkProblem.timeout,
    cause: RefreshDeferred.race,
  );
  const cutoff = NetworkFailure(
    NetworkProblem.timeout,
    cause: RefreshDeferred.cutoff,
  );

  String notSent(AppLocalizations l10n, NetworkFailure failure) =>
      failure.cause is SecureStorageUnreadable
      ? '${l10n.actionFailureSignInUnreadable} '
            '${l10n.failureSignInUnreadableSuggestion}'
      : '${l10n.actionFailureRenewalDeferred} '
            '${l10n.failureRenewalDeferredSuggestion}';

  final actions = <String, String Function(AppLocalizations, Object)>{
    'a share change': (l10n, error) =>
        shareFailureText(l10n, error, ShareChange.addPerson),
    'a label change': labelChangeFailureText,
    'a new team': (l10n, error) =>
        teamFailureText(l10n, error, TeamChange.create),
    'a team change': (l10n, error) =>
        teamFailureText(l10n, error, TeamChange.toggleAdmin),
    'a project change from its screen': (l10n, error) =>
        projectChangeFailureText(l10n, error, ProjectChange.favourite),
    'a project form': (l10n, error) =>
        projectChangeFailureText(l10n, error, ProjectChange.edit),
    'a project move': (l10n, error) =>
        projectMoveFailureText(l10n, error, parentChanged: false),
    'a saved filter form': (l10n, error) =>
        savedFilterFailureText(l10n, error, fromForm: true),
    'a saved filter change': (l10n, error) =>
        savedFilterFailureText(l10n, error, fromForm: false),
    'an account security change': accountSecurityFailureText,
    'an account settings change': accountSettingsFailureText,
    'an avatar upload': avatarUploadFailureText,
    'a comment': (l10n, error) =>
        commentFailureText(l10n, error, CommentWrite.send),
    'a reaction': (l10n, error) =>
        commentFailureText(l10n, error, CommentWrite.react),
    'an attachment change': attachmentFailureText,
    'an attachment download': (l10n, error) =>
        attachmentFailureText(l10n, error, download: true),
    'a column change': (l10n, error) =>
        columnChangeFailureText(l10n, error, ColumnChange.rename),
    'opening a task': taskOpenFailureText,
    'following': followFailureText,
    'a restore': (l10n, error) =>
        trashFailureText(l10n, error, TrashAction.restoreTask),
    'emptying the bin': (l10n, error) =>
        trashFailureText(l10n, error, TrashAction.empty),
    'duplicating a task': taskDuplicateFailureText,
  };

  for (final failure in const [unreadable, race, cutoff]) {
    group('${failure.cause}', () {
      for (final MapEntry(key: what, value: text) in actions.entries) {
        test('$what says nothing was sent', () {
          expect(text(en, failure), notSent(en, failure));
        });
      }

      test('a notice of a failed read tells a failure, not a missing '
          'connection', () {
        final at = DateTime.utc(2026, 11, 20, 9);
        expect(commentsFailureText(en, failure), en.commentsFailed);
        expect(
          commentsStoredText(en, at, failure, now: at),
          commentsStoredText(en, at, const ServerFailure(502), now: at),
        );
        expect(attachmentImageFailureText(en, failure), en.richTextImageFailed);
      });

      test('a share list is not out of date after it', () {
        expect(shareListOutdatedBy(failure), isFalse);
      });
    });
  }

  test('a request that was sent keeps its own words', () {
    const timeout = NetworkFailure(NetworkProblem.timeout);
    const offline = NetworkFailure(NetworkProblem.unreachable);
    expect(notSentFailureText(en, timeout), isNull);
    expect(notSentFailureText(en, offline), isNull);
    expect(labelChangeFailureText(en, timeout), en.labelsUnconfirmed);
    expect(labelChangeFailureText(en, offline), en.labelsNeedsConnection);
    expect(shareListOutdatedBy(timeout), isTrue);
    expect(commentsFailureText(en, offline), en.commentsNeedConnection);
  });

  test('in German too', () {
    expect(labelChangeFailureText(de, unreadable), notSent(de, unreadable));
    expect(labelChangeFailureText(de, race), notSent(de, race));
  });
}
