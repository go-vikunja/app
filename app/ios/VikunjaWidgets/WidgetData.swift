import Foundation

/// The JSON the app writes (app/lib/core/widgets/widget_catalog.dart and
/// widget_snapshot.dart). Texts arrive localized; a version this code does
/// not know is skipped.
struct AccountCatalog: Decodable {
  struct Account: Decodable {
    var id: String
    var name: String
    var host: String?
    var guest: Bool?
  }

  struct ListEntry: Decodable {
    var key: String
    var kind: String
    var id: Int?
    var days: Int?
    var section: String?
    var title: String
    var writable: Bool?
    var parent: String?
  }

  var v: Int
  var account: Account
  var canAddTasks: Bool?
  var quickAddKey: String?
  var lists: [ListEntry]

  func list(kind: String, id: Int? = nil, days: Int? = nil) -> ListEntry? {
    lists.first { $0.kind == kind && $0.id == id && $0.days == days }
  }
}

/// What the app writes to host.json; `linkKey` goes into the links built
/// here (see `WidgetLinks`).
struct Host: Decodable {
  var activeAccountId: String?
  var linkKey: String?

  static func read() -> Host? { AppGroupStore.read(Host.self, AppGroupStore.hostFile) }
}

enum Catalogs {
  /// The active account first, so a new widget shows what the app shows.
  static func all() -> [AccountCatalog] {
    let active = Host.read()?.activeAccountId
    return AppGroupStore.readAll(AccountCatalog.self, in: AppGroupStore.catalogsDirectory)
      .filter { $0.v == 1 }
      .sorted {
        ($0.account.id == active ? 0 : 1, $0.account.name.lowercased())
          < ($1.account.id == active ? 0 : 1, $1.account.name.lowercased())
      }
  }

  static func catalog(for accountId: String) -> AccountCatalog? {
    guard AppGroupStore.isFileSafe(accountId),
      let catalog = AppGroupStore.read(
        AccountCatalog.self, "\(AppGroupStore.catalogsDirectory)/\(accountId).json"),
      catalog.v == 1
    else { return nil }
    return catalog
  }
}

struct WidgetText: Decodable {
  var title: String
  var body: String?
}

struct ListSnapshot: Decodable {
  enum State: String {
    case ok, needsReauth, guestEnded, accountRemoved, gone
  }

  struct Row: Decodable {
    var id: Int
    var title: String
    var due: String?
    /// `due` with a date for a day word, for an entry from `validUntil` on.
    var dueAbsolute: String?
    var dueAt: Date?
    var tone: String?
    var priority: String?
    var priorityLevel: Int?
    var project: String?
    var color: String?
    /// `color` as the app drew it on the light and the dark background.
    var colorLight: String?
    var colorDark: String?
    var canDone: Bool?
    var label: String?
    var labelOverdue: String?
    var labelAbsolute: String?
    var labelAbsoluteOverdue: String?
    var doneLabel: String?
    var link: String?
    /// When the row joins a list whose tasks join by the clock; it is in
    /// the list from the start without it.
    var showsFrom: Date?
  }

  /// The app's texts for one count an entry may show.
  struct CountText: Decodable {
    var n: Int
    var label: String
    var more: String?
    /// What the list shows in place of hidden titles.
    var empty: WidgetText?
  }

  var v: Int
  var account: String?
  var state: String?
  var title: String
  var subtitle: String?
  var generatedAt: Date
  var validUntil: Date?
  var changesAt: [Date]?
  /// When each task that is not in the list yet joins it, rows or not.
  var joinsAt: [Date]?
  var rows: [Row]?
  var total: Int?
  var moreLabel: String?
  var countLabel: String?
  var empty: WidgetText?
  var message: WidgetText?
  var messageLink: String?
  var link: String?
  var newTaskLink: String?
  var newTaskLabel: String?
  var staleNotice: String?
  var counts: [CountText]?

  var listState: State { state.flatMap(State.init(rawValue:)) ?? .ok }

  /// Every instant after now at which a row may look or read otherwise: its
  /// due instant, also after `validUntil`, a task joining, and `validUntil`.
  func changeDates(rows: [Row], after now: Date) -> [Date] {
    let changes =
      (changesAt ?? []) + (joinsAt ?? []) + [validUntil].compactMap { $0 }
      + rows.compactMap(\.dueAt)
    return Set(changes.filter { $0 > now }).sorted()
  }

  func entryDates(rows: [Row], now: Date, limit: Int) -> [Date] {
    [now] + changeDates(rows: rows, after: now).prefix(limit - 1)
  }

  func countText(_ count: Int) -> CountText? {
    counts?.first { $0.n == count }
  }

  static func load(key: String) -> ListSnapshot? {
    guard AppGroupStore.isFileSafe(key),
      let snapshot = AppGroupStore.read(
        ListSnapshot.self, "\(AppGroupStore.snapshotsDirectory)/\(key).json"),
      snapshot.v == 1
    else { return nil }
    return snapshot
  }
}

extension ListSnapshot.Row {
  /// The label of the due text and tone an entry shows: dated from
  /// `validUntil` on (`stale`), and "Overdue" while the row shows as overdue.
  /// A label the app leaves out equals the one tried next or is never
  /// needed; a snapshot written before step 40t has `label` alone.
  func spokenLabel(stale: Bool, overdue: Bool) -> String? {
    switch (stale, overdue) {
    case (false, false): return label
    case (false, true): return labelOverdue ?? label
    case (true, false): return labelAbsolute ?? label
    case (true, true): return labelAbsoluteOverdue ?? labelAbsolute ?? labelOverdue ?? label
    }
  }
}
