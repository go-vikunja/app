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

private struct Host: Decodable {
  var activeAccountId: String?
}

enum Catalogs {
  /// The active account first, so a new widget shows what the app shows.
  static func all() -> [AccountCatalog] {
    let active = AppGroupStore.read(Host.self, AppGroupStore.hostFile)?.activeAccountId
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
    var dueAt: Date?
    var tone: String?
    var priority: String?
    var priorityLevel: Int?
    var project: String?
    var color: String?
    var canDone: Bool?
    var label: String?
    var doneLabel: String?
    var link: String?
  }

  var v: Int
  var account: String?
  var state: String?
  var title: String
  var subtitle: String?
  var generatedAt: Date
  var validUntil: Date?
  var changesAt: [Date]?
  var rows: [Row]?
  var total: Int?
  var countLabel: String?
  var empty: WidgetText?
  var message: WidgetText?
  var messageLink: String?
  var link: String?
  var newTaskLink: String?
  var newTaskLabel: String?

  var listState: State { state.flatMap(State.init(rawValue:)) ?? .ok }

  static func load(key: String) -> ListSnapshot? {
    guard AppGroupStore.isFileSafe(key),
      let snapshot = AppGroupStore.read(
        ListSnapshot.self, "\(AppGroupStore.snapshotsDirectory)/\(key).json"),
      snapshot.v == 1
    else { return nil }
    return snapshot
  }
}
