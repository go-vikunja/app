import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/attachment_image_view.dart';

/// Full screen over everything, on the root navigator, so an account
/// switch closes it with the sheets.
Future<void> showAttachmentImage(
  BuildContext context, {
  required int taskId,
  required int attachmentId,
  String description = '',
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (context) => AttachmentImageViewer(
      taskId: taskId,
      attachmentId: attachmentId,
      description: description,
    ),
  ),
);

/// The original of an attachment image, zoomable; the larger preview
/// stands in while the original loads, when it is in memory.
class AttachmentImageViewer extends StatelessWidget {
  const new({
    required this.taskId,
    required this.attachmentId,
    this.description = '',
    super.key,
  });

  final int taskId;
  final int attachmentId;
  final String description;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = description.isNotEmpty ? description : l10n.richTextImage;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: l10n.imageViewerClose,
          icon: const Icon(Icons.close),
        ),
        title: description.isEmpty ? null : ScreenTitle(description),
      ),
      body: SafeArea(
        child: AttachmentImageLoader(
          taskId: taskId,
          attachmentId: attachmentId,
          preview: null,
          builder: (context, state, retry) => switch (state) {
            AttachmentImageLoaded(:final image) when state.drawable =>
              _Zoomable(label: label, bytes: image.bytes),
            AttachmentImageLoaded() => _Notice(
              text: l10n.richTextImageUnsupported,
            ),
            AttachmentImageFailed(:final failure) => _Notice(
              text: attachmentImageFailureText(l10n, failure),
              onRetry: state.mayPass ? retry : null,
            ),
            AttachmentImageLoading() => _PreviewWhileLoading(
              taskId: taskId,
              attachmentId: attachmentId,
              label: label,
            ),
          },
        ),
      ),
    );
  }
}

/// A preview already in memory stands in; none is requested for it.
class _PreviewWhileLoading extends ConsumerWidget {
  const new({
    required this.taskId,
    required this.attachmentId,
    required this.label,
  });

  final int taskId;
  final int attachmentId;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(attachmentImagesProvider);
    final preview =
        images?.peek(
          taskId,
          attachmentId,
          preview: AttachmentPreviewSize.extraLarge,
        ) ??
        images?.peek(
          taskId,
          attachmentId,
          preview: AttachmentPreviewSize.medium,
        );
    return Stack(
      alignment: Alignment.center,
      children: [
        if (preview != null && AttachmentImageLoaded(preview).drawable)
          _Zoomable(label: label, bytes: preview.bytes),
        // The Cupertino indicator takes its colour from the background
        // colour, the Material one from the colour.
        CircularProgressIndicator.adaptive(
          valueColor: const AlwaysStoppedAnimation(Colors.white),
          backgroundColor: switch (Theme.of(context).platform) {
            TargetPlatform.iOS || TargetPlatform.macOS => Colors.white,
            _ => null,
          },
        ),
      ],
    );
  }
}

class _Zoomable extends StatelessWidget {
  const new({required this.label, required this.bytes});

  final String label;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    child: InteractiveViewer(
      maxScale: 6,
      child: Center(
        child: Image.memory(
          bytes,
          // Room to zoom in without decoding a huge photo at full size.
          cacheWidth: decodeWidthFor(context, factor: 2),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) =>
              _Notice(text: context.l10n.richTextImageUnsupported),
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const new({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white),
          ),
          if (onRetry != null)
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
              child: Text(context.l10n.retry),
            ),
        ],
      ),
    ),
  );
}
