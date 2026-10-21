import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/storage/comment_drafts.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/description_editor/application/mention_suggestions.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/mention_bar.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_text_controller.dart';

/// The comment a reply quotes.
@immutable
final class ComposerReply {
  const new({
    required this.commentId,
    required this.html,
    required this.authorName,
  });

  final int commentId;

  /// The quoted comment's HTML, untrusted.
  final String html;
  final String authorName;
}

/// What the composer at the bottom of the task sheet holds: the text with
/// its mentions, the comment it replies to, whether it is sending, and
/// the field's focus, which Reply moves there.
final class CommentComposerController extends ChangeNotifier {
  new() {
    text.addListener(notifyListeners);
  }

  final text = CommentTextController();
  final focusNode = FocusNode(debugLabel: 'comment composer');
  ComposerReply? _reply;
  bool _sending = false;

  ComposerReply? get reply => _reply;
  bool get sending => _sending;

  /// Whitespace alone is no comment, though the server would take it.
  bool get isBlank => text.text.trim().isEmpty;

  /// Nothing worth keeping as a draft.
  bool get isEmpty => isBlank && _reply == null;

  set sending(bool sending) {
    if (_sending == sending) return;
    _sending = sending;
    notifyListeners();
  }

  void replyTo(ComposerReply reply) {
    _reply = reply;
    notifyListeners();
    focusNode.requestFocus();
  }

  void cancelReply() {
    if (_reply == null) return;
    _reply = null;
    notifyListeners();
  }

  /// What was kept of an unsent comment.
  void restore(CommentComposerDraft draft) {
    _reply = switch (draft.reply) {
      final reply? => ComposerReply(
        commentId: reply.commentId,
        html: reply.html,
        authorName: reply.author,
      ),
      null => null,
    };
    text.restore(draft.text, [
      for (final mention in draft.mentions)
        ComposerMention(
          start: mention.start,
          end: mention.end,
          user: User(id: 0, username: mention.username, name: mention.label),
        ),
    ]);
  }

  CommentComposerDraft toDraft() => CommentComposerDraft(
    text: text.text,
    mentions: [
      for (final mention in text.mentions)
        (
          start: mention.start,
          end: mention.end,
          username: mention.user.username,
          label: mention.user.displayName,
        ),
    ],
    reply: switch (_reply) {
      final reply? => (
        commentId: reply.commentId,
        author: reply.authorName,
        html: reply.html,
      ),
      null => null,
    },
  );

  void clear() {
    _reply = null;
    text.clear();
  }

  /// The comment in the web editor's HTML.
  String html() => commentHtmlFromText(
    text.text,
    mentions: [
      for (final mention in text.mentions)
        MentionSpan(
          start: mention.start,
          end: mention.end,
          username: mention.user.username,
          label: mention.user.displayName,
        ),
    ],
    reply: switch (_reply) {
      final reply? => QuotedComment(id: reply.commentId, html: reply.html),
      null => null,
    },
  );

  @override
  void dispose() {
    text.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

/// The rounded "Write a comment…" field with `@` suggestions from the
/// project's people (those this device knows when the server cannot be
/// asked) and the Send button; above it the comment being replied to and,
/// offline, why Send is off. Up to five lines before it scrolls, fewer
/// where [maxHeight], the room above the keyboard, is short; what is above
/// the field then scrolls, so that the field and Send stay in view.
/// Disabled until [enabled], while it is not known yet whether the user
/// may write.
class CommentComposer extends ConsumerStatefulWidget {
  const new({
    required this.controller,
    required this.projectId,
    required this.offline,
    required this.maxHeight,
    required this.onSend,
    this.enabled = true,
    this.onFocused,
    super.key,
  });

  final CommentComposerController controller;
  final int projectId;
  final bool offline;
  final double maxHeight;
  final bool enabled;
  final VoidCallback onSend;

  /// The field got the focus.
  final VoidCallback? onFocused;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  late final _mentions = MentionController(
    search: _searchPeople,
    known: _knownPeople,
  )..addListener(_announceSuggestions);
  MentionQueryAt? _query;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    widget.controller.text.addListener(_followQuery);
    widget.controller.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(CommentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.text.removeListener(_followQuery);
      oldWidget.controller.focusNode.removeListener(_onFocus);
      widget.controller.text.addListener(_followQuery);
      widget.controller.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.controller.text.removeListener(_followQuery);
    widget.controller.focusNode.removeListener(_onFocus);
    _mentions.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (widget.controller.focusNode.hasFocus) {
      widget.onFocused?.call();
    } else {
      _endQuery();
    }
  }

  void _followQuery() {
    final query = widget.controller.focusNode.hasFocus
        ? widget.controller.text.activeMention()
        : null;
    if (query == null) {
      _endQuery();
      return;
    }
    if (query == _query) return;
    final changed = query.query != _query?.query;
    _query = query;
    if (changed || !_mentions.value.active) _mentions.query(query.query);
  }

  void _endQuery() {
    _query = null;
    if (_mentions.value.active) _mentions.end();
  }

  Future<List<User>> _searchPeople(String query) {
    final users = ref.read(userRepositoryProvider);
    if (users == null) {
      return Future.error(const NetworkFailure(NetworkProblem.unreachable));
    }
    return users.searchAssignees(widget.projectId, query);
  }

  Future<List<User>> _knownPeople() async =>
      await ref.read(userRepositoryProvider)?.knownUsers() ?? const [];

  void _announceSuggestions() {
    final suggestions = _mentions.value;
    final arrived = _searching && suggestions.active && !suggestions.searching;
    _searching = suggestions.searching;
    if (!arrived || suggestions.people.isEmpty || !mounted) return;
    announce(
      context,
      context.l10n.editorMentionsFound(suggestions.people.length),
    );
  }

  void _pick(User user) {
    final query = _query;
    if (query == null) return;
    _endQuery();
    widget.controller.text.insertMention(user, at: query.at);
  }

  void _cancelReply() {
    widget.controller.cancelReply();
    announce(context, context.l10n.commentReplyDropped);
  }

  /// As many lines as take a part of the composer's height, beside the
  /// paddings of the field and its row.
  int _maxLines(BuildContext context, TextStyle? style) {
    final scaler = MediaQuery.textScalerOf(context);
    // In large text five lines would cover the list.
    final most = scaler.scale(1) > 1.5 ? 3 : 5;
    if (!widget.maxHeight.isFinite) return most;
    final lineHeight =
        scaler.scale(style?.fontSize ?? 16) * (style?.height ?? 1.2);
    final fitting = ((widget.maxHeight - 1 - 16 - 28) / lineHeight * 0.6)
        .floor();
    return math.max(1, math.min(most, fitting));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final reply = controller.reply;
        final canSend =
            widget.enabled &&
            !controller.isBlank &&
            !controller.sending &&
            !widget.offline;
        final fieldStyle = theme.textTheme.bodyLarge;
        final field = Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller.text,
                  focusNode: controller.focusNode,
                  enabled: widget.enabled,
                  readOnly: controller.sending,
                  minLines: 1,
                  maxLines: _maxLines(context, fieldStyle),
                  style: fieldStyle,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  // The server takes up to 1 MB; past this a phone
                  // is no place to write it.
                  inputFormatters: [LengthLimitingTextInputFormatter(20000)],
                  decoration: InputDecoration(
                    hintText: l10n.commentComposerHint,
                    hintMaxLines: 1,
                    filled: true,
                    fillColor: colors.surfaceContainerHigh,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                sending: controller.sending,
                onPressed: canSend ? widget.onSend : null,
              ),
            ],
          ),
        );
        return Material(
          color: colors.surface,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: _mentions,
                          builder: (context, suggestions, _) =>
                              suggestions.active
                              ? MentionBar(
                                  suggestions: suggestions,
                                  onPick: _pick,
                                  maxHeight: math.min(
                                    220,
                                    widget.maxHeight * 0.6,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (reply != null)
                          _ReplyBanner(
                            reply: reply,
                            onCancel: controller.sending ? null : _cancelReply,
                          ),
                        if (widget.offline)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              16,
                              8,
                              16,
                              0,
                            ),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                l10n.commentComposerOffline,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Below the bare field only the field shows, from its end.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(0, widget.maxHeight - 1),
                  ),
                  child: SingleChildScrollView(reverse: true, child: field),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SendButton extends StatelessWidget {
  const new({required this.sending, required this.onPressed});

  final bool sending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return IconButton.filled(
      onPressed: onPressed,
      tooltip: sending ? l10n.commentSending : l10n.commentSend,
      style: IconButton.styleFrom(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        minimumSize: const Size.square(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: sending
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : const Icon(Icons.send),
    );
  }
}

/// "Replying to Anna" and the start of what is quoted, with a button that
/// drops the quote.
class _ReplyBanner extends StatefulWidget {
  const new({required this.reply, required this.onCancel});

  final ComposerReply reply;
  final VoidCallback? onCancel;

  @override
  State<_ReplyBanner> createState() => _ReplyBannerState();
}

// The composer rebuilds with every key; the quote is parsed once.
class _ReplyBannerState extends State<_ReplyBanner> {
  late String _quoted = quotedTextOf(widget.reply.html);

  @override
  void didUpdateWidget(_ReplyBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reply.html != widget.reply.html) {
      _quoted = quotedTextOf(widget.reply.html);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final quoted = _quoted;
    final reply = widget.reply;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 0),
      child: Row(
        children: [
          Icon(Icons.reply, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.commentReplyingTo(reply.authorName),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  if (quoted.isNotEmpty)
                    Text(
                      quoted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onCancel,
            tooltip: l10n.commentReplyCancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
