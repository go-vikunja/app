import 'package:background_downloader/background_downloader.dart'
    show TaskStatusUpdate;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/pages/home_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';

class MockTaskRepository implements TaskRepository {
  Future<Response<Task>> Function(int id)? getTaskStub;

  @override
  Future<Response<Task>> getTask(int id) => getTaskStub!(id);

  @override
  Future<Response<Task>> add(int projectId, Task task) {
    throw UnimplementedError();
  }

  @override
  Future delete(int taskId) {
    throw UnimplementedError();
  }

  @override
  Future<Response<Task>> update(Task task) {
    throw UnimplementedError();
  }

  @override
  Future<Response<List<Task>>> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) {
    throw UnimplementedError();
  }

  @override
  Future<Response<List<Task>>> getAllByProjectView(
    int projectId,
    int view, [
    Map<String, List<String>>? queryParameters,
  ]) {
    throw UnimplementedError();
  }

  @override
  Future<Response<List<Task>>> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]) {
    throw UnimplementedError();
  }

  @override
  Future<TaskStatusUpdate> downloadAttachment(
    int taskId,
    TaskAttachment attachment,
  ) {
    throw UnimplementedError();
  }
}

class MockTaskPageController extends TaskPageController {
  final TaskPageModel model;
  MockTaskPageController(this.model);

  @override
  Future<TaskPageModel> build() async => model;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('vikunja');
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Task buildTask({int id = 42}) {
    return Task(
      id: id,
      title: 'Widget Task $id',
      // A set priority: null would trip a debug-only assert inside
      // TaskEditPage's priority dropdown (pre-existing, release-stripped).
      priority: 1,
      createdBy: User(username: 'testuser'),
      projectId: 1,
    );
  }

  Future<void> pumpHome(WidgetTester tester, MockTaskRepository taskRepo) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepo),
          taskPageControllerProvider.overrideWith(
            () => MockTaskPageController(
              TaskPageModel(<Task>[], false, 1, false),
            ),
          ),
        ],
        child: MaterialApp(
          home: const HomePage(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
  }

  setUp(() {
    // Deny the notification permission so HomePage skips notification setup.
    messenger.setMockMethodCallHandler(permissionsChannel, (call) async {
      return 0;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(permissionsChannel, null);
  });

  testWidgets(
    'pending open_task launch (cold start) opens the task detail page',
    (WidgetTester tester) async {
      final task = buildTask(id: 42);
      final taskRepo = MockTaskRepository();
      taskRepo.getTaskStub = (id) async => SuccessResponse(task, 200, {});

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isQuickTile') {
          return {'method': 'open_task', 'argument': '42'};
        }
        return null;
      });

      await pumpHome(tester, taskRepo);
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditPage), findsOneWidget);
      expect(find.text('Widget Task 42'), findsWidgets);
    },
  );

  testWidgets(
    'open_task method call while the app runs (warm) opens the task detail page',
    (WidgetTester tester) async {
      final task = buildTask(id: 7);
      final taskRepo = MockTaskRepository();
      taskRepo.getTaskStub = (id) async => SuccessResponse(task, 200, {});

      messenger.setMockMethodCallHandler(channel, (call) async {
        // No pending launch: MainActivity would answer with an error.
        throw PlatformException(code: '1');
      });

      await pumpHome(tester, taskRepo);
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditPage), findsNothing);

      // Native side invokes "open_task" when onNewIntent fires.
      final message = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('open_task', '7'),
      );
      await messenger.handlePlatformMessage(
        'vikunja',
        message,
        (ByteData? data) {},
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditPage), findsOneWidget);
    },
  );
}
