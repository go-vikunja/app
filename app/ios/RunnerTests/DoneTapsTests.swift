import XCTest

final class DoneTapsTests: XCTestCase {
  private var container: URL!
  private var widgets: URL { container.appendingPathComponent("widgets", isDirectory: true) }

  override func setUpWithError() throws {
    container = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    AppGroupStore.container = container
  }

  override func tearDownWithError() throws {
    AppGroupStore.container = nil
    try FileManager.default.removeItem(at: container)
  }

  func testATapGoesToTheOutboxAndThePendingListInTheAppsFormat() throws {
    let dueAt = Date(timeIntervalSince1970: 1_793_000_000.1236)
    let before = Int64(Date().timeIntervalSince1970 * 1000)

    XCTAssertTrue(try record("account-1", 12, ShownRow(dueAt: dueAt)))

    let outbox = try names(in: "outbox")
    XCTAssertEqual(outbox.count, 1)
    let text = try String(contentsOf: url("outbox/\(outbox[0])"), encoding: .utf8)
    let tap = try object(text)
    XCTAssertEqual(tap["version"] as? Int, 2)
    XCTAssertEqual(tap["accountId"] as? String, "account-1")
    XCTAssertEqual(tap["taskId"] as? Int, 12)
    XCTAssertEqual(tap["dueAt"] as? Int64, 1_793_000_000_124)
    XCTAssertEqual("\(try XCTUnwrap(tap["id"] as? String)).json", outbox[0])
    XCTAssertGreaterThanOrEqual(try XCTUnwrap(tap["createdAt"] as? Int64), before)
    // The app's reader takes whole milliseconds only.
    XCTAssertNotNil(text.range(of: #""createdAt":\d+[,}]"#, options: .regularExpression))
    XCTAssertNotNil(text.range(of: #""dueAt":\d+[,}]"#, options: .regularExpression))

    let entries = try XCTUnwrap(try json("ios-pending.json")["entries"] as? [[String: Any]])
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries.first?["id"] as? String, tap["id"] as? String)
    XCTAssertEqual(try names(in: ""), ["ios-pending.json", "outbox"])
  }

  func testWhatTheRowShowedSetsTheVersion() throws {
    XCTAssertTrue(try record("a", 1, nil))
    XCTAssertTrue(try record("a", 2, ShownRow(dueAt: nil)))

    let taps = try names(in: "outbox").map { try json("outbox/\($0)") }
    let byTask = Dictionary(uniqueKeysWithValues: taps.map { ($0["taskId"] as? Int ?? 0, $0) })
    XCTAssertEqual(byTask[1]?["version"] as? Int, 1)
    XCTAssertEqual(byTask[2]?["version"] as? Int, 2)
    XCTAssertNil(byTask[1]?["dueAt"])
    XCTAssertNil(byTask[2]?["dueAt"])
  }

  func testAnAccountIdThatIsNoSafeFileNameIsIgnored() throws {
    let unsafe = ["", ".", "..", ".hidden", "../outside", "a/b", "a b", "ä", "a\u{0}b", "a\\b"]
    for accountId in unsafe {
      XCTAssertFalse(try record(accountId, 1, nil), accountId.debugDescription)
    }

    XCTAssertFalse(FileManager.default.fileExists(atPath: widgets.path))
  }

  func testASecondTapBeforeTheAppImportedTheFirstIsIgnored() throws {
    XCTAssertTrue(try record("a", 7, nil))
    XCTAssertFalse(try record("a", 7, ShownRow(dueAt: Date())))
    XCTAssertEqual(try names(in: "outbox").count, 1)

    XCTAssertTrue(try record("a", 8, nil))
    XCTAssertTrue(try record("b", 7, nil))
    XCTAssertEqual(try names(in: "outbox").count, 3)
    XCTAssertEqual(try pendingIds().count, 3)
  }

  func testATapAfterTheImportIsRecordedAgain() throws {
    XCTAssertTrue(try record("a", 7, nil))
    try importOutbox()

    XCTAssertTrue(try record("a", 7, nil))

    XCTAssertEqual(try names(in: "outbox").count, 1)
    XCTAssertEqual(try pendingIds().count, 2)
  }

  func testATappedRowStaysHiddenUntilTheAppWroteTheListAfterTheImport() throws {
    let beforeTap = Date(timeIntervalSinceNow: -60)
    let afterTap = Date(timeIntervalSinceNow: 60)
    XCTAssertTrue(try record("a", 7, nil))

    XCTAssertEqual(DoneTaps.hiddenTaskIds(accountId: "a", listGeneratedAt: beforeTap), [7])
    XCTAssertEqual(DoneTaps.hiddenTaskIds(accountId: "a", listGeneratedAt: afterTap), [7])
    XCTAssertEqual(DoneTaps.hiddenTaskIds(accountId: "b", listGeneratedAt: beforeTap), [])

    try importOutbox()

    XCTAssertEqual(DoneTaps.hiddenTaskIds(accountId: "a", listGeneratedAt: beforeTap), [7])
    XCTAssertEqual(DoneTaps.hiddenTaskIds(accountId: "a", listGeneratedAt: afterTap), [])
  }

  func testImportedTapsAreForgottenAfterThreeDaysAndQueuedOnesKept() throws {
    let day = 24.0 * 3600
    try write(
      pending: [
        ("imported-old", Date(timeIntervalSinceNow: -4 * day)),
        ("imported-recent", Date(timeIntervalSinceNow: -2 * day)),
        ("queued-old", Date(timeIntervalSinceNow: -4 * day)),
      ])
    try write(Data("{}".utf8), to: "outbox/queued-old.json")

    XCTAssertTrue(try record("a", 99, nil))

    let ids = try pendingIds()
    XCTAssertEqual(ids.count, 3)
    XCTAssertTrue(ids.isSuperset(of: ["imported-recent", "queued-old"]))
    XCTAssertFalse(ids.contains("imported-old"))
  }

  private func record(_ accountId: String, _ taskId: Int, _ shown: ShownRow?) throws -> Bool {
    try DoneTaps.record(accountId: accountId, taskId: taskId, shown: shown)
  }

  private func url(_ path: String) -> URL {
    widgets.appendingPathComponent(path)
  }

  private func names(in directory: String) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: url(directory).path).sorted()
  }

  private func object(_ text: String) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
  }

  private func json(_ path: String) throws -> [String: Any] {
    try object(String(contentsOf: url(path), encoding: .utf8))
  }

  private func pendingIds() throws -> Set<String> {
    let entries = try XCTUnwrap(try json("ios-pending.json")["entries"] as? [[String: Any]])
    return Set(entries.compactMap { $0["id"] as? String })
  }

  /// What the app does once it has marked the tasks done.
  private func importOutbox() throws {
    for name in try names(in: "outbox") {
      try FileManager.default.removeItem(at: url("outbox/\(name)"))
    }
  }

  private func write(pending: [(id: String, createdAt: Date)]) throws {
    let entries = pending.enumerated().map { index, entry in
      [
        "version": 1, "id": entry.id, "accountId": "a", "taskId": index + 1,
        "createdAt": Int64(entry.createdAt.timeIntervalSince1970 * 1000),
      ] as [String: Any]
    }
    try write(
      JSONSerialization.data(withJSONObject: ["version": 1, "entries": entries]),
      to: "ios-pending.json")
  }

  private func write(_ data: Data, to path: String) throws {
    try FileManager.default.createDirectory(
      at: url(path).deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url(path))
  }
}
