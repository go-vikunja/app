import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';

import '../contract/helpers.dart';
import '../helpers/fake_sync_client.dart';
import '../helpers/fake_write_client.dart';

/// What the parity scenarios run against: the signed-in user [me], the read
/// client the app syncs through, and the server's own write client
/// ([server]), which seeds each case and plays another device; the app's
/// writes reach it through a `FlakyWriteClient`.
abstract interface class ParityBackend {
  String get name;
  User get me;
  VikunjaReadClient get read;
  VikunjaWriteClient get server;
  int get perPage;
  CurrentUserSource get currentUser;

  /// Waits for what the server still does after it answered, such as the
  /// `updated` bump of a comment; nothing on the fakes.
  Future<void> settle();
}

/// The unit tests' two fakes joined into one server: before every read the
/// read fake is given what the write fake holds, as that server would show
/// it to [me], the owner of every project and the creator, uploader and
/// author of everything written.
final class FakeBackend implements ParityBackend {
  new() {
    writes
      ..creator = me
      ..uploader = me
      ..commenter = me
      ..serverUsers[me.id] = me;
    reads.beforeRequest = (_) async => _mirror();
  }

  final FakeWriteClient writes = FakeWriteClient();
  final FakeSyncClient reads = FakeSyncClient();

  @override
  String get name => 'fakes';

  @override
  User get me => const User(id: 1, username: 'me', name: 'Me');

  @override
  VikunjaReadClient get read => reads;

  @override
  VikunjaWriteClient get server => writes;

  @override
  int get perPage => reads.maxPerPage;

  @override
  CurrentUserSource get currentUser =>
      () async => (user: me, settings: const UserSettings());

  @override
  Future<void> settle() async {}

  void _mirror() {
    Reactions reactionsOf(ReactionEntity kind, int id) =>
        writes.serverReactions[(kind, id)] ?? const {};
    int commentsOf(int taskId) => writes.serverComments[taskId]?.length ?? 0;
    reads
      ..currentUser = me
      // The write fake's projects carry no permission and no owner.
      ..allProjects = [
        for (final project in writes.serverProjects.values)
          project.copyWith(owner: me, maxPermission: Permission.admin),
      ]
      ..allLabels = [...writes.serverLabels.values]
      ..allTasks = [
        for (final task in writes.serverTasks.values)
          task.copyWith(commentCount: commentsOf(task.id)),
      ];
    reads.taskComments
      ..clear()
      ..addAll({
        for (final MapEntry(key: taskId, value: comments)
            in writes.serverComments.entries)
          taskId: [
            for (final comment in comments)
              comment.copyWith(
                reactions: reactionsOf(ReactionEntity.comment, comment.id),
              ),
          ],
      });
    reads.taskDetails
      ..clear()
      ..addAll({
        for (final task in writes.serverTasks.values)
          task.id: TaskDetails(
            attachments: [...?writes.serverAttachments[task.id]],
            coverImageAttachmentId: writes.covers[task.id] ?? 0,
            reactions: reactionsOf(ReactionEntity.task, task.id),
            commentCount: commentsOf(task.id),
            maxPermission: Permission.admin,
          ),
      });
    reads.attachmentBlobs
      ..clear()
      ..addAll({
        for (final MapEntry(key: taskId, value: attachments)
            in writes.serverAttachments.entries)
          for (final attachment in attachments)
            (taskId, attachment.id, null): AttachmentBlob(
              bytes: Uint8List.fromList(
                writes.uploadedBytes[attachment.id] ?? const [],
              ),
              contentType: attachment.mime,
            ),
      });
  }
}

/// A fresh user of the local test server, reached through one API version.
final class ServerBackend implements ParityBackend {
  new _({
    required this.name,
    required this.me,
    required this.read,
    required this.server,
    required this.perPage,
    required this.currentUser,
  });

  static Future<ServerBackend> register(
    Dio dio,
    ServerConnection connection,
    ApiVersion version,
  ) async {
    final user = await registerAndLogin(dio, connection);
    final only = onlyApiVersion(connection, version);
    final authenticated = createAuthenticatedDio(
      base: dio,
      connection: only,
      tokens: StaticJwt(user.jwt),
    );
    return ServerBackend._(
      name: 'server over ${version.pathSegment}',
      me: User(id: user.id, username: user.username),
      read: createReadClient(dio: authenticated, connection: only),
      server: createWriteClient(dio: authenticated, connection: only),
      perPage: only.info.maxItemsPerPage,
      currentUser: AccountApi(authenticated, only).currentUserWithSettings,
    );
  }

  @override
  final String name;

  @override
  final User me;

  @override
  final VikunjaReadClient read;

  @override
  final VikunjaWriteClient server;

  @override
  final int perPage;

  @override
  final CurrentUserSource currentUser;

  @override
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 500));
}

/// Seeding and reading back through [ParityBackend.server] and
/// [ParityBackend.read], as another device would.
extension ParitySeeding on ParityBackend {
  Future<int> seedProject(String title) async => (await despiteWriteRaces(
    () => server.projects.create(NewProject(title: title)),
  )).id;

  Future<int> seedTask(NewTask task) async =>
      (await despiteWriteRaces(() => server.tasks.create(task))).id;

  /// Every task of the project on the server, from all pages.
  Future<List<Task>> serverTasksIn(int projectId) async {
    final all = <Task>[];
    for (var page = 1; ; page++) {
      final current = await read.tasks.listInProject(
        projectId,
        TaskQuery(page: page),
      );
      all.addAll(current.items);
      if (!current.hasMore) return all;
    }
  }

  /// The ids of the server's labels titled exactly [title].
  Future<List<int>> serverLabelsTitled(String title) async => [
    for (final label in await read.labels.listAll())
      if (label.title == title) label.id,
  ];
}
