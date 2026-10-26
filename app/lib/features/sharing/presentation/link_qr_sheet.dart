import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/sharing/application/link_qr.dart';
import 'package:vikunja_mobile/features/sharing/presentation/link_share_clipboard.dart';
import 'package:vikunja_mobile/features/sharing/presentation/qr_code_view.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// [url] as a QR code to scan from the screen, the URL selectable below;
/// a URL too long for a code that scans well says so instead.
Future<void> showLinkQrSheet(BuildContext context, {required Uri url}) =>
    showPickerSheet<void>(
      context,
      builder: (context, scrollController) =>
          LinkQrSheet(url: url, scrollController: scrollController),
    );

class LinkQrSheet extends StatelessWidget {
  const new({required this.url, this.scrollController, super.key});

  final Uri url;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = url.toString();
    final image = linkQrImage(text);
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        PickerHeader(
          title: l10n.linkShareQr,
          actionLabel: l10n.pickerDone,
          onAction: () => Navigator.of(context).pop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: switch (image) {
            final image? => Center(
              child: QrCodeView(
                image: image,
                semanticsLabel: l10n.linkShareQrSemantics,
              ),
            ),
            null => Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(Icons.qr_code_2, color: colors.error),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.linkShareQrTooLong,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          },
        ),
        if (image != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              l10n.linkShareQrHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: LinkShareText(text),
        ),
      ],
    );
  }
}
