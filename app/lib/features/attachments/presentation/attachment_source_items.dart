import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';

/// A menu entry with its icon for each of [sources], in that order.
List<PopupMenuEntry<AttachmentSource>> attachmentSourceItems(
  AppLocalizations l10n,
  List<AttachmentSource> sources,
) => [
  for (final source in sources)
    PopupMenuItem(
      value: source,
      child: Row(
        children: [
          Icon(switch (source) {
            AttachmentSource.files => Icons.folder_open_outlined,
            AttachmentSource.photos => Icons.photo_library_outlined,
            AttachmentSource.camera => Icons.photo_camera_outlined,
          }),
          const SizedBox(width: 12),
          Flexible(
            child: Text(switch (source) {
              AttachmentSource.files => l10n.attachmentSourceFiles,
              AttachmentSource.photos => l10n.attachmentSourcePhotos,
              AttachmentSource.camera => l10n.attachmentSourceCamera,
            }),
          ),
        ],
      ),
    ),
];
