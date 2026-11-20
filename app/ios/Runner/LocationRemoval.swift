import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Takes the location out of a picked photo or video in place, as `LocationRemoval.kt` does on
/// Android, without encoding a JPEG, HEIC or video again. A file without a location stays
/// untouched.
enum LocationRemoval {
  enum Failure: Error {
    case unreadable
    case notCopied
    case locationKept
    case notExported
  }

  static func remove(from url: URL, completion: @escaping (Error?) -> Void) {
    guard let type = UTType(filenameExtension: url.pathExtension) else {
      completion(nil)
      return
    }
    if type.conforms(to: .image) {
      do {
        try removeFromImage(at: url)
        completion(nil)
      } catch {
        completion(error)
      }
    } else if type.conforms(to: .movie) {
      removeFromVideo(at: url, type: type, completion: completion)
    } else {
      completion(nil)
    }
  }

  private static func removeFromImage(at url: URL) throws {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let type = CGImageSourceGetType(source)
    else { throw Failure.unreadable }
    guard hasLocation(source) else { return }
    let count = CGImageSourceGetCount(source)
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, type, count, nil) else {
      throw Failure.notCopied
    }
    if UTType(type as String) == .png {
      // Image I/O's lossless copy keeps a PNG's location, and PNG loses nothing when written again.
      for index in 0..<count {
        CGImageDestinationAddImageFromSource(
          destination, source, index, [kCGImagePropertyGPSDictionary: kCFNull] as CFDictionary)
      }
      guard CGImageDestinationFinalize(destination) else { throw Failure.notCopied }
    } else {
      // Without the metadata given, a JPEG's copy loses its orientation and a HEIC's keeps its
      // location.
      var options: [CFString: Any] = [kCGImageMetadataShouldExcludeGPS: true]
      if let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil) {
        options[kCGImageDestinationMetadata] = withoutLocation(metadata)
      }
      var error: Unmanaged<CFError>?
      guard CGImageDestinationCopyImageSource(destination, source, options as CFDictionary, &error)
      else { throw error?.takeRetainedValue() ?? Failure.notCopied }
    }
    guard let copy = CGImageSourceCreateWithData(data, nil), !hasLocation(copy) else {
      throw Failure.locationKept
    }
    try data.write(to: url, options: .atomic)
  }

  private static func hasLocation(_ source: CGImageSource) -> Bool {
    (0..<CGImageSourceGetCount(source)).contains { index in
      let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
      guard properties?[kCGImagePropertyGPSDictionary] == nil else { return true }
      guard let metadata = CGImageSourceCopyMetadataAtIndex(source, index, nil) else {
        return false
      }
      return !locationTags(metadata).isEmpty
    }
  }

  private static func withoutLocation(_ metadata: CGImageMetadata) -> CGImageMetadata {
    guard let copy = CGImageMetadataCreateMutableCopy(metadata) else { return metadata }
    for path in locationTags(metadata) {
      CGImageMetadataRemoveTagWithPath(copy, nil, path as CFString)
    }
    return copy
  }

  /// The EXIF GPS tags, whether the file keeps them in EXIF or in XMP.
  private static func locationTags(_ metadata: CGImageMetadata) -> [String] {
    let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag] ?? []
    return tags.compactMap { tag in
      guard
        CGImageMetadataTagCopyNamespace(tag) as String? == kCGImageMetadataNamespaceExif as String,
        let prefix = CGImageMetadataTagCopyPrefix(tag) as String?,
        let name = CGImageMetadataTagCopyName(tag) as String?, name.hasPrefix("GPS")
      else { return nil }
      return "\(prefix):\(name)"
    }
  }

  private static func removeFromVideo(
    at url: URL, type: UTType, completion: @escaping (Error?) -> Void
  ) {
    let asset = AVURLAsset(url: url)
    guard asset.metadata.contains(where: isLocation) else {
      completion(nil)
      return
    }
    let fileType = AVFileType(rawValue: type.identifier)
    guard
      let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough),
      session.supportedFileTypes.contains(fileType)
    else {
      completion(Failure.notExported)
      return
    }
    let output = url.deletingLastPathComponent()
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(url.pathExtension)
    session.outputURL = output
    session.outputFileType = fileType
    session.metadataItemFilter = .forSharing()
    session.exportAsynchronously {
      do {
        guard session.status == .completed else { throw session.error ?? Failure.notExported }
        guard !AVURLAsset(url: output).metadata.contains(where: isLocation) else {
          throw Failure.locationKept
        }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: output)
        completion(nil)
      } catch {
        try? FileManager.default.removeItem(at: output)
        completion(error)
      }
    }
  }

  private static func isLocation(_ item: AVMetadataItem) -> Bool {
    item.commonKey == .commonKeyLocation
      || item.identifier == .quickTimeUserDataLocationISO6709
      || item.identifier?.rawValue.lowercased().contains("location") == true
  }
}
