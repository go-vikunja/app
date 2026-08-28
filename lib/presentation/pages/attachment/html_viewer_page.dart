import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/utils/attachment_utils.dart';

class HtmlViewerPage extends ConsumerStatefulWidget {
  final Task task;
  final TaskAttachment attachment;

  const HtmlViewerPage({
    super.key,
    required this.task,
    required this.attachment,
  });

  @override
  ConsumerState<HtmlViewerPage> createState() => _HtmlViewerPageState();
}

class _HtmlViewerPageState extends ConsumerState<HtmlViewerPage> {
  String? _html;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = await resolveAttachmentPath(
      ref,
      widget.task,
      widget.attachment,
    );
    if (!mounted) return;
    if (path == null) {
      setState(() {
        _error = AppLocalizations.of(context).attachmentFailed;
      });
      return;
    }

    try {
      final html = await File(path).readAsString();
      if (!mounted) return;
      setState(() => _html = html);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context).attachmentFailed;
      });
    }
  }

  Future<void> _openExternally() async {
    final path = await resolveAttachmentPath(
      ref,
      widget.task,
      widget.attachment,
    );
    if (path == null) return;
    await openLocalFileExternally(path, widget.attachment.file.mime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.attachment.file.name,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_html != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: AppLocalizations.of(context).openInBrowser,
              onPressed: _openExternally,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_html == null) {
      return const Center(
        child: SpinKitThreeBounce(color: Colors.blueGrey, size: 24),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: HtmlWidget(
        _html!,
        key: const Key('html-viewer'),
        textStyle: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
