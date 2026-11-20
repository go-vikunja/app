import ImageIO
import UniformTypeIdentifiers
import XCTest

final class LocationRemovalTests: XCTestCase {
  private var folder: URL!

  override func setUpWithError() throws {
    folder = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: folder)
  }

  func testAJpegLosesItsLocationAndKeepsItsOrientationOtherTagsAndImageData() throws {
    let url = try photo(.jpeg, withLocation: true)
    let pixelsBefore = try pixels(url)
    XCTAssertTrue(try hasLocation(url))

    XCTAssertNil(removeLocation(from: url))

    XCTAssertFalse(try hasLocation(url))
    let properties = try self.properties(url)
    XCTAssertEqual(properties[kCGImagePropertyOrientation] as? Int, 6)
    XCTAssertEqual(
      (properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFMake]
        as? String, "Camera")
    XCTAssertEqual(try pixels(url), pixelsBefore)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["photo.jpeg"])
  }

  func testAHeicLosesItsLocationAndKeepsItsImageData() throws {
    guard
      (CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []).contains(UTType.heic.identifier)
    else { throw XCTSkip("Image I/O cannot write HEIC here") }
    let url = try photo(.heic, withLocation: true)
    let pixelsBefore = try pixels(url)
    XCTAssertTrue(try hasLocation(url))

    XCTAssertNil(removeLocation(from: url))

    XCTAssertFalse(try hasLocation(url))
    XCTAssertEqual(
      (try properties(url)[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[
        kCGImagePropertyTIFFMake] as? String, "Camera")
    XCTAssertEqual(try pixels(url), pixelsBefore)
  }

  func testAPngLosesItsLocationAndKeepsItsPixels() throws {
    let url = try photo(.png, withLocation: true)
    let pixelsBefore = try pixels(url)
    XCTAssertTrue(try hasLocation(url))

    XCTAssertNil(removeLocation(from: url))

    XCTAssertFalse(try hasLocation(url))
    XCTAssertEqual(try pixels(url), pixelsBefore)
  }

  func testAPhotoWithoutLocationIsNotWrittenTo() throws {
    let url = try photo(.jpeg, withLocation: false)
    let before = try Data(contentsOf: url)
    let modified = try modificationDate(url)

    XCTAssertNil(removeLocation(from: url))

    XCTAssertEqual(try Data(contentsOf: url), before)
    XCTAssertEqual(try modificationDate(url), modified)
  }

  func testAFileThatIsNoPhotoOrVideoIsLeftAlone() throws {
    let url = folder.appendingPathComponent("notes.txt")
    try Data("52.5200 N, 13.4050 E".utf8).write(to: url)

    XCTAssertNil(removeLocation(from: url))

    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "52.5200 N, 13.4050 E")
  }

  func testAnUnreadablePhotoFailsAndStaysAsItWas() throws {
    let url = folder.appendingPathComponent("broken.jpg")
    let bytes = Data("not a JPEG".utf8)
    try bytes.write(to: url)

    let failure = removeLocation(from: url)

    guard case .unreadable = failure as? LocationRemoval.Failure else {
      return XCTFail("Expected unreadable, got \(String(describing: failure))")
    }
    XCTAssertEqual(try Data(contentsOf: url), bytes)
  }

  private func removeLocation(from url: URL) -> Error? {
    let done = expectation(description: "removeLocation")
    var failure: Error?
    LocationRemoval.remove(from: url) { error in
      failure = error
      done.fulfill()
    }
    wait(for: [done], timeout: 30)
    return failure
  }

  private func photo(_ type: UTType, withLocation: Bool) throws -> URL {
    let url = folder.appendingPathComponent("photo").appendingPathExtension(
      try XCTUnwrap(type.preferredFilenameExtension))
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
    var properties: [CFString: Any] = [
      kCGImagePropertyOrientation: 6,
      kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Camera"],
    ]
    if withLocation {
      properties[kCGImagePropertyGPSDictionary] = [
        kCGImagePropertyGPSLatitude: 52.52,
        kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 13.405,
        kCGImagePropertyGPSLongitudeRef: "E",
      ]
    }
    CGImageDestinationAddImage(destination, try pattern(), properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw XCTSkip("Image I/O cannot write \(type.identifier) here")
    }
    return url
  }

  private func pattern() throws -> CGImage {
    let context = try XCTUnwrap(
      CGContext(
        data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    for x in stride(from: 0, to: 64, by: 8) {
      for y in stride(from: 0, to: 48, by: 8) {
        context.setFillColor(
          red: CGFloat(x) / 64, green: CGFloat(y) / 48, blue: CGFloat((x + y) % 24) / 24, alpha: 1)
        context.fill(CGRect(x: x, y: y, width: 8, height: 8))
      }
    }
    return try XCTUnwrap(context.makeImage())
  }

  private func source(_ url: URL) throws -> CGImageSource {
    try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
  }

  private func properties(_ url: URL) throws -> [CFString: Any] {
    try XCTUnwrap(
      CGImageSourceCopyPropertiesAtIndex(try source(url), 0, nil) as? [CFString: Any])
  }

  private func hasLocation(_ url: URL) throws -> Bool {
    let source = try source(url)
    return (0..<CGImageSourceGetCount(source)).contains { index in
      let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
      let tags =
        CGImageSourceCopyMetadataAtIndex(source, index, nil)
        .flatMap { CGImageMetadataCopyTags($0) as? [CGImageMetadataTag] } ?? []
      return properties?[kCGImagePropertyGPSDictionary] != nil
        || tags.contains { (CGImageMetadataTagCopyName($0) as String?)?.hasPrefix("GPS") == true }
    }
  }

  private func pixels(_ url: URL) throws -> Data {
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(try source(url), 0, nil))
    var data = Data(count: image.width * image.height * 4)
    try data.withUnsafeMutableBytes { buffer in
      let context = try XCTUnwrap(
        CGContext(
          data: buffer.baseAddress, width: image.width, height: image.height,
          bitsPerComponent: 8, bytesPerRow: image.width * 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return data
  }

  private func modificationDate(_ url: URL) throws -> Date? {
    try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
  }
}
