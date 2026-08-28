import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/utils/attachment_utils.dart';

/// Renders an HTML attachment in a full in-app WebView (real browser engine),
/// so styles, scripts (e.g. Tailwind CDN) and RTL Hebrew render correctly.
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
  WebViewController? _controller;
  String? _error;
  bool _loading = true;

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

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // DOM storage is enabled by default in webview_flutter 4.13.
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _loading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
          },
        ),
      );

    // file:// prefix so both the new and legacy Android loaders get a URL.
    await controller.loadFile('file://$path');

    if (!mounted) return;
    setState(() {
      _controller = controller;
      _loading = false;
    });
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
          if (_controller != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: AppLocalizations.of(context).openInBrowser,
              onPressed: _openExternally,
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_loading)
            const Center(
              child: SpinKitThreeBounce(color: Colors.blueGrey, size: 24),
            ),
        ],
      ),
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

    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return WebViewWidget(controller: controller);
  }
}
