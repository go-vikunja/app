import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project_list_model.dart';
import 'package:vikunja_app/domain/entities/project_page_model.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';

import '../../helpers/builders.dart';

void main() {
  group('ProjectListModel.copyWith', () {
    test('defaults isLoadingNextPage to false', () {
      expect(ProjectListModel([]).isLoadingNextPage, isFalse);
    });

    test('keeps every field when given nothing', () {
      final model = ProjectListModel([buildProject()], isLoadingNextPage: true);

      final copy = model.copyWith();

      expect(copy.projects, model.projects);
      expect(copy.isLoadingNextPage, isTrue);
    });

    test('replaces only the fields it is given', () {
      final model = ProjectListModel([buildProject(id: 1)]);

      final copy = model.copyWith(
        projects: [buildProject(id: 2)],
        isLoadingNextPage: true,
      );

      expect(copy.projects.single.id, 2);
      expect(copy.isLoadingNextPage, isTrue);
      expect(model.projects.single.id, 1);
    });
  });

  group('TaskPageModel.copyWith', () {
    final model = TaskPageModel([buildTask()], false, 3, false);

    test('keeps every field when given nothing', () {
      final copy = model.copyWith();

      expect(copy.tasks, model.tasks);
      expect(copy.onlyDueDate, isFalse);
      expect(copy.defaultProjectId, 3);
      expect(copy.isLoadingNextPage, isFalse);
    });

    test('replaces only the fields it is given', () {
      final copy = model.copyWith(onlyDueDate: true, isLoadingNextPage: true);

      expect(copy.onlyDueDate, isTrue);
      expect(copy.isLoadingNextPage, isTrue);
      expect(copy.defaultProjectId, 3);
    });

    test('can swap the task list and the default project', () {
      final copy = model.copyWith(tasks: [], defaultProjectId: 9);

      expect(copy.tasks, isEmpty);
      expect(copy.defaultProjectId, 9);
    });
  });

  group('ProjectPageModel.copyWith', () {
    final project = buildProject();
    final model = ProjectPageModel(project, 0, [buildTask()], [], false, false);

    test('keeps every field when given nothing', () {
      final copy = model.copyWith();

      expect(copy.project, same(project));
      expect(copy.viewIndex, 0);
      expect(copy.tasks, model.tasks);
      expect(copy.buckets, isEmpty);
      expect(copy.displayDoneTask, isFalse);
      expect(copy.isLoadingNextPage, isFalse);
    });

    test('replaces only the fields it is given', () {
      final other = buildProject(id: 2);

      final copy = model.copyWith(
        project: other,
        viewIndex: 1,
        buckets: [buildBucket()],
        displayDoneTask: true,
        isLoadingNextPage: true,
      );

      expect(copy.project, same(other));
      expect(copy.viewIndex, 1);
      expect(copy.buckets, hasLength(1));
      expect(copy.displayDoneTask, isTrue);
      expect(copy.isLoadingNextPage, isTrue);
      expect(copy.tasks, model.tasks);
    });
  });
}
