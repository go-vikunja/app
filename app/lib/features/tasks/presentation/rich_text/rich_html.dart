import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/link_targets.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_text_view.dart';

/// Parses [html] of the active account once per change and draws it with
/// [RichTextView]; [empty] stands in when it has nothing visible. A tap on
/// a checkbox goes to [onToggleTaskItem] with the exact HTML the item was
/// parsed from.
class RichHtml extends ConsumerStatefulWidget {
  const new({
    required this.html,
    required this.onLink,
    required this.onTaskLink,
    this.onToggleTaskItem,
    this.empty,
    this.style,
    this.projectId,
    this.replyAuthorOf,
    this.attachments,
    super.key,
  });

  final String html;
  final ValueChanged<String>? onLink;
  final ValueChanged<int> onTaskLink;
  final void Function(String html, RichTaskItem item)? onToggleTaskItem;
  final Widget? empty;
  final TextStyle? style;
  final int? projectId;
  final User? Function(int commentId)? replyAuthorOf;

  /// The task's attachments as its details list them, null where none are
  /// at hand. An original stands in by itself for a missing preview only
  /// for a small image named here, and a file named here as something
  /// other than an image is never asked for.
  final List<TaskAttachment>? attachments;

  @override
  ConsumerState<RichHtml> createState() => _RichHtmlState();
}

class _RichHtmlState extends ConsumerState<RichHtml> {
  (String, AccountLinkBases)? _parsedFrom;
  RichDocument _document = const RichDocument([]);

  RichDocument _parse(String html, AccountLinkBases bases) {
    if (_parsedFrom != (html, bases)) {
      _parsedFrom = (html, bases);
      _document = parseRichText(
        html,
        apiRoot: bases.serverRoot,
        taskLinkBases: bases.taskLinkBases,
      );
    }
    return _document;
  }

  @override
  Widget build(BuildContext context) {
    final bases = ref.watch(activeLinkBasesProvider);
    final html = widget.html;
    final document = bases == null
        ? const RichDocument([])
        : _parse(html, bases);
    if (document.isEmpty && widget.empty != null) return widget.empty!;
    final onToggle = widget.onToggleTaskItem;
    return RichTextView(
      document: document,
      onLink: widget.onLink,
      onTaskLink: widget.onTaskLink,
      onToggleTaskItem: onToggle == null
          ? null
          : (item) => onToggle(html, item),
      linkAddress: bases == null ? null : (href) => linkAddressOf(href, bases),
      style: widget.style,
      projectId: widget.projectId,
      replyAuthorOf: widget.replyAuthorOf,
      attachments: widget.attachments,
    );
  }
}
