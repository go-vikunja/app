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
    guard let original = CGImageSourceCreateWithURL(url as CFURL, nil),
      let type = CGImageSourceGetType(original)
    else { throw Failure.unreadable }
    let isPng = UTType(type as String) == .png
    let stripped =
      isPng ? try pngWithoutLocationText(Data(contentsOf: url, options: .mappedIfSafe)) : nil
    let source: CGImageSource
    if let stripped {
      guard let copy = CGImageSourceCreateWithData(stripped as CFData, nil) else {
        throw Failure.notCopied
      }
      source = copy
    } else {
      source = original
    }
    guard hasLocation(source) else {
      if let stripped { try stripped.write(to: url, options: .atomic) }
      return
    }
    let count = CGImageSourceGetCount(source)
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, type, count, nil) else {
      throw Failure.notCopied
    }
    if isPng {
      // Image I/O's lossless copy keeps a PNG's location, and PNG loses nothing when written again.
      // The properties carry what the XMP does not: text chunks, DPI, orientation, an APNG's loop
      // count and frame delays.
      CGImageDestinationSetProperties(
        destination, withoutGPS(CGImageSourceCopyProperties(source, nil)) as CFDictionary)
      for index in 0..<count {
        guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
          throw Failure.notCopied
        }
        var properties = withoutGPS(CGImageSourceCopyPropertiesAtIndex(source, index, nil))
        properties[kCGImageMetadataShouldExcludeGPS] = true
        CGImageDestinationAddImageAndMetadata(
          destination, image,
          CGImageSourceCopyMetadataAtIndex(source, index, nil).map(withoutLocation),
          properties as CFDictionary)
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
    if isPng, try pngWithoutLocationText(data as Data) != nil {
      throw Failure.locationKept
    }
    try data.write(to: url, options: .atomic)
  }

  /// Image I/O does not expose arbitrary PNG text keywords. Remove the entire named chunk,
  /// compressed or not; the other chunks keep their bytes and checksums.
  private static func pngWithoutLocationText(_ data: Data) throws -> Data? {
    var offset = 8
    var lastKept = 0
    var stripped: Data?
    while data.count - offset >= 12 {
      let length = (offset..<(offset + 4)).reduce(0) { $0 * 256 + Int(data[$1]) }
      guard length <= data.count - offset - 12 else { throw Failure.unreadable }
      let start = offset + 8
      let end = start + length + 4
      let type = String(decoding: data[(offset + 4)..<start], as: UTF8.self)
      switch type {
      case "tEXt", "zTXt", "iTXt":
        let keywordBytes = data[start..<(start + min(length, 80))]
        guard let terminator = keywordBytes.firstIndex(of: 0), terminator > start,
          let keyword = String(data: data[start..<terminator], encoding: .isoLatin1)
        else { throw Failure.unreadable }
        if let name = keyword.split(separator: ":").last, namesLocation(String(name)) {
          if stripped == nil { stripped = Data() }
          stripped?.append(contentsOf: data[lastKept..<offset])
          lastKept = end
        }
      case "IEND":
        stripped?.append(contentsOf: data[lastKept...])
        return stripped
      default:
        break
      }
      offset = end
    }
    throw Failure.unreadable
  }

  /// Without {GPS} and without what Image I/O would write back into the XMP from the other
  /// dictionaries, such as IPTC's `LocationShown`.
  private static func withoutGPS(_ properties: CFDictionary?) -> [CFString: Any] {
    var properties = properties as? [CFString: Any] ?? [:]
    properties[kCGImagePropertyGPSDictionary] = nil
    for (key, value) in properties {
      guard var dictionary = value as? [String: Any] else { continue }
      dictionary = dictionary.filter { !namesLocation($0.key) && !holdsLocation($0.value) }
      properties[key] = dictionary
    }
    return properties
  }

  private static func holdsLocation(_ value: Any) -> Bool {
    if let dictionary = value as? [String: Any] {
      return dictionary.contains { namesLocation($0.key) || holdsLocation($0.value) }
    }
    if let array = value as? [Any] {
      return array.contains(where: holdsLocation)
    }
    return false
  }

  private static func hasLocation(_ source: CGImageSource) -> Bool {
    (0..<CGImageSourceGetCount(source)).contains { index in
      let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
      let gps = properties?[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
      guard gps.keys.allSatisfy({ $0 == kCGImagePropertyGPSVersion }) else { return true }
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

  /// The paths of the top-level tags that hold a position, in any namespace: the EXIF GPS tags
  /// in EXIF or XMP, a drone's (DJI's `drone-dji:GpsLatitude`) and structures such as IPTC's
  /// `Iptc4xmpExt:LocationShown`, which go whole, the place names in them included.
  private static func locationTags(_ metadata: CGImageMetadata) -> [String] {
    let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag] ?? []
    return tags.compactMap { tag in
      guard holdsLocation(tag), let prefix = CGImageMetadataTagCopyPrefix(tag) as String?,
        let name = CGImageMetadataTagCopyName(tag) as String?
      else { return nil }
      return "\(prefix):\(name)"
    }
  }

  private static func holdsLocation(_ tag: CGImageMetadataTag) -> Bool {
    if let name = CGImageMetadataTagCopyName(tag) as String?, namesLocation(name) { return true }
    return children(tag).contains(where: holdsLocation)
  }

  /// The names `XmpGps` in LocationRemoval.kt takes for a location's; the version and the GPS
  /// IFD's pointer hold none.
  private static func namesLocation(_ name: String) -> Bool {
    let lowercased = name.lowercased()
    guard lowercased != "gpsversionid", lowercased != "gpsinfo" else { return false }
    return lowercased.hasPrefix("gps")
      || ["latitude", "longitude", "altitude"].contains(where: lowercased.contains)
      || ["Lat", "Lon", "Lng"].contains(where: name.hasSuffix)
  }

  /// A structure's fields or an array's items.
  private static func children(_ tag: CGImageMetadataTag) -> [CGImageMetadataTag] {
    let value = CGImageMetadataTagCopyValue(tag)
    let items: [AnyObject]
    if let structure = value as? NSDictionary {
      items = structure.allValues as [AnyObject]
    } else if let array = value as? NSArray {
      items = array as [AnyObject]
    } else {
      return []
    }
    return items.compactMap { item in
      CFGetTypeID(item) == CGImageMetadataTagGetTypeID() ? (item as! CGImageMetadataTag) : nil
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
