import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository.dart';
import 'package:vikunja_mobile/features/projects/application/project_management.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_change_failure.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  final projects = [
    sampleProject(id: 1, title: 'Work', position: 1),
    sampleProject(id: 2, title: 'Reports', parent: 1),
    sampleProject(id: 3, title: 'Q1', parent: 2, archived: true),
    sampleProject(id: 4, title: 'Home', position: 2),
    sampleProject(id: 5, title: 'Old', archived: true),
    sampleProject(id: -2, title: 'A saved filter'),
  ];

  group('projectSubtreeIds', () {
    test('holds the project and every level below it, archived ones '
        'included', () {
      expect(projectSubtreeIds(1, projects), {1, 2, 3});
      expect(projectSubtreeIds(2, projects), {2, 3});
      expect(projectSubtreeIds(4, projects), {4});
    });

    test('ends on a parent cycle', () {
      final cycle = [
        sampleProject(id: 1, title: 'A', parent: 2),
        sampleProject(id: 2, title: 'B', parent: 1),
      ];
      expect(projectSubtreeIds(1, cycle), {1, 2});
    });
  });

  group('parentCandidates', () {
    List<int> ids(List<Project> all, {int? moved}) => [
      for (final row in parentCandidates(all, movedProjectId: moved))
        row.node.project.id,
    ];

    test('leaves out archived and pseudo projects', () {
      expect(ids(projects), [1, 2, 4]);
    });

    test('leaves out the moved project and its subprojects', () {
      expect(ids(projects, moved: 1), [4]);
      expect(ids(projects, moved: 2), [1, 4]);
    });
  });

  group('list filters', () {
    test('the web default is the switch off and nothing else', () {
      expect(splitListFilter('done = false'), (showDone: false, rest: ''));
      expect(splitListFilter(' DONE=0 '), (showDone: false, rest: ''));
      expect(joinListFilter((showDone: false, rest: '')), 'done = false');
    });

    test('no filter is the switch on', () {
      expect(splitListFilter(''), (showDone: true, rest: ''));
      expect(joinListFilter((showDone: true, rest: ' ')), '');
    });

    test('done = false joined with more takes it apart and back', () {
      const filter = 'done = false && priority >= 3';
      final parts = splitListFilter(filter);
      expect(parts, (showDone: false, rest: 'priority >= 3'));
      expect(joinListFilter(parts), filter);
    });

    test('an alternative stays in its brackets', () {
      final joined = joinListFilter((
        showDone: false,
        rest: 'priority >= 3 || labels in 4',
      ));
      expect(joined, 'done = false && (priority >= 3 || labels in 4)');
      expect(splitListFilter(joined), (
        showDone: false,
        rest: 'priority >= 3 || labels in 4',
      ));
    });

    test('an alternative without brackets is not taken apart, as its order '
        'would change', () {
      const filter = 'done = false && priority >= 3 || labels in 4';
      expect(splitListFilter(filter), (showDone: true, rest: filter));
    });

    test('two groups are not one', () {
      const filter = 'done = false && (a = 1) || (b = 2)';
      expect(splitListFilter(filter), (showDone: true, rest: filter));
    });

    test('any other filter is shown whole with the switch on', () {
      expect(splitListFilter('done = true'), (
        showDone: true,
        rest: 'done = true',
      ));
      expect(splitListFilter('priority >= 3 && done = false'), (
        showDone: true,
        rest: 'priority >= 3 && done = false',
      ));
    });
  });

  group('projectChangeFailureText', () {
    String text(Object error, [ProjectChange change = ProjectChange.edit]) =>
        projectChangeFailureText(en, error, change);

    test('a connection problem, or an answer that never came: on the '
        'project screen pull to refresh, in a form check before trying '
        'again', () {
      const timeout = NetworkFailure(NetworkProblem.timeout);
      expect(
        text(const NetworkFailure(NetworkProblem.unreachable)),
        en.projectChangeNeedsConnection,
      );
      for (final change in [
        ProjectChange.favourite,
        ProjectChange.archive,
        ProjectChange.unarchive,
        ProjectChange.delete,
      ]) {
        expect(text(timeout, change), en.projectChangeUnconfirmed);
      }
      for (final change in [
        ProjectChange.create,
        ProjectChange.edit,
        ProjectChange.editWithParent,
        ProjectChange.duplicate,
        ProjectChange.view,
      ]) {
        expect(text(timeout, change), en.projectFormUnconfirmed);
      }
    });

    test('a refused permission in the words of the change', () {
      const forbidden = Forbidden();
      expect(text(forbidden), en.projectChangeForbidden);
      expect(text(forbidden, ProjectChange.view), en.projectViewsAdminOnly);
      expect(text(forbidden, ProjectChange.delete), en.projectDeleteAdminOnly);
      expect(
        text(forbidden, ProjectChange.editWithParent),
        en.projectMoveAdminOnly,
      );
      expect(text(forbidden, ProjectChange.create), en.projectCreateForbidden);
      expect(
        text(forbidden, ProjectChange.duplicate),
        en.projectCreateForbidden,
      );
    });

    test('the server codes', () {
      expect(
        text(const DomainError(400, code: 3007)),
        en.projectIdentifierTaken,
      );
      expect(
        text(const DomainError(412, code: 3012), ProjectChange.delete),
        en.projectDeleteDefault,
      );
      expect(
        text(const DomainError(412, code: 3013), ProjectChange.archive),
        en.projectArchiveDefault,
      );
      expect(
        text(const DomainError(412, code: 3016), ProjectChange.unarchive),
        en.projectUnarchiveParentFirst,
      );
      expect(
        text(const DomainError(412, code: 3008)),
        en.projectChangeArchived,
      );
      expect(
        text(const DomainError(412, code: 3008), ProjectChange.create),
        en.projectParentArchived,
      );
      expect(
        text(const DomainError(412, code: 3011), ProjectChange.editWithParent),
        en.projectMoveNotPossible,
      );
      expect(text(const NotFound(code: 3001)), en.projectGone);
      expect(
        text(const NotFound(code: 3014), ProjectChange.view),
        en.projectViewGone,
      );
      expect(text(const ValidationFailed(code: 2002)), en.projectChangeInvalid);
      expect(
        text(const ValidationFailed(), ProjectChange.view),
        en.projectViewInvalid,
      );
    });

    test('a refused change of a project whose stored title is too long asks '
        'to shorten the title', () {
      for (final error in const [
        ValidationFailed(code: 2002),
        DomainError(412, code: 2002),
      ]) {
        expect(
          projectChangeFailureText(
            en,
            error,
            ProjectChange.favourite,
            titleTooLong: true,
          ),
          en.projectTitleTooLongToChange,
        );
      }
      expect(
        projectChangeFailureText(
          en,
          const DomainError(412, code: 3008),
          ProjectChange.favourite,
          titleTooLong: true,
        ),
        en.projectChangeArchived,
      );
    });

    test('a filter the server refuses, with its explanation', () {
      for (final code in [4024, 4019, 4016]) {
        final error = DomainError(400, code: code, message: ' Why. ');
        expect(isInvalidViewFilter(error), isTrue);
        expect(
          text(error, ProjectChange.view),
          en.projectViewFilterInvalid('Why.'),
        );
      }
      expect(isInvalidViewFilter(const DomainError(400, code: 3007)), isFalse);
    });

    test('the last view, refused before any request', () {
      expect(
        text(const LastViewNotDeletable(), ProjectChange.view),
        en.projectViewLastOne,
      );
    });

    test('another refusal with its message, else a fallback', () {
      expect(
        text(const DomainError(400, code: 9999, message: 'Boom')),
        en.projectChangeRefused('Boom'),
      );
      expect(
        text(const ServerFailure(500, message: 'Internal Server Error')),
        en.actionFailureServerError,
      );
      expect(text(const ServerFailure(500)), en.actionFailureServerError);
      expect(text(const UnexpectedResponse(502)), en.projectChangeFailed);
      expect(text(StateError('x')), en.projectChangeFailed);
    });

    group('newly mapped server codes, in English and German', () {
      for (final l10n in [en, de]) {
        String text(
          Object error, [
          ProjectChange change = ProjectChange.edit,
        ]) => projectChangeFailureText(l10n, error, change);

        test('${l10n.localeName}: a file missing from storage while '
            'duplicating', () {
          expect(
            text(const NotFound(code: 4034), ProjectChange.duplicate),
            l10n.projectDuplicateFileMissing,
          );
          expect(text(const NotFound(code: 4034)), l10n.projectGone);
          expect(
            text(const NotFound(code: 3001), ProjectChange.duplicate),
            l10n.projectGone,
          );
        });

        test('${l10n.localeName}: an archived parent while editing, '
            'unarchiving stays', () {
          const parentArchived = DomainError(412, code: 3016);
          expect(
            text(parentArchived, ProjectChange.editWithParent),
            l10n.projectParentArchived,
          );
          expect(
            text(parentArchived, ProjectChange.unarchive),
            l10n.projectUnarchiveParentFirst,
          );
        });

        test('${l10n.localeName}: an empty title', () {
          expect(
            text(const DomainError(400, code: 3005, message: 'empty')),
            l10n.projectChangeInvalid,
          );
        });

        test('${l10n.localeName}: filter codes 4017 with the server detail '
            'and 4033 in our words, both at the filter field', () {
          const comparator = DomainError(
            400,
            code: 4017,
            message: ' Invalid comparator. ',
          );
          const tooComplex = DomainError(
            400,
            code: 4033,
            message: 'The filter is too complex.',
          );
          expect(
            text(comparator, ProjectChange.view),
            l10n.projectViewFilterInvalid('Invalid comparator.'),
          );
          expect(isInvalidViewFilter(comparator), isTrue);
          expect(
            text(tooComplex, ProjectChange.view),
            l10n.filterErrorTooComplex,
          );
          expect(isInvalidViewFilter(tooComplex), isTrue);
        });

        test('${l10n.localeName}: a server error', () {
          expect(
            text(const ServerFailure(503, code: 4037, message: 'Busy')),
            l10n.actionFailureServerError,
          );
        });
      }
    });
  });
}
