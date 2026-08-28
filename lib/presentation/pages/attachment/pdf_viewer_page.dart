import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/utils/attachment_utils.dart';

class PdfViewerPage extends ConsumerStatefulWidget {
  final Task task;
  final TaskAttachment attachment;

  const PdfViewerPage({
    super.key,
    required this.task,
    required this.attachment,
  });

  @override
  ConsumerState<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends ConsumerState<PdfViewerPage> {
  String? _path;
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
    } else {
      setState(() => _path = path);
    }
  }

  Future<void> _openExternally() async {
    if (_path == null) return;
    await openLocalFileExternally(_path!, widget.attachment.file.mime);
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
          if (_path != null)
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

    if (_path == null) {
      return const Center(
        child: SpinKitThreeBounce(color: Colors.blueGrey, size: 24),
      );
    }

    return PDFView(
      filePath: _path!,
      autoSpacing: true,
      pageFling: false,
      swipeHorizontal: false,
      onError: (_) {
        setState(() {
          _error = AppLocalizations.of(context).attachmentFailed;
        });
      },
      onPageError: (page, error) {
        setState(() {
          _error = AppLocalizations.of(context).attachmentFailed;
        });
      },
    );
  }
}
