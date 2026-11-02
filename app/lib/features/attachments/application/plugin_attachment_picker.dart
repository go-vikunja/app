import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' hide PickedFile;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/platform/location_removal.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';
import 'package:vikunja_mobile/features/attachments/application/channel_document_picker.dart';

/// [AttachmentPicker] through file_selector (the document picker; on
/// Android the app's own [documents] instead) and image_picker (the photo
/// picker and the camera). Leaving the app for a picker does not lock it.
final class PluginAttachmentPicker implements AttachmentPicker {
  new({
    this.documents,
    this.excursions,
    this.locations,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const lostPickPoll = Duration(milliseconds: 500);

  /// Without a lost pick by then, nothing was picked.
  static const lostPickWait = Duration(seconds: 15);

  final ChannelDocumentPicker? documents;
  final AppExcursions? excursions;

  /// Takes the location out of photos and videos from the photo picker and
  /// the camera; files from the document picker keep theirs.
  final LocationRemoval? locations;
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
    final names = defaultTargetPlatform == TargetPlatform.iOS
        ? iosLibraryFileNames([
            for (final file in files) file.name,
          ], pickedAt: _now())
        : [for (final file in files) file.name];
    await locations?.removeFromAll([for (final file in files) file.path]);
    return [
      for (final (index, file) in files.indexed)
        _picked(file, name: names[index]),
    ];
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
    final takenAt = _now();
    await locations?.removeFromAll([file.path]);
    return PickedFile(
      path: file.path,
      name: cameraFileName(file.path, takenAt: takenAt),
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

  static PickedFile _picked(XFile file, {String? name}) => PickedFile(
    path: file.path,
    name: name ?? file.name,
    mimeType: file.mimeType ?? mediaTypeOf(file.path),
  );
}

/// A camera shot's name the way cameras write it, `IMG_20261020_143005.jpg`,
/// instead of the picker's random temporary name; [number] tells apart
/// several of the same second.
String cameraFileName(String path, {required DateTime takenAt, int? number}) {
  final extension = p.extension(path);
  return 'IMG_${DateFormat('yyyyMMdd_HHmmss').format(takenAt)}'
      '${number == null ? '' : '_$number'}'
      '${extension.isEmpty ? '.jpg' : extension.toLowerCase()}';
}

// image_picker's copy on iOS: `image_picker_`, a unique id (a UUID, the
// process id and 16 hex digits), then a photo's extension or a video's own
// name.
final _iosPickerCopy = RegExp(
  r'^image_picker_[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}-\d+-[0-9A-F]{16}'
  r'(.*)$',
);

/// The names of photos and videos picked from the library on iOS: a photo
/// in image_picker's copy is named like a camera shot taken at [pickedAt],
/// numbered when there are several; a video keeps its own name, and so
/// does a file the picker named itself.
List<String> iosLibraryFileNames(
  List<String> names, {
  required DateTime pickedAt,
}) {
  final rests = [
    for (final name in names) _iosPickerCopy.firstMatch(name)?.group(1),
  ];
  bool isPhoto(String? rest) => rest != null && !_isOwnName(rest);
  final numbered = rests.where(isPhoto).length > 1;
  var number = 0;
  return [
    for (final (index, name) in names.indexed)
      switch (rests[index]) {
        null => name,
        final rest when _isOwnName(rest) => rest,
        _ => cameraFileName(
          name,
          takenAt: pickedAt,
          number: numbered ? ++number : null,
        ),
      },
  ];
}

bool _isOwnName(String rest) => rest.isNotEmpty && !rest.startsWith('.');

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
