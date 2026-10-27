import Foundation

/// The files shared with the app under `<App Group>/widgets` (the contract of
/// plugins/rurana_widgets). The app writes catalogs, snapshots and host.json;
/// the extension writes only the outbox, its pending list and the request
/// markers. No file lock is ever held: a process suspended while holding one
/// in the shared container is killed (0xdead10cc), so every write is a
/// rename of a finished temp file.
enum AppGroupStore {
  static let groupIdentifier = "group.dev.coderoftime.vikunja"

  static let catalogsDirectory = "catalogs"
  static let snapshotsDirectory = "snapshots"
  static let outboxDirectory = "outbox"
  static let requestsDirectory = "requests"
  static let hostFile = "host.json"
  static let pendingFile = "ios-pending.json"

  private static var root: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
      .appendingPathComponent("widgets", isDirectory: true)
  }

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    return decoder
  }()

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    encoder.outputFormatting = .sortedKeys
    return encoder
  }()

  /// Keys and ids become file names; anything else could leave the directory.
  static func isFileSafe(_ name: String) -> Bool {
    !name.isEmpty && !name.hasPrefix(".")
      && name.unicodeScalars.allSatisfy { CharacterSet.fileSafe.contains($0) }
  }

  static func read<T: Decodable>(_ type: T.Type, _ path: String) -> T? {
    guard let url = root?.appendingPathComponent(path),
      let data = try? Data(contentsOf: url)
    else { return nil }
    return try? decoder.decode(type, from: data)
  }

  static func readAll<T: Decodable>(_ type: T.Type, in directory: String) -> [T] {
    names(in: directory).filter { $0.hasSuffix(".json") }
      .compactMap { read(type, "\(directory)/\($0)") }
  }

  static func names(in directory: String) -> [String] {
    guard let url = root?.appendingPathComponent(directory, isDirectory: true),
      let names = try? FileManager.default.contentsOfDirectory(atPath: url.path)
    else { return [] }
    return names.filter { !$0.hasPrefix(".") && !$0.hasSuffix(".tmp") }.sorted()
  }

  static func exists(_ path: String) -> Bool {
    guard let url = root?.appendingPathComponent(path) else { return false }
    return FileManager.default.fileExists(atPath: url.path)
  }

  static func modificationDate(_ path: String) -> Date? {
    guard let url = root?.appendingPathComponent(path) else { return nil }
    return (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate]
      as? Date
  }

  static func write<T: Encodable>(_ value: T, to path: String) throws {
    try write(encoder.encode(value), to: path)
  }

  /// The app's readers skip names ending in ".tmp", so they never see a
  /// half-written file.
  static func write(_ data: Data, to path: String) throws {
    guard let url = root?.appendingPathComponent(path) else {
      throw CocoaError(.fileNoSuchFile)
    }
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let temp = url.appendingPathExtension("tmp")
    try data.write(to: temp, options: .completeFileProtectionUntilFirstUserAuthentication)
    guard rename(temp.path, url.path) == 0 else {
      try? FileManager.default.removeItem(at: temp)
      throw CocoaError(.fileWriteUnknown)
    }
  }

  /// An empty file needs no temp file: it never exists half-written.
  static func createEmptyFile(_ path: String) {
    guard let url = root?.appendingPathComponent(path) else { return }
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    FileManager.default.createFile(
      atPath: url.path, contents: nil,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
  }

  static func remove(_ path: String) {
    guard let url = root?.appendingPathComponent(path) else { return }
    try? FileManager.default.removeItem(at: url)
  }
}

extension CharacterSet {
  fileprivate static let fileSafe = CharacterSet(
    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
}
