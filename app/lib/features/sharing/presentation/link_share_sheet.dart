import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/share_web_link.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/view_labels.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';
import 'package:vikunja_mobile/features/sharing/application/link_share_links.dart';
import 'package:vikunja_mobile/features/sharing/presentation/link_qr_sheet.dart';
import 'package:vikunja_mobile/features/sharing/presentation/link_share_clipboard.dart';
import 'package:vikunja_mobile/features/sharing/presentation/share_texts.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// A link share's name, or what stands in for a missing one.
String linkShareTitle(AppLocalizations l10n, LinkShare share) =>
    share.name.trim().isEmpty ? l10n.linkShareUnnamed : share.name.trim();

/// What can be done with [share]: the view it opens, Share, Copy link, the
/// QR code and, unless it was [created] just now, Delete, which closes the
/// sheet with true for the caller to ask and delete. [onViewChanged] gets
/// a newly picked view, which the caller keeps for the share's row.
Future<bool?> showLinkShareSheet(
  BuildContext context, {
  required LinkShare share,
  required String projectTitle,
  required List<ProjectView> views,
  required int? viewId,
  required ValueChanged<int> onViewChanged,
  bool created = false,
}) => showPickerSheet<bool>(
  context,
  builder: (context, scrollController) => LinkShareSheet(
    share: share,
    projectTitle: projectTitle,
    views: views,
    viewId: viewId,
    onViewChanged: onViewChanged,
    created: created,
    scrollController: scrollController,
  ),
);

class LinkShareSheet extends ConsumerStatefulWidget {
  const new({
    required this.share,
    required this.projectTitle,
    required this.views,
    required this.viewId,
    required this.onViewChanged,
    this.created = false,
    this.scrollController,
    super.key,
  });

  final LinkShare share;
  final String projectTitle;
  final List<ProjectView> views;
  final int? viewId;
  final ValueChanged<int> onViewChanged;
  final bool created;
  final ScrollController? scrollController;

  @override
  ConsumerState<LinkShareSheet> createState() => _LinkShareSheetState();
}

class _LinkShareSheetState extends ConsumerState<LinkShareSheet> {
  late int? _viewId = linkViewIdFor(widget.views, widget.viewId);

  Future<void> _pickView() async {
    final l10n = context.l10n;
    final picked = await showOptionSheet<int>(
      context,
      title: l10n.linkShareViewTitle,
      options: [
        for (final view in widget.views)
          SheetOption(
            value: view.id,
            label: viewTitle(l10n, view),
            selected: view.id == _viewId,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _viewId = picked);
    widget.onViewChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final share = widget.share;
    final bases = ref.watch(activeLinkBasesProvider);
    final url = bases == null
        ? null
        : linkShareUriFor(bases, share, viewId: _viewId);
    final view = widget.views.where((view) => view.id == _viewId).firstOrNull;
    final details = [
      permissionLabel(l10n, share.permission),
      if (share.passwordProtected) l10n.linkSharePasswordProtected,
    ].join(' · ');
    Widget action({
      required IconData icon,
      required String label,
      required void Function(BuildContext context, Uri url) onTap,
      Color? color,
    }) => Builder(
      builder: (context) => ListTile(
        enabled: url != null,
        leading: Icon(icon, color: color ?? colors.onSurfaceVariant),
        title: Text(label, style: TextStyle(color: color)),
        onTap: url == null ? null : () => onTap(context, url),
      ),
    );

    return ListView(
      controller: widget.scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        PickerHeader(
          title: widget.created
              ? l10n.linkShareCreated
              : linkShareTitle(l10n, share),
          actionLabel: l10n.pickerDone,
          onAction: () => Navigator.of(context).pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.created) ...[
                Text(
                  linkShareTitle(l10n, share),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
              ],
              Text(
                details,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (widget.created) ...[
                const SizedBox(height: 8),
                Text(l10n.linkShareCreatedBody),
              ],
            ],
          ),
        ),
        if (widget.views.length > 1 && view != null)
          ListTile(
            leading: Icon(
              viewKindIcon(view.kind),
              color: colors.onSurfaceVariant,
            ),
            title: Text(l10n.linkShareViewTitle),
            subtitle: Text(viewTitle(l10n, view)),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () => unawaited(_pickView()),
          ),
        action(
          icon: Icons.share_outlined,
          label: l10n.linkShareShare,
          onTap: (context, url) => unawaited(
            shareWebLink(
              context,
              ref,
              url: url,
              subject: l10n.linkShareSubject(widget.projectTitle),
            ),
          ),
        ),
        action(
          icon: Icons.copy,
          label: l10n.linkShareCopy,
          onTap: (context, url) =>
              unawaited(copyLinkShareText(context, ref, url.toString())),
        ),
        action(
          icon: Icons.qr_code_2,
          label: l10n.linkShareQr,
          onTap: (context, url) =>
              unawaited(showLinkQrSheet(context, url: url)),
        ),
        if (!widget.created)
          action(
            icon: Icons.delete_outline,
            label: l10n.linkShareDelete,
            color: colors.error,
            onTap: (context, _) => Navigator.of(context).pop(true),
          ),
      ],
    );
  }
}
