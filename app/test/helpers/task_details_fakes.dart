import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/links/deep_link_source.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_resolver.dart';

/// The details of tasks as the server holds them: [detailsByTask] is what
/// a read answers per task id (absent: nothing beyond the row,
/// `TaskDetails()`), [commentsByTask] every comment of a task in any
/// order, served sorted by `(created, id)` in pages of [commentsPerPage].
/// Every call is recorded in [calls] (`details 3`, `comments 3 page 1
/// oldest`, `comments 3 page 2 newest`, `markRead 3`) and every mark read
/// in [markedRead]; [beforeCall] can hold one, and [detailsFailure],
/// [commentsFailure] and [markReadFailure] (a `VikunjaFailure`, or
/// `TaskNotSyncedYet`) are thrown instead while set.
final class FakeTaskDetailsRepository implements TaskDetailsRepository {
  final Map<int, TaskDetails> detailsByTask = {};
  final Map<int, List<TaskComment>> commentsByTask = {};
  int commentsPerPage = 50;
  final List<String> calls = [];
  final List<int> markedRead = [];
  Exception? detailsFailure;
  Exception? commentsFailure;
  Exception? markReadFailure;
  Future<void> Function(String call)? beforeCall;

  @override
  Future<TaskDetails> details(int taskId) async {
    await _call('details $taskId', detailsFailure);
    return detailsByTask[taskId] ?? const TaskDetails();
  }

  @override
  Future<Page<TaskComment>> comments(
    int taskId, {
    int page = 1,
    bool newestFirst = false,
  }) async {
    await _call(
      'comments $taskId page $page ${newestFirst ? 'newest' : 'oldest'}',
      commentsFailure,
    );
    final all = [...?commentsByTask[taskId]]
      ..sort((a, b) {
        final byCreated = (a.created ?? DateTime(0)).compareTo(
          b.created ?? DateTime(0),
        );
        return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
      });
    final ordered = newestFirst ? all.reversed.toList() : all;
    final start = (page - 1) * commentsPerPage;
    return Page(
      items: start >= ordered.length
          ? const []
          : ordered.sublist(
              start,
              (start + commentsPerPage).clamp(0, ordered.length),
            ),
      page: page,
      perPage: commentsPerPage,
      totalPages: (ordered.length / commentsPerPage).ceil(),
      total: ordered.length,
    );
  }

  @override
  Future<void> markRead(int taskId) async {
    await _call('markRead $taskId', markReadFailure);
    markedRead.add(taskId);
  }

  Future<void> _call(String call, Exception? failure) async {
    calls.add(call);
    await beforeCall?.call(call);
    if (failure != null) throw failure;
  }
}

/// Resolves from the `local` tasks first (an id by `Task.id`, an
/// identifier by `Task.identifier` ignoring case), then from [online];
/// [failures] fails one reference online, and a reference found nowhere
/// fails with `NotFound` code 4002. Every reference [resolve] gets is
/// recorded in [resolved], the ones that went online in [onlineRequests],
/// and every [findLocal] in [localLookups]; [beforeResolve] can hold or
/// fail a resolve.
final class FakeTaskResolver implements TaskResolver {
  new({List<Task> Function()? local}) : _local = local ?? (() => const []);

  final List<Task> Function() _local;
  final Map<TaskReference, Task> online = {};
  final Map<TaskReference, Exception> failures = {};
  final List<TaskReference> resolved = [];
  final List<TaskReference> onlineRequests = [];
  final List<TaskReference> localLookups = [];
  Future<void> Function(TaskReference reference)? beforeResolve;

  @override
  Future<Task> resolve(TaskReference reference) async {
    resolved.add(reference);
    await beforeResolve?.call(reference);
    if (_findLocal(reference) case final task?) return task;
    onlineRequests.add(reference);
    if (failures[reference] case final failure?) throw failure;
    return online[reference] ?? (throw const NotFound(code: 4002));
  }

  @override
  Future<Task?> findLocal(TaskReference reference) async {
    localLookups.add(reference);
    return _findLocal(reference);
  }

  Task? _findLocal(TaskReference reference) => _local()
      .where(
        (task) => switch (reference) {
          TaskById(:final id) => task.id == id,
          TaskByIdentifier(:final identifier, :final index) =>
            task.identifier.toLowerCase() == '$identifier-$index'.toLowerCase(),
        },
      )
      .firstOrNull;
}

/// Attachment images by `(taskId, attachmentId, preview)`: [images] what a
/// load answers, [failures] what it throws; a key in neither fails with
/// `NotFound` code 4002 unless [fallback] is set. [peek] answers only
/// images loaded before, like the real cache. A failed load is
/// remembered until it is forgotten, a failure that cannot pass for good.
/// Every load is recorded in [loads] (`3 7 md`, `3 7 original`);
/// [beforeLoad] can hold one.
final class FakeAttachmentImages implements AttachmentImages {
  final Map<(int, int, AttachmentPreviewSize?), AttachmentImage> images = {};
  final Map<(int, int, AttachmentPreviewSize?), Exception> failures = {};
  AttachmentImage? fallback;
  final List<String> loads = [];
  Future<void> Function(String load)? beforeLoad;
  final _loaded = <(int, int, AttachmentPreviewSize?)>{};
  final _failed = <(int, int, AttachmentPreviewSize?), Object>{};

  @override
  Future<AttachmentImage> load(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) async {
    final description =
        '$taskId $attachmentId ${preview?.wireName ?? 'original'}';
    loads.add(description);
    await beforeLoad?.call(description);
    final key = (taskId, attachmentId, preview);
    final image = images[key] ?? fallback;
    final failure =
        failures[key] ?? (image == null ? const NotFound(code: 4002) : null);
    if (failure != null) {
      _failed[key] = failure;
      throw failure;
    }
    _failed.remove(key);
    _loaded.add(key);
    return image!;
  }

  @override
  bool remembersFailure(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) => _failed.containsKey((taskId, attachmentId, preview));

  @override
  void forgetFailure(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) {
    final key = (taskId, attachmentId, preview);
    if (_failed[key] case final failure?
        when attachmentImageFailureMayPass(failure)) {
      _failed.remove(key);
    }
  }

  @override
  void forgetFailures() => _failed.removeWhere(
    (_, failure) => attachmentImageFailureMayPass(failure),
  );

  @override
  AttachmentImage? peek(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) {
    final key = (taskId, attachmentId, preview);
    return _loaded.contains(key) ? images[key] ?? fallback : null;
  }
}

/// [initial] is answered once by [initialLink]; [push] delivers a link
/// while the app runs.
final class FakeDeepLinkSource implements DeepLinkSource {
  new({this.initial});

  Uri? initial;
  final controller = StreamController<Uri>.broadcast();
  int initialLinkCalls = 0;

  @override
  Future<Uri?> initialLink() async {
    initialLinkCalls++;
    final link = initial;
    initial = null;
    return link;
  }

  @override
  Stream<Uri> get links => controller.stream;

  void push(Uri uri) => controller.add(uri);
}

/// A 1×1 PNG that `Image.memory` decodes.
final Uint8List samplePngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMwTpv5HwAE'
  'NAIyWy0K4AAAAABJRU5ErkJggg==',
);

final AttachmentImage samplePngImage = AttachmentImage(
  bytes: samplePngBytes,
  contentType: 'image/png',
);

/// What the server answers for an SVG, which it cannot preview.
final AttachmentImage sampleSvgImage = AttachmentImage(
  bytes: utf8.encode(
    '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>',
  ),
  contentType: 'image/svg+xml',
);
