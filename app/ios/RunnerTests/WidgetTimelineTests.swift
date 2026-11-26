import XCTest

/// The widget extension's timeline, built as WidgetKit asks for it from the files the app
/// writes into the App Group (app/lib/core/widgets/widget_snapshot.dart), here a folder of
/// the test's own.
final class WidgetTimelineTests: XCTestCase {
  private var container: URL!
  private var widgets: URL { container.appendingPathComponent("widgets", isDirectory: true) }

  private let now = Date(timeIntervalSince1970: 1_793_000_000)
  private var dueSoon: Date { now.addingTimeInterval(3600) }
  private var midnight: Date { now.addingTimeInterval(6 * 3600) }
  private let selection = ListSelection(
    accountId: "a", key: "a.overdue", kind: .overdue,
    openLink: URL(string: "vikunja-io.vikunja.app://widget/list?account=a&kind=overdue"))

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

  // MARK: The timeline

  func testARowTurnsOverdueAtItsDueInstantAndSpeaksAsOverdueFromThen() throws {
    try writeSnapshot(rows: [row(1, dueAt: dueSoon, tone: "today")], total: 1)

    let entries = timeline().entries

    XCTAssertEqual(entries.map(\.date), [now, dueSoon, midnight])
    let before = try list(entries[0]).rows[0]
    XCTAssertEqual(before.dueTone, .today)
    XCTAssertEqual(before.semanticsLabel, "Task 1\nDue Today, 15:00")
    let after = try list(entries[1]).rows[0]
    XCTAssertEqual(after.dueTone, .overdue)
    XCTAssertEqual(after.semanticsLabel, "Task 1\nOverdue, due Today, 15:00")
    XCTAssertEqual(after.dueLabel, "Today, 15:00")
  }

  func testFromMidnightTheRowsShowDatesUnderTheNotice() throws {
    try writeSnapshot(
      rows: [row(1, dueAt: now.addingTimeInterval(86_400), tone: "later")], total: 1)

    let entries = timeline().entries

    let today = try list(entries[0])
    XCTAssertNil(today.notice)
    XCTAssertEqual(today.rows[0].dueLabel, "Today, 15:00")
    let stale = try list(XCTUnwrap(entries.first { $0.date == midnight }))
    XCTAssertEqual(stale.notice, "Open Vikunja to update")
    XCTAssertEqual(stale.rows[0].dueLabel, "Oct 26, 15:00")
    XCTAssertEqual(stale.rows[0].semanticsLabel, "Task 1\nDue Oct 26, 15:00")
    XCTAssertEqual(timeline().reloadDate, midnight)
  }

  func testTheCountLeavesOutTappedRowsAndSaysSoInTheAppsWords() throws {
    try writeSnapshot(rows: [row(1), row(2)], total: 3, counts: counts(1...3))

    let before = try list(timeline().entries[0])
    XCTAssertEqual(before.total, 3)
    XCTAssertEqual(before.countLabel, "3 tasks")
    XCTAssertTrue(try DoneTaps.record(accountId: "a", taskId: 1, shown: nil))

    let after = try list(timeline().entries[0])

    XCTAssertEqual(after.rows.map(\.id), [2])
    XCTAssertEqual(after.total, 2)
    XCTAssertEqual(after.countLabel, "2 tasks")
    XCTAssertEqual(after.moreLabel(shown: 1), "+1 more")
    XCTAssertNil(after.moreLabel(shown: 2))
  }

  func testATappedRowThatJoinedLaterLeavesTheCountOnceItJoins() throws {
    try writeSnapshot(
      rows: [row(1), row(2, dueAt: dueSoon, tone: "today", showsFrom: dueSoon)], total: 1,
      counts: counts(0...2), joinsAt: [dueSoon])
    XCTAssertTrue(try DoneTaps.record(accountId: "a", taskId: 2, shown: nil))

    let entries = timeline().entries

    XCTAssertEqual(entries.map(\.date), [now, dueSoon, midnight])
    for entry in entries {
      let content = try list(entry)
      XCTAssertEqual(content.rows.map(\.id), [1])
      XCTAssertEqual(content.total, 1)
      XCTAssertEqual(content.countLabel, "1 task")
    }
  }

  func testAListWrittenBeforeTheCountTextsKeepsItsOwnWhereTheyStillFit() throws {
    try writeSnapshot(rows: [row(1), row(2)], total: 5, moreLabel: "+3 more")

    let content = try list(timeline().entries[0])

    XCTAssertEqual(content.countLabel, "5 tasks")
    XCTAssertEqual(content.moreLabel(shown: 2), "+3 more")
    XCTAssertNil(content.moreLabel(shown: 1))
    XCTAssertTrue(try DoneTaps.record(accountId: "a", taskId: 1, shown: nil))
    let tapped = try list(timeline().entries[0])
    XCTAssertEqual(tapped.total, 4)
    XCTAssertNil(tapped.countLabel)
    XCTAssertEqual(tapped.spokenCount, 4.formatted())
  }

  func testWithMoreInstantsThanEntriesTheWidgetReloadsAtTheFirstLeftOut() throws {
    let joins = (1...60).map { now.addingTimeInterval(Double($0) * 60) }
    try writeSnapshot(rows: [row(1)], total: 1, counts: counts(0...61), joinsAt: joins)

    let timeline = timeline()

    XCTAssertEqual(timeline.entries.count, 48)
    XCTAssertEqual(timeline.entries.last?.date, joins[46])
    XCTAssertEqual(timeline.reloadDate, joins[47])
  }

  func testATaskThatJoinsTheListShowsFromItsInstantWithTheCountOfEachEntry() throws {
    let joinsLater = now.addingTimeInterval(2 * 3600)
    try writeSnapshot(
      rows: [row(1), row(2, dueAt: dueSoon, tone: "today", showsFrom: dueSoon)], total: 1,
      counts: counts(0...3), joinsAt: [dueSoon, joinsLater])

    let entries = timeline().entries

    XCTAssertEqual(entries.map(\.date), [now, dueSoon, joinsLater, midnight])
    let first = try list(entries[0])
    XCTAssertEqual(first.rows.map(\.id), [1])
    XCTAssertEqual(first.total, 1)
    XCTAssertEqual(first.countLabel, "1 task")
    let joined = try list(entries[1])
    XCTAssertEqual(joined.rows.map(\.id), [1, 2])
    XCTAssertEqual(joined.rows[1].dueTone, .overdue)
    XCTAssertEqual(joined.total, 2)
    XCTAssertEqual(joined.countLabel, "2 tasks")
    XCTAssertEqual(joined.moreLabel(shown: 1), "+1 more")
    let beyondTheRows = try list(entries[2])
    XCTAssertEqual(beyondTheRows.rows.map(\.id), [1, 2])
    XCTAssertEqual(beyondTheRows.total, 3)
    XCTAssertEqual(beyondTheRows.countLabel, "3 tasks")
  }

  func testWithTitlesHiddenTheCountTextOfEachEntryIsTheAppsOwn() throws {
    try writeSnapshot(
      rows: [], total: 0,
      counts: [
        ["n": 0, "label": "No tasks"],
        [
          "n": 1, "label": "1 task", "more": "+1 more",
          "empty": ["title": "1 task", "body": "Open Vikunja to see it"],
        ],
      ], joinsAt: [dueSoon], empty: ["title": "Nothing overdue"])

    let entries = timeline().entries

    XCTAssertEqual(try list(entries[0]).empty?.title, "Nothing overdue")
    let joined = try list(entries[1])
    XCTAssertEqual(joined.total, 1)
    XCTAssertEqual(joined.empty?.title, "1 task")
    XCTAssertEqual(joined.empty?.body, "Open Vikunja to see it")
  }

  func testAListWithoutItsSnapshotAsksToOpenTheAppInItsAccount() throws {
    let entries = timeline().entries

    XCTAssertEqual(entries.count, 1)
    guard case .message(_, let text, let link) = entries[0].content else {
      return XCTFail("Expected a message, got \(entries[0].content)")
    }
    XCTAssertEqual(text, "Open Vikunja to load this list")
    XCTAssertEqual(link, selection.openLink)
  }

  // MARK: Entry dates

  func testEntriesAreAtNowAndEveryLaterInstantARowMayChangeAtOnce() throws {
    let change = now.addingTimeInterval(600)
    let join = now.addingTimeInterval(1200)
    try writeSnapshot(
      rows: [
        row(1, dueAt: now.addingTimeInterval(-60)), row(2, dueAt: dueSoon), row(3, dueAt: dueSoon),
      ],
      total: 3, changesAt: [change, now.addingTimeInterval(-10)], joinsAt: [join])
    let snapshot = try XCTUnwrap(ListSnapshot.load(key: selection.key))

    XCTAssertEqual(
      snapshot.entryDates(rows: snapshot.rows ?? [], now: now, limit: 48),
      [now, change, join, dueSoon, midnight])
    XCTAssertEqual(
      snapshot.entryDates(rows: snapshot.rows ?? [], now: now, limit: 3), [now, change, join])
  }

  // MARK: The configuration

  func testAWidgetWithoutAnAccountShowsTheActiveOneAndAsksForOneWithoutCatalogs() throws {
    XCTAssertTrue(isNoAccount(TasksWidgetIntent().resolution))
    try writeCatalog("b", name: "Bob")
    try writeCatalog("a", name: "Zoe")
    try writeHost(activeAccountId: "a", linkKey: nil)

    guard case .selection(let chosen) = TasksWidgetIntent().resolution else {
      return XCTFail("Expected a selection")
    }

    XCTAssertEqual(chosen.accountId, "a")
    XCTAssertEqual(chosen.key, "a.today")
    XCTAssertEqual(chosen.kind, .today)
  }

  func testUpcomingResolvesToTheSnapshotOfItsDaysWithALinkInItsAccount() throws {
    try writeCatalog("a", name: "Alice")
    try writeHost(activeAccountId: "a", linkKey: "KEY")
    let intent = TasksWidgetIntent()
    intent.account = AccountEntity(AccountCatalog.Account(id: "a", name: "Alice"))
    intent.kind = .upcoming
    intent.days = .fourteen

    guard case .selection(let chosen) = intent.resolution else {
      return XCTFail("Expected a selection")
    }

    XCTAssertEqual(chosen.key, "a.upcoming_14")
    XCTAssertEqual(
      chosen.openLink?.absoluteString,
      "vikunja-io.vikunja.app://widget/list?account=a&days=14&k=KEY&kind=upcoming")
  }

  func testAProjectOfAnotherAccountOrARemovedAccountIsNotShown() throws {
    try writeCatalog("a", name: "Alice")
    let intent = TasksWidgetIntent()
    intent.account = AccountEntity(AccountCatalog.Account(id: "a", name: "Alice"))
    intent.kind = .project
    intent.project = ProjectEntity(item: project(accountId: "b"))
    guard case .missingItem(let accountId, .project) = intent.resolution else {
      return XCTFail("Expected a missing project")
    }
    XCTAssertEqual(accountId, "a")

    intent.project = ProjectEntity(item: project(accountId: "a"))
    guard case .selection(let chosen) = intent.resolution else {
      return XCTFail("Expected a selection")
    }
    XCTAssertEqual(chosen.key, "a.project_5")
    XCTAssertEqual(chosen.projectId, 5)

    intent.account = AccountEntity(removed: "gone")
    guard case .accountRemoved = intent.resolution else {
      return XCTFail("Expected a removed account")
    }
  }

  // MARK: Links

  func testLinksCarryTheRowsAccountAndTheInstallsKey() throws {
    try writeHost(activeAccountId: "b", linkKey: "KEY")
    var foreign = row(1)
    foreign["link"] = "https://example.com/task/1"
    try writeSnapshot(rows: [foreign, row(2)], total: 2)

    let content = try list(timeline().entries[0])

    XCTAssertEqual(content.accountId, "a")
    XCTAssertEqual(
      content.rows[0].link?.absoluteString,
      "vikunja-io.vikunja.app://widget/task/1?account=a&k=KEY")
    XCTAssertEqual(
      content.rows[1].link?.absoluteString,
      "vikunja-io.vikunja.app://widget/task/2?account=a&k=APPKEY")
    XCTAssertEqual(
      WidgetLinks.open(accountId: "a")?.absoluteString,
      "vikunja-io.vikunja.app://widget/open?account=a&k=KEY")
    XCTAssertEqual(
      WidgetLinks.newTask(accountId: "a", projectId: 5)?.absoluteString,
      "vikunja-io.vikunja.app://widget/new-task?account=a&k=KEY&project=5")
  }

  func testWithoutTheKeyALinkCarriesNone() throws {
    XCTAssertEqual(
      WidgetLinks.task(7, accountId: "a")?.absoluteString,
      "vikunja-io.vikunja.app://widget/task/7?account=a")
  }

  // MARK: Request markers

  func testMarkingAKnownListRenewsItsMarker() throws {
    SnapshotRequests.mark("a.project_5")
    try age("requests/a.project_5", by: 2 * 86_400)

    SnapshotRequests.mark("a.project_5")

    let renewed = try XCTUnwrap(AppGroupStore.modificationDate("requests/a.project_5"))
    XCTAssertLessThan(abs(renewed.timeIntervalSinceNow), 60)
  }

  func testPruningKeepsTheAskingWidgetsListThoughTheSystemDoesNotListItYet() throws {
    for key in ["asking", "placed", "gone", "young"] {
      SnapshotRequests.mark(key)
    }
    for key in ["asking", "placed", "gone"] {
      try age("requests/\(key)", by: 2 * 86_400)
    }

    SnapshotRequests.sync(placed: ["placed"], asking: "asking", now: Date())

    XCTAssertEqual(AppGroupStore.names(in: "requests"), ["asking", "placed", "young"])
    for key in ["asking", "placed"] {
      let date = try XCTUnwrap(AppGroupStore.modificationDate("requests/\(key)"))
      XCTAssertLessThan(abs(date.timeIntervalSinceNow), 60, key)
    }
  }

  func testPruningRemovesOnlyMarkersADayOld() throws {
    SnapshotRequests.mark("old")
    SnapshotRequests.mark("recent")
    try age("requests/old", by: 25 * 3600)
    try age("requests/recent", by: 23 * 3600)

    SnapshotRequests.prune(keeping: [], now: Date())

    XCTAssertEqual(AppGroupStore.names(in: "requests"), ["recent"])
  }

  // MARK: Helpers

  private func timeline() -> TasksTimeline {
    TasksTimeline(resolution: .selection(selection), now: now)
  }

  private func list(_ entry: TasksEntry) throws -> ListContent {
    guard case .list(let content) = entry.content else {
      XCTFail("Expected a list, got \(entry.content)")
      throw CocoaError(.featureUnsupported)
    }
    return content
  }

  private func isNoAccount(_ resolution: ListResolution) -> Bool {
    if case .noAccount = resolution { return true }
    return false
  }

  private func project(accountId: String) -> ListItem {
    ListItem(
      id: "\(accountId).project_5", accountId: accountId, itemId: 5, title: "Home",
      writable: true)
  }

  private func milliseconds(_ date: Date) -> Int64 {
    Int64(date.timeIntervalSince1970 * 1000)
  }

  private func row(
    _ id: Int, dueAt: Date? = nil, tone: String = "overdue", showsFrom: Date? = nil
  ) -> [String: Any] {
    var row: [String: Any] = [
      "id": id, "title": "Task \(id)", "tone": tone, "canDone": true,
      "due": "Today, 15:00", "dueAbsolute": "Oct 26, 15:00",
      "label": "Task \(id)\nDue Today, 15:00",
      "labelOverdue": "Task \(id)\nOverdue, due Today, 15:00",
      "labelAbsolute": "Task \(id)\nDue Oct 26, 15:00",
      "labelAbsoluteOverdue": "Task \(id)\nOverdue, due Oct 26, 15:00",
      "doneLabel": "Mark “Task \(id)” as done",
      "link": "vikunja-io.vikunja.app://widget/task/\(id)?account=a&k=APPKEY",
    ]
    if let dueAt { row["dueAt"] = milliseconds(dueAt) }
    if let showsFrom { row["showsFrom"] = milliseconds(showsFrom) }
    return row
  }

  private func counts(_ range: ClosedRange<Int>) -> [[String: Any]] {
    range.map { n in
      var text: [String: Any] = ["n": n, "label": n == 1 ? "1 task" : "\(n) tasks"]
      if n > 0 { text["more"] = "+\(n) more" }
      return text
    }
  }

  private func writeSnapshot(
    rows: [[String: Any]], total: Int, counts: [[String: Any]]? = nil,
    changesAt: [Date] = [], joinsAt: [Date]? = nil, empty: [String: Any]? = nil,
    moreLabel: String? = nil
  ) throws {
    var snapshot: [String: Any] = [
      "v": 1, "key": selection.key, "account": "a", "state": "ok", "title": "Overdue",
      "generatedAt": milliseconds(now.addingTimeInterval(-60)),
      "validUntil": milliseconds(midnight), "changesAt": changesAt.map(milliseconds),
      "rows": rows, "total": total, "countLabel": "\(total) tasks",
      "staleNotice": "Open Vikunja to update",
    ]
    if let counts { snapshot["counts"] = counts }
    if let joinsAt { snapshot["joinsAt"] = joinsAt.map(milliseconds) }
    if let empty { snapshot["empty"] = empty }
    if let moreLabel { snapshot["moreLabel"] = moreLabel }
    try write(snapshot, to: "snapshots/\(selection.key).json")
  }

  private func writeCatalog(_ accountId: String, name: String) throws {
    try write(
      [
        "v": 1, "account": ["id": accountId, "name": name, "host": "example.com"],
        "lists": [
          ["key": "\(accountId).today", "kind": "today", "title": "Today"],
          ["key": "\(accountId).upcoming_14", "kind": "upcoming", "days": 14, "title": "Next 14"],
          ["key": "\(accountId).project_5", "kind": "project", "id": 5, "title": "Home"],
        ],
      ], to: "catalogs/\(accountId).json")
  }

  private func writeHost(activeAccountId: String, linkKey: String?) throws {
    var host: [String: Any] = ["activeAccountId": activeAccountId]
    if let linkKey { host["linkKey"] = linkKey }
    try write(host, to: "host.json")
  }

  private func write(_ object: Any, to path: String) throws {
    let url = widgets.appendingPathComponent(path)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: object).write(to: url)
  }

  private func age(_ path: String, by interval: TimeInterval) throws {
    try FileManager.default.setAttributes(
      [.modificationDate: Date(timeIntervalSinceNow: -interval)],
      ofItemAtPath: widgets.appendingPathComponent(path).path)
  }
}
