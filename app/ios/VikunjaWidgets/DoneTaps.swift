import Foundation

/// The app imports each outbox file exactly once, marks the task done
/// through its own outbox and then deletes the file.
struct DoneTap: Codable {
  var version = 1
  var id: String
  var accountId: String
  var taskId: Int
  var createdAt: Date

  private enum CodingKeys: String, CodingKey {
    case version, id, accountId, taskId, createdAt
  }

  init(id: String, accountId: String, taskId: Int, createdAt: Date) {
    self.id = id
    self.accountId = accountId
    self.taskId = taskId
    self.createdAt = createdAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    id = try container.decode(String.self, forKey: .id)
    accountId = try container.decode(String.self, forKey: .accountId)
    taskId = try container.decode(Int.self, forKey: .taskId)
    createdAt = Date(
      timeIntervalSince1970: try container.decode(Double.self, forKey: .createdAt) / 1000)
  }

  // Whole milliseconds: the encoder's millisecondsSince1970 writes a
  // fraction, which the app's reader refuses as no integer.
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(id, forKey: .id)
    try container.encode(accountId, forKey: .accountId)
    try container.encode(taskId, forKey: .taskId)
    try container.encode(
      Int64((createdAt.timeIntervalSince1970 * 1000).rounded()), forKey: .createdAt)
  }
}

enum DoneTaps {
  private struct Pending: Codable {
    var version = 1
    var entries: [DoneTap] = []
  }

  private static let lock = NSLock()
  private static let keptAfterImport: TimeInterval = 3 * 24 * 3600

  static func record(accountId: String, taskId: Int) throws {
    guard AppGroupStore.isFileSafe(accountId) else { return }
    try lock.withLock {
      var pending = AppGroupStore.read(Pending.self, AppGroupStore.pendingFile) ?? Pending()
      let now = Date()
      pending.entries.removeAll {
        !isQueued($0) && now.timeIntervalSince($0.createdAt) > keptAfterImport
      }
      // A second tap before the reload would move a repeating task twice.
      if pending.entries.contains(where: {
        $0.accountId == accountId && $0.taskId == taskId && isQueued($0)
      }) {
        return
      }
      let tap = DoneTap(id: UUID().uuidString, accountId: accountId, taskId: taskId, createdAt: now)
      try AppGroupStore.write(tap, to: outboxPath(tap.id))
      pending.entries.append(tap)
      try AppGroupStore.write(pending, to: AppGroupStore.pendingFile)
    }
  }

  /// Rows tapped done stay hidden until the app has imported the tap and
  /// written the list again.
  static func hiddenTaskIds(accountId: String, listGeneratedAt: Date) -> Set<Int> {
    let entries = AppGroupStore.read(Pending.self, AppGroupStore.pendingFile)?.entries ?? []
    return Set(
      entries.filter {
        $0.accountId == accountId && ($0.createdAt > listGeneratedAt || isQueued($0))
      }.map(\.taskId))
  }

  private static func isQueued(_ tap: DoneTap) -> Bool {
    AppGroupStore.exists(outboxPath(tap.id))
  }

  private static func outboxPath(_ id: String) -> String {
    "\(AppGroupStore.outboxDirectory)/\(id).json"
  }
}
