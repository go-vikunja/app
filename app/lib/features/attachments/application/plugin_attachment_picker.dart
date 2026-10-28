import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' hide PickedFile;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/attachments/application/channel_document_picker.dart';

/// [AttachmentPicker] through file_selector (the document picker; on
/// Android the app's own [documents] instead) and image_picker (the photo
/// picker and the camera). Leaving the app for a picker does not lock it.
final class PluginAttachmentPicker implements AttachmentPicker {
  new({this.documents, this.excursions, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const lostPickPoll = Duration(milliseconds: 500);

  /// Without a lost pick by then, nothing was picked.
  static const lostPickWait = Duration(seconds: 15);

  final ChannelDocumentPicker? documents;
  final AppExcursions? excursions;
  final DateTime Function() _now;

  static const _images = XTypeGroup(
    label: 'images',
    mimeTypes: ['image/*'],
    uniformTypeIdentifiers: ['public.image'],
  );

  // file_selector copies whatever was picked; one above the limit is
  // refused when it is queued.
  @override
  Future<PickedFiles> pickFiles({
    required int maxBytes,
    bool imagesOnly = false,
    bool multiple = true,
  }) async {
    if (documents case final documents?) {
      return await documents.pick(
        maxBytes: maxBytes,
        imagesOnly: imagesOnly,
        multiple: multiple,
      );
    }
    final groups = imagesOnly ? const [_images] : const <XTypeGroup>[];
    final files = await _away(
      () async => multiple
          ? await openFiles(acceptedTypeGroups: groups)
          : [?await openFile(acceptedTypeGroups: groups)],
    );
    return PickedFiles(files: files.map(_picked).toList());
  }

  // Without the full metadata the photo picker needs no library permission
  // on iOS.
  @override
  Future<List<PickedFile>> pickPhotos({
    bool imagesOnly = false,
    bool multiple = true,
  }) async {
    final picker = ImagePicker();
    final files = await _away(() async {
      if (imagesOnly) {
        return multiple
            ? await picker.pickMultiImage(requestFullMetadata: false)
            : [
                ?await picker.pickImage(
                  source: ImageSource.gallery,
                  requestFullMetadata: false,
                ),
              ];
      }
      return multiple
          ? await picker.pickMultipleMedia(requestFullMetadata: false)
          : [?await picker.pickMedia(requestFullMetadata: false)];
    }, recover: _lostPick);
    return files.map(_picked).toList();
  }

  @override
  Future<PickedFile?> takePhoto() async {
    final file = await _away(
      () => ImagePicker().pickImage(
        source: ImageSource.camera,
        requestFullMetadata: false,
      ),
      recover: () async => (await _lostPick()).firstOrNull,
    );
    if (file == null) return null;
    return PickedFile(
      path: file.path,
      name: cameraFileName(file.path, takenAt: _now()),
      mimeType: file.mimeType ?? mediaTypeOf(file.path),
    );
  }

  // image_picker keeps lost picks on Android only, and iOS does not
  // relaunch.
  Future<T> _away<T>(
    Future<T> Function() pick, {
    Future<T> Function()? recover,
  }) =>
      excursions?.roundTrip(
        pick,
        recover: defaultTargetPlatform == TargetPlatform.android
            ? recover
            : null,
      ) ??
      pick();

  // image_picker never answers a pick across an activity relaunch; it keeps
  // what was picked for retrieveLostData once its background work (for the
  // camera a media scan) is done.
  static Future<List<XFile>> _lostPick() async {
    final picker = ImagePicker();
    for (var waited = Duration.zero; ; waited += lostPickPoll) {
      // While no activity is attached (the app left again and Android
      // destroyed the activity), image_picker cannot be asked; a later look
      // may still find the pick.
      final lost = await picker.retrieveLostData().onError<PlatformException>(
        (_, _) => LostDataResponse.empty(),
      );
      if (!lost.isEmpty) {
        if (lost.exception case final exception?) throw exception;
        return lost.files ?? [?lost.file];
      }
      if (waited >= lostPickWait) return const [];
      await Future<void>.delayed(lostPickPoll);
    }
  }

  static PickedFile _picked(XFile file) => PickedFile(
    path: file.path,
    name: file.name,
    mimeType: file.mimeType ?? mediaTypeOf(file.path),
  );
}

/// A camera shot's name the way cameras write it, `IMG_20261020_143005.jpg`,
/// instead of the picker's random temporary name.
String cameraFileName(String path, {required DateTime takenAt}) {
  final extension = p.extension(path);
  return 'IMG_${DateFormat('yyyyMMdd_HHmmss').format(takenAt)}'
      '${extension.isEmpty ? '.jpg' : extension.toLowerCase()}';
}

/// The type of a photo or video by its extension, for pickers that name
/// none: the icon of a queued file needs it.
String? mediaTypeOf(String path) => switch (p.extension(path).toLowerCase()) {
  '.jpg' || '.jpeg' => 'image/jpeg',
  '.png' => 'image/png',
  '.gif' => 'image/gif',
  '.webp' => 'image/webp',
  '.bmp' => 'image/bmp',
  '.heic' => 'image/heic',
  '.heif' => 'image/heif',
  '.mp4' => 'video/mp4',
  '.mov' => 'video/quicktime',
  '.3gp' => 'video/3gpp',
  '.webm' => 'video/webm',
  '.mkv' => 'video/x-matroska',
  _ => null,
};
