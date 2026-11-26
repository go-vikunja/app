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
    let properties = try self.properties(url)
    XCTAssertEqual(properties[kCGImagePropertyOrientation] as? Int, 6)
    XCTAssertEqual(
      (properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFMake]
        as? String, "Camera")
    XCTAssertEqual(
      (properties[kCGImagePropertyPNGDictionary] as? [CFString: Any])?[kCGImagePropertyPNGTitle]
        as? String, "Garden")
    XCTAssertEqual(properties[kCGImagePropertyDPIWidth] as? Int, 144)
  }

  func testAnAnimatedPngLosesItsLocationAndKeepsItsFramesTimingAndLoops() throws {
    let url = folder.appendingPathComponent("animated.png")
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 2, nil))
    CGImageDestinationSetProperties(
      destination,
      [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 3]] as CFDictionary)
    for (delay, gps) in [(0.25, Self.gps as Any?), (0.5, nil)] {
      var properties: [CFString: Any] = [
        kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: delay]
      ]
      properties[kCGImagePropertyGPSDictionary] = gps
      CGImageDestinationAddImage(destination, try pattern(), properties as CFDictionary)
    }
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    XCTAssertTrue(try hasLocation(url))

    XCTAssertNil(removeLocation(from: url))

    XCTAssertFalse(try hasLocation(url))
    let source = try source(url)
    XCTAssertEqual(CGImageSourceGetCount(source), 2)
    let file = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
    XCTAssertEqual(
      (file?[kCGImagePropertyPNGDictionary] as? [CFString: Any])?[kCGImagePropertyAPNGLoopCount]
        as? Int, 3)
    let delays = (0..<2).map { index in
      let frame = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
      return (frame?[kCGImagePropertyPNGDictionary] as? [CFString: Any])?[
        kCGImagePropertyAPNGDelayTime] as? Double
    }
    XCTAssertEqual(delays, [0.25, 0.5])
  }

  func testAGpsVersionAloneIsNoLocationAndTheFileIsNotWrittenTo() throws {
    let url = try photo(
      .png,
      xmp: """
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
         <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about="" xmlns:exif="http://ns.adobe.com/exif/1.0/"
            exif:GPSVersionID="2.2.0.0"/>
         </rdf:RDF>
        </x:xmpmeta>
        """)
    XCTAssertTrue(try xmp(url).contains("GPSVersionID"))
    let before = try Data(contentsOf: url)
    let modified = try modificationDate(url)

    XCTAssertNil(removeLocation(from: url))

    XCTAssertEqual(try Data(contentsOf: url), before)
    XCTAssertEqual(try modificationDate(url), modified)
  }

  /// ImageMagick writes Exif tags as PNG text chunks; Image I/O does not read a chunk of its own
  /// name, so this stays (threat model R36).
  func testAGpsNamedPngTextChunkIsNotSeenAndStays() throws {
    let url = try photo(.png, withLocation: false)
    var bytes = [UInt8](try Data(contentsOf: url))
    let chunk = Self.pngChunk(
      "tEXt", Array("exif:GPSLatitude".utf8) + [0] + Array("52/1, 31/1, 12/1".utf8))
    bytes.insert(contentsOf: chunk, at: 33)
    try Data(bytes).write(to: url)
    XCTAssertFalse(try hasLocation(url))

    XCTAssertNil(removeLocation(from: url))

    XCTAssertEqual(try Data(contentsOf: url), Data(bytes))
  }

  func testADronesPositionAndIptcLocationsInXmpLeaveAJpegAndTheRestStays() throws {
    let url = try photo(.jpeg, xmp: Self.droneXmp)
    let pixelsBefore = try pixels(url)
    XCTAssertTrue(try xmp(url).contains("GpsLatitude"))

    XCTAssertNil(removeLocation(from: url))

    try assertNoPosition(in: xmp(url))
    XCTAssertTrue(try xmp(url).contains("GimbalYawDegree"))
    XCTAssertEqual(try pixels(url), pixelsBefore)
  }

  func testADronesPositionAndIptcLocationsInXmpLeaveAPng() throws {
    let url = try photo(.png, xmp: Self.droneXmp)
    let pixelsBefore = try pixels(url)
    XCTAssertTrue(try xmp(url).contains("LocationShown"))

    XCTAssertNil(removeLocation(from: url))

    try assertNoPosition(in: xmp(url))
    XCTAssertTrue(try xmp(url).contains("GimbalYawDegree"))
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
    if type == .png {
      properties[kCGImagePropertyPNGDictionary] = [kCGImagePropertyPNGTitle: "Garden"]
      properties[kCGImagePropertyDPIWidth] = 144
      properties[kCGImagePropertyDPIHeight] = 144
    }
    if withLocation {
      properties[kCGImagePropertyGPSDictionary] = Self.gps
    }
    CGImageDestinationAddImage(destination, try pattern(), properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw XCTSkip("Image I/O cannot write \(type.identifier) here")
    }
    return url
  }

  private static let gps: [CFString: Any] = [
    kCGImagePropertyGPSLatitude: 52.52,
    kCGImagePropertyGPSLatitudeRef: "N",
    kCGImagePropertyGPSLongitude: 13.405,
    kCGImagePropertyGPSLongitudeRef: "E",
  ]

  /// Length, type, data and CRC-32, to go after the 8-byte signature and the 25-byte IHDR.
  private static func pngChunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
    let typed = Array(type.utf8) + data
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in typed {
      crc ^= UInt32(byte)
      for _ in 0..<8 { crc = crc & 1 == 1 ? 0xEDB8_8320 ^ (crc >> 1) : crc >> 1 }
    }
    return withUnsafeBytes(of: UInt32(data.count).bigEndian, Array.init) + typed
      + withUnsafeBytes(of: (crc ^ 0xFFFF_FFFF).bigEndian, Array.init)
  }

  /// As DJI drones write it (their own misspelt "Longtitude" included), with the IPTC
  /// location structures as photo tools add them.
  private static let droneXmp = """
    <x:xmpmeta xmlns:x="adobe:ns:meta/">
     <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about=""
        xmlns:drone-dji="http://www.dji.com/drone-dji/1.0/"
        xmlns:Iptc4xmpExt="http://iptc.org/std/Iptc4xmpExt/2008-02-29/"
        drone-dji:GpsLatitude="+52.520000" drone-dji:GpsLongtitude="+13.405000"
        drone-dji:AbsoluteAltitude="+34.50" drone-dji:LRFTargetLat="52.521234"
        drone-dji:GimbalYawDegree="+90.00">
       <Iptc4xmpExt:LocationCreated rdf:parseType="Resource">
        <Iptc4xmpExt:GPSLatitude>52,31.2N</Iptc4xmpExt:GPSLatitude>
        <Iptc4xmpExt:City>Berlin</Iptc4xmpExt:City>
       </Iptc4xmpExt:LocationCreated>
       <Iptc4xmpExt:LocationShown>
        <rdf:Bag>
         <rdf:li rdf:parseType="Resource">
          <Iptc4xmpExt:GPSLongitude>13,24.3E</Iptc4xmpExt:GPSLongitude>
         </rdf:li>
        </rdf:Bag>
       </Iptc4xmpExt:LocationShown>
      </rdf:Description>
     </rdf:RDF>
    </x:xmpmeta>
    """

  private func photo(_ type: UTType, xmp: String) throws -> URL {
    let url = folder.appendingPathComponent("drone").appendingPathExtension(
      try XCTUnwrap(type.preferredFilenameExtension))
    let metadata = try XCTUnwrap(CGImageMetadataCreateFromXMPData(Data(xmp.utf8) as CFData))
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
    CGImageDestinationAddImageAndMetadata(destination, try pattern(), metadata, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw XCTSkip("Image I/O cannot write \(type.identifier) here")
    }
    return url
  }

  private func xmp(_ url: URL) throws -> String {
    guard let metadata = CGImageSourceCopyMetadataAtIndex(try source(url), 0, nil),
      let data = CGImageMetadataCreateXMPData(metadata, nil)
    else { return "" }
    return String(decoding: data as Data, as: UTF8.self)
  }

  private func assertNoPosition(in xmp: String, line: UInt = #line) {
    for value in [
      "52.520000", "13.405000", "34.50", "52.521234", "52,31.2N", "13,24.3E", "GpsLatitude",
      "LocationCreated", "LocationShown",
    ] {
      XCTAssertFalse(xmp.contains(value), "\(value) stayed", line: line)
    }
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
