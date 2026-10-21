import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository_providers.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/attachments/presentation/attachment_messages.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/file_size_text.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_drafts.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_bridge.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:vikunja_mobile/features/description_editor/application/mention_suggestions.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/editor_theme.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/editor_toolbar.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/link_sheet.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/mention_bar.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/webview_editor_bridge.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_change_failure.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart'
    show taskByIdProvider;
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_messages.dart';

final _log = Logger('DescriptionEditor');

enum _Leave { save, discard }

enum _Changed { overwrite, reload }

/// How a write ended.
sealed class _Outcome {
  const new();
}

final class _Saved extends _Outcome {
  const new();
}

/// The page has said why.
final class _Refused extends _Outcome {
  const new();
}

/// The server's description is no longer the one the edit started from,
/// it is [current]; nothing was written.
final class _ChangedOnWeb extends _Outcome {
  const new(this.current);

  final String current;
}

/// The description as it is stored now and the project whose people can
/// be mentioned in it.
typedef _Subject = ({String description, int projectId});

/// Edits a task's or a project's description, or the user's own comment,
/// in the bundled web editor. The editor starts from the description as it
/// was when the page opened; Save writes only when the editor reports a
/// change, and asks first when the description changed meanwhile. Pops
/// with true once saved, with the stored `TaskComment` for a comment.
///
/// The edit itself lives in the WebView, so the page keeps a copy of it a
/// moment after each change: when the WebView's process ends, Reload goes
/// on from that copy, and when the app goes to the background it is kept
/// as a draft that a later editor for the same description offers back.
///
/// A task's description can take images while online: each is uploaded as
/// an attachment of the task first and then inserted the way the web
/// writes it; the page shows it as a placeholder, like every image.
class DescriptionEditorPage extends ConsumerStatefulWidget {
  const new({required this.target, super.key});

  static const loadTimeout = Duration(seconds: 20);
  static const copyDelay = Duration(seconds: 1);
  static const draftTimeout = Duration(seconds: 2);

  final DescriptionTarget target;

  /// The space the suggestions take of [available], what the body leaves
  /// between the app bar and the keyboard, so that the editor keeps about
  /// [editorMinHeight] and never less than half of what the toolbar leaves.
  @visibleForTesting
  static double mentionBarMaxHeight({
    required double available,
    required double toolbarHeight,
    required double editorMinHeight,
  }) {
    final remaining = math.max(0, available - toolbarHeight).toDouble();
    return (remaining - editorMinHeight).clamp(
      math.min(48, remaining / 2),
      remaining / 2,
    );
  }

  @override
  ConsumerState<DescriptionEditorPage> createState() =>
      _DescriptionEditorPageState();
}

class _DescriptionEditorPageState extends ConsumerState<DescriptionEditorPage> {
  late final _mentions = MentionController(
    search: _searchPeople,
    known: _knownPeople,
  )..addListener(_announceSuggestions);
  late final DescriptionDrafts _drafts = ref.read(descriptionDraftsProvider);
  late final AppLifecycleListener _lifecycle;
  EditorBridge? _bridge;
  StreamSubscription<EditorEvent>? _events;
  Timer? _loadTimer;
  Timer? _copyTimer;

  /// The description the edit started from: what Save compares the stored
  /// one with and sends as its base.
  String? _opened;

  /// The comment as the server stored the edit.
  TaskComment? _savedComment;

  /// What this page load started from when that is not [_opened]: the
  /// copy of an edit after the WebView stopped, or a draft. It counts as a
  /// change even while the page reports none.
  String? _restored;

  /// The latest copy of the edit, null while there is none.
  String? _copy;
  String? _account;
  int? _projectId;
  EditorTheme? _theme;
  var _starting = false;
  var _ready = false;
  var _failed = false;
  var _stopped = false;
  var _saving = false;
  var _closing = false;
  var _gone = false;
  var _editingLink = false;
  var _searching = false;
  var _pickingImage = false;
  CancelToken? _imageUpload;

  /// What the current page load recognises attachment images by.
  EditorLinks? _links;
  var _state = const EditorState();

  bool get _unsaved =>
      _ready ? _state.dirty || _restored != null : _copy != null;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: () => unawaited(_keepDraft()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTheme();
  }

  @override
  void dispose() {
    _imageUpload?.cancel();
    _lifecycle.dispose();
    _copyTimer?.cancel();
    _stop();
    _mentions.dispose();
    if (_account case final account?) {
      unawaited(
        _drafts
            .discard(account: account, target: widget.target)
            .catchError(
              (Object error) => _log.warning(
                'Dropping the draft failed: ${error.runtimeType}',
              ),
            ),
      );
    }
    super.dispose();
  }

  AsyncValue<_Subject?> _watchSubject() => switch (widget.target) {
    TaskDescriptionTarget(:final taskId) =>
      ref
          .watch(taskByIdProvider(taskId))
          .whenData(
            (task) => task == null
                ? null
                : (description: task.description, projectId: task.projectId),
          ),
    ProjectDescriptionTarget(:final projectId) =>
      ref.watch(projectsProvider).whenData((projects) {
        for (final project in projects) {
          if (project.id == projectId) {
            return (description: project.description, projectId: projectId);
          }
        }
        return null;
      }),
    CommentTarget(:final comment, :final projectId) => AsyncValue.data((
      description: comment.html,
      projectId: projectId,
    )),
  };

  String? _storedDescription() => switch (widget.target) {
    TaskDescriptionTarget(:final taskId) =>
      ref.read(taskByIdProvider(taskId)).value?.description,
    ProjectDescriptionTarget(:final projectId) =>
      ref.read(projectByIdProvider(projectId))?.description,
    CommentTarget(:final comment) => comment.html,
  };

  void _stop() {
    _loadTimer?.cancel();
    unawaited(_events?.cancel());
    _bridge?.dispose();
    _bridge = null;
  }

  /// Offers a draft the app kept for this description before starting
  /// from [stored].
  Future<void> _open(String stored) async {
    final account = _account = ref.read(activeAccountIdProvider);
    DescriptionDraft? draft;
    if (account != null) {
      try {
        draft = await _drafts.read(account: account, target: widget.target);
      } on Object catch (error) {
        _log.warning('Reading the draft failed: ${error.runtimeType}');
      }
    }
    if (!mounted) return;
    if (draft == null || draft.html == stored) {
      _start(stored);
      return;
    }
    final restore = await _askToRestore();
    if (!mounted) return;
    if (restore ?? false) {
      _start(draft.base, restored: draft.html);
    } else {
      _start(stored);
    }
  }

  /// A fresh page load of the edit that started from [opened]: [restored]
  /// when given, else [opened] itself. A reload throws away what the old
  /// load held.
  void _start(String opened, {String? restored}) {
    _stop();
    _copyTimer?.cancel();
    _mentions.end();
    final bridge = ref.read(editorBridgeFactoryProvider)();
    final theme = editorThemeOf(context);
    final links = _links = editorLinksOf(ref.read(activeLinkBasesProvider));
    final l10n = context.l10n;
    setState(() {
      _bridge = bridge;
      _opened = opened;
      _restored = restored;
      _copy = restored;
      _theme = theme;
      _ready = false;
      _failed = false;
      _stopped = false;
      _state = const EditorState();
    });
    _events = bridge.events.listen(_onEvent);
    _loadTimer = Timer(DescriptionEditorPage.loadTimeout, _fail);
    unawaited(
      bridge
          .start(
            EditorInit(
              html: restored ?? opened,
              theme: theme,
              placeholder: widget.target is CommentTarget
                  ? l10n.commentComposerHint
                  : l10n.descriptionEditorPlaceholder,
              label: _title(l10n),
              imageLabel: l10n.descriptionEditorImage,
              locale: Localizations.localeOf(context).toLanguageTag(),
              links: links,
            ),
            background: Theme.of(context).colorScheme.surface,
          )
          .catchError((Object error) {
            _log.warning('The editor did not load: ${error.runtimeType}');
            _fail();
          }),
    );
  }

  void _fail() {
    _loadTimer?.cancel();
    if (mounted && !_ready) setState(() => _failed = true);
  }

  void _onEvent(EditorEvent event) {
    if (!mounted) return;
    switch (event) {
      case EditorReady():
        _loadTimer?.cancel();
        setState(() => _ready = true);
        _syncTheme();
        unawaited(_bridge?.focus());
      case EditorStateChanged(:final state):
        setState(() => _state = state);
        _copyTimer?.cancel();
        if (state.dirty) {
          _copyTimer = Timer(DescriptionEditorPage.copyDelay, _takeCopy);
        } else {
          _copy = _restored;
        }
      case MentionQuery(:final query):
        _mentions.query(query);
      case MentionEnd():
        _mentions.end();
      case EditorStopped():
        _copyTimer?.cancel();
        _mentions.end();
        setState(() {
          _ready = false;
          _failed = true;
          _stopped = true;
          _saving = false;
          _state = const EditorState();
        });
      case EditorFailed():
        if (_ready) {
          _log.warning('The editor reported a failure');
        } else {
          _fail();
        }
      case EditorHtml():
        break;
    }
  }

  Future<void> _takeCopy() async {
    final bridge = _bridge;
    if (bridge == null || !_ready) return;
    try {
      final document = await bridge.html();
      if (!mounted || !identical(bridge, _bridge) || !_ready) return;
      _copy = document.dirty ? document.html : _restored;
    } on Object catch (error) {
      _log.fine('Copying the edit failed: ${error.runtimeType}');
    }
  }

  /// Keeps the edit when the app leaves the screen: the system may end it
  /// in the background, and with it the WebView.
  Future<void> _keepDraft() async {
    final opened = _opened;
    final account = _account;
    if (opened == null || account == null || _closing || !_unsaved) return;
    var html = _copy;
    final bridge = _bridge;
    if (_ready && bridge != null) {
      try {
        final document = await bridge.html().timeout(
          DescriptionEditorPage.draftTimeout,
        );
        html = document.dirty ? document.html : _restored;
      } on Object catch (error) {
        _log.fine('Reading the edit for a draft failed: ${error.runtimeType}');
      }
    }
    if (html == null || !mounted || _closing) return;
    try {
      await _drafts.save(
        DescriptionDraft(html: html, base: opened),
        account: account,
        target: widget.target,
      );
    } on Object catch (error) {
      _log.warning('Keeping the draft failed: ${error.runtimeType}');
    }
  }

  void _announceSuggestions() {
    final suggestions = _mentions.value;
    final arrived = _searching && suggestions.active && !suggestions.searching;
    _searching = suggestions.searching;
    if (!arrived || suggestions.people.isEmpty || !mounted) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.editorMentionsFound(suggestions.people.length),
        Directionality.of(context),
      ),
    );
  }

  void _syncTheme() {
    final bridge = _bridge;
    if (bridge == null || !_ready) return;
    final theme = editorThemeOf(context);
    if (theme == _theme) return;
    _theme = theme;
    unawaited(bridge.setTheme(theme));
  }

  void _command(EditorCommand command) => unawaited(_bridge?.command(command));

  /// The link at the cursor, with its address, or a new one.
  Future<void> _editLink() async {
    if (_editingLink) return;
    _editingLink = true;
    final active = _state.active;
    final LinkEdit? edit;
    try {
      edit = await showLinkSheet(
        context,
        href: active.link ? active.linkHref ?? '' : '',
        hasLink: active.link,
      );
    } finally {
      _editingLink = false;
    }
    final bridge = _bridge;
    if (!mounted || bridge == null) return;
    switch (edit) {
      case SetLink(:final href):
        await bridge.command(EditorCommand.setLink(href));
      case RemoveLink():
        await bridge.command(const EditorCommand(EditorCommandName.unsetLink));
      case null:
        break;
    }
    await bridge.focus();
  }

  /// The task an image would be attached to: online, on the server
  /// already, outside archived projects, on a server that takes
  /// attachments; null otherwise and for a project's description.
  int? _imageTaskId() {
    if (widget.target case TaskDescriptionTarget(:final taskId)) {
      final task = ref.watch(taskByIdProvider(taskId)).value;
      final attachments = ref.watch(attachmentRepositoryProvider);
      if (task == null ||
          task.id <= 0 ||
          !(attachments?.uploadsEnabled ?? false) ||
          ref.watch(offlineProvider) != null) {
        return null;
      }
      final projects = ref.watch(projectsProvider).value ?? const <Project>[];
      final byId = {for (final project in projects) project.id: project};
      return isArchivedInTree(task.projectId, byId) ? null : task.id;
    }
    return null;
  }

  /// Picks one image, uploads it to the task and inserts it at the cursor;
  /// leaving the page cancels the upload. The picker's copy goes either
  /// way.
  Future<void> _insertImage(AttachmentSource source, int taskId) async {
    final attachments = ref.read(attachmentRepositoryProvider);
    final bridge = _bridge;
    if (attachments == null ||
        bridge == null ||
        _pickingImage ||
        _imageUpload != null) {
      return;
    }
    final l10n = context.l10n;
    _pickingImage = true;
    final PickedFiles pick;
    try {
      pick = await ref
          .read(attachmentPickerProvider)
          .pick(
            source,
            maxBytes: attachments.maxUploadBytes,
            imagesOnly: true,
            multiple: false,
          );
    } on Object catch (error) {
      _log.warning('Picking an image failed: ${error.runtimeType}');
      if (mounted) _showMessage(l10n.attachmentPickFailed);
      return;
    } finally {
      _pickingImage = false;
    }
    final picked = pick.files.firstOrNull;
    if (picked == null) {
      if (!mounted) return;
      if (pick.tooLarge.isNotEmpty) {
        _showMessage(
          l10n.attachmentFileTooLargeLimit(
            formatFileSize(l10n, attachments.maxUploadBytes),
          ),
        );
      } else if (pick.failed.isNotEmpty) {
        _showMessage(l10n.attachmentPickFailed);
      }
      return;
    }
    if (!mounted) {
      unawaited(_deletePicked(picked));
      return;
    }
    final cancel = CancelToken();
    setState(() => _imageUpload = cancel);
    try {
      final attachment = await attachments.uploadNow(
        taskId,
        File(picked.path),
        fileName: safeFileName(picked.name),
        mimeType: picked.mimeType,
        cancel: cancel,
      );
      final links = _links;
      if (!mounted || !identical(bridge, _bridge) || !_ready || links == null) {
        return;
      }
      await bridge.command(
        EditorCommand.insertImage(
          src: attachmentImageSrc(
            links,
            taskId: attachment.taskId,
            attachmentId: attachment.id,
          ),
          id: attachmentImageId(
            taskId: attachment.taskId,
            attachmentId: attachment.id,
          ),
        ),
      );
      if (!mounted) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          l10n.editorImageInserted,
          Directionality.of(context),
        ),
      );
    } on Object catch (error) {
      if (cancel.isCancelled) return;
      _log.warning('Uploading an image failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) _showMessage(attachmentFailureText(l10n, error));
    } finally {
      unawaited(_deletePicked(picked));
      if (mounted) setState(() => _imageUpload = null);
    }
  }

  static Future<void> _deletePicked(PickedFile picked) async {
    try {
      final file = File(picked.path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error) {
      _log.info('Could not delete a picked image: ${error.osError?.errorCode}');
    }
  }

  Future<List<User>> _searchPeople(String query) {
    final users = ref.read(userRepositoryProvider);
    final projectId = _projectId;
    if (users == null || projectId == null) {
      return Future.error(const NetworkFailure(NetworkProblem.unreachable));
    }
    return users.searchAssignees(projectId, query);
  }

  Future<List<User>> _knownPeople() async =>
      await ref.read(userRepositoryProvider)?.knownUsers() ?? const [];

  void _mention(User user) {
    _mentions.end();
    unawaited(
      _bridge?.insertMention(
        EditorMention(username: user.username, label: user.displayName),
      ),
    );
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    final opened = _opened;
    final bridge = _ready ? _bridge : null;
    final copy = _copy;
    if (opened == null || _saving || (bridge == null && copy == null)) return;
    final l10n = context.l10n;
    setState(() => _saving = true);
    final String html;
    if (bridge != null) {
      final EditorDocument document;
      try {
        // Whatever is typed after the answer would be lost on closing.
        await bridge.setReadOnly(readOnly: true);
        document = await bridge.html();
      } on Object catch (error) {
        _log.warning(
          'Reading the edited description failed: '
          '${error.runtimeType}',
        );
        if (!mounted) return;
        _resume();
        _showMessage(l10n.descriptionEditorSaveFailed);
        return;
      }
      if (!mounted) return;
      // The page's state may lag behind its document; this answer does not.
      // A clean editor's HTML can still differ from the stored one,
      // normalised the way the web would on its next save; writing it is no
      // edit.
      if (!document.dirty && _restored == null) {
        _close(saved: false);
        return;
      }
      html = document.html;
    } else {
      html = copy!;
    }
    if (unchangedDescription(opened, html)) {
      _close(saved: false);
      return;
    }
    var base = opened;
    var changed = switch (_storedDescription()) {
      final stored? when stored != opened => stored,
      _ => null,
    };
    for (;;) {
      if (changed != null) {
        setState(() => _saving = false);
        final choice = await _askAboutChange();
        if (!mounted) return;
        switch (choice) {
          case null:
            _resume();
            return;
          case _Changed.reload:
            _start(changed);
            return;
          case _Changed.overwrite:
            base = changed;
            setState(() => _saving = true);
        }
      }
      final outcome = await _write(html, base: base);
      if (!mounted) return;
      switch (outcome) {
        case _Saved():
          _close(saved: true);
          return;
        case _Refused():
          _resume();
          return;
        case _ChangedOnWeb(:final current):
          changed = current;
      }
    }
  }

  /// Back to editing after a save that did not close the page.
  void _resume() {
    setState(() => _saving = false);
    final bridge = _bridge;
    if (!_ready || bridge == null) return;
    unawaited(bridge.setReadOnly(readOnly: false).then((_) => bridge.focus()));
  }

  /// The task's change goes through the outbox and never fails for
  /// network reasons; the project's goes to the server and may.
  Future<_Outcome> _write(String html, {required String base}) async {
    final l10n = context.l10n;
    try {
      switch (widget.target) {
        case TaskDescriptionTarget(:final taskId):
          final repository = ref.read(taskRepositoryProvider);
          if (repository == null) return const _Refused();
          // A queued create may have been answered while editing.
          final id = ref.read(taskByIdProvider(taskId)).value?.id ?? taskId;
          if (!await repository.updateDescription(id, html, base: base)) {
            if (mounted) _showMessage(l10n.taskEditGoneBody);
            return const _Refused();
          }
        case ProjectDescriptionTarget(:final projectId):
          final repository = ref.read(projectRepositoryProvider);
          if (repository == null) return const _Refused();
          final current = await repository.updateDescription(
            projectId,
            html,
            base: base,
          );
          if (current != null) return _ChangedOnWeb(current);
        case CommentTarget(:final taskId, :final comment):
          final repository = ref.read(taskDetailsRepositoryProvider);
          if (repository == null) return const _Refused();
          // The server would store whitespace; the web sends no empty edit.
          if (parseRichText(
            html,
            apiRoot: Uri(),
            taskLinkBases: const [],
          ).isEmpty) {
            _showMessage(l10n.commentEmptyRefused);
            return const _Refused();
          }
          _savedComment = await repository.editComment(
            taskId,
            comment,
            CommentDraft(html),
          );
      }
      return const _Saved();
    } on Object catch (error) {
      _log.warning('Saving a description failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) {
        _showMessage(switch (widget.target) {
          TaskDescriptionTarget() => l10n.descriptionEditorSaveFailed,
          ProjectDescriptionTarget() => projectChangeFailureText(
            l10n,
            error,
            ProjectChange.edit,
          ),
          CommentTarget() => commentFailureText(l10n, error, CommentWrite.save),
        });
      }
      return const _Refused();
    }
  }

  void _close({required bool saved}) {
    setState(() => _closing = true);
    GoRouter.of(context).pop(saved ? _savedComment ?? true : false);
  }

  /// Null keeps editing: both other choices lose one of the two changes.
  Future<_Changed?> _askAboutChange() {
    final l10n = context.l10n;
    return showAdaptiveDialog<_Changed>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog.adaptive(
        scrollable: true,
        title: Text(l10n.descriptionEditorChangedTitle),
        content: Text(l10n.descriptionEditorChangedBody),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.taskEditKeepEditing),
          ),
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(_Changed.reload),
            isDestructive: true,
            child: Text(l10n.descriptionEditorReload),
          ),
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(_Changed.overwrite),
            isDestructive: true,
            child: Text(l10n.descriptionEditorOverwrite),
          ),
        ],
      ),
    );
  }

  Future<bool?> _askToRestore() {
    final l10n = context.l10n;
    return showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        scrollable: true,
        title: Text(l10n.descriptionEditorRestoreTitle),
        content: Text(l10n.descriptionEditorRestoreBody),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            isDestructive: true,
            child: Text(l10n.taskEditDiscard),
          ),
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.descriptionEditorRestore),
          ),
        ],
      ),
    );
  }

  /// Without Save when the description has gone meanwhile.
  Future<void> _confirmLeave() async {
    if (_saving || _closing) return;
    final l10n = context.l10n;
    final choice = await showAdaptiveDialog<_Leave>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        scrollable: true,
        title: Text(l10n.descriptionEditorLeaveTitle),
        content: Text(l10n.descriptionEditorLeaveBody),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.taskEditKeepEditing),
          ),
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(_Leave.discard),
            isDestructive: true,
            child: Text(l10n.taskEditDiscard),
          ),
          if (!_gone)
            AdaptiveDialogAction(
              onPressed: () => Navigator.of(context).pop(_Leave.save),
              child: Text(l10n.taskEditSave),
            ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _Leave.save:
        await _save();
      case _Leave.discard:
        _close(saved: false);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final subject = _watchSubject();
    if (subject.value case final subject?) {
      _projectId = subject.projectId;
      if (_opened == null && !_starting) {
        _starting = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_open(subject.description));
        });
      }
    }
    final bridge = _bridge;
    final gone = _gone = subject.hasValue && subject.value == null && !_closing;
    final unsaved = _unsaved;
    final imageTaskId = _imageTaskId();
    final uploadingImage = _imageUpload != null;

    return PopScope(
      canPop: _closing || !unsaved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title(l10n)),
          actions: [
            TextButton(
              // The image goes in first.
              onPressed: unsaved && !_saving && !gone && !uploadingImage
                  ? () => unawaited(_save())
                  : null,
              child: Text(l10n.taskEditSave),
            ),
            const SizedBox(width: 8),
          ],
          bottom: _saving || uploadingImage
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: Semantics(
                    liveRegion: uploadingImage,
                    label: uploadingImage ? l10n.editorImageUploading : null,
                    child: const LinearProgressIndicator(),
                  ),
                )
              : null,
        ),
        body: gone
            ? CenteredScrollView(
                child: switch (widget.target) {
                  TaskDescriptionTarget() => EmptyState(
                    icon: Icons.search_off,
                    title: l10n.taskEditGoneTitle,
                    body: l10n.taskEditGoneBody,
                  ),
                  ProjectDescriptionTarget() => EmptyState(
                    icon: Icons.search_off,
                    title: l10n.projectGoneTitle,
                    body: l10n.projectGoneBody,
                  ),
                  // Never gone: the page holds the comment itself.
                  CommentTarget() => const SizedBox.shrink(),
                },
              )
            : LayoutBuilder(
                builder: (context, constraints) => Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (bridge != null)
                            KeyedSubtree(
                              key: ObjectKey(bridge),
                              child: bridge.buildView(context),
                            ),
                          if (_failed)
                            ColoredBox(
                              color: colors.surface,
                              child: CenteredScrollView(
                                child: _LoadFailure(
                                  message: !_stopped
                                      ? l10n.descriptionEditorFailed
                                      : _copy != null
                                      ? l10n.descriptionEditorStoppedKept
                                      : l10n.descriptionEditorStoppedLost,
                                  action: _stopped
                                      ? l10n.descriptionEditorReload
                                      : l10n.retry,
                                  onRetry: () =>
                                      _start(_opened ?? '', restored: _copy),
                                ),
                              ),
                            )
                          else if (!_ready)
                            ColoredBox(
                              color: colors.surface,
                              child: CenteredScrollView(
                                child: LoadingPlaceholder(
                                  label: l10n.descriptionEditorLoading,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _mentions,
                      builder: (context, suggestions, _) => suggestions.active
                          ? MentionBar(
                              suggestions: suggestions,
                              onPick: _mention,
                              maxHeight:
                                  DescriptionEditorPage.mentionBarMaxHeight(
                                    available: constraints.maxHeight,
                                    toolbarHeight: EditorToolbar.heightOf(
                                      context,
                                    ),
                                    editorMinHeight: _editorMinHeight(
                                      _theme?.fontScale ?? 1,
                                    ),
                                  ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    EditorToolbar(
                      state: _state,
                      enabled: _ready && !_saving,
                      onCommand: _command,
                      onLink: () => unawaited(_editLink()),
                      onImage: imageTaskId == null
                          ? null
                          : (source) =>
                                unawaited(_insertImage(source, imageTaskId)),
                      imageEnabled: !uploadingImage,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _title(AppLocalizations l10n) => widget.target is CommentTarget
      ? l10n.commentEditorTitle
      : l10n.descriptionEditorTitle;

  /// About two lines of the page's text (16 px at line height 1.5) below
  /// its top padding.
  static double _editorMinHeight(double fontScale) => 12 + 2 * 24 * fontScale;
}

class _LoadFailure extends StatelessWidget {
  const new({
    required this.message,
    required this.action,
    required this.onRetry,
  });

  final String message;
  final String action;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline,
              size: 56,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}
