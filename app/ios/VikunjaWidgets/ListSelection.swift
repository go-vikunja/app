import Foundation
import WidgetKit

/// The list one widget shows: its snapshot key (taken from the catalog, so
/// the app alone defines the key format) and the app link that opens it.
struct ListSelection: Equatable {
  var accountId: String
  var key: String
  var kind: ListKind
  var projectId: Int?
  var openLink: URL?
}

enum ListResolution {
  case selection(ListSelection)
  case noAccount
  case accountRemoved
  case missingItem(accountId: String, kind: ListKind)
}

extension TasksWidgetIntent {
  var resolution: ListResolution {
    guard let accountId = account?.id ?? Catalogs.all().first?.account.id else { return .noAccount }
    guard let catalog = Catalogs.catalog(for: accountId) else { return .accountRemoved }

    func link(id: Int? = nil, days: Int? = nil) -> URL? {
      WidgetLinks.url(
        "list",
        [
          "account": accountId, "kind": kind.rawValue, "id": id.map(String.init),
          "days": days.map(String.init),
        ])
    }
    func selection(_ entity: ListItem?) -> ListResolution {
      guard let entity, entity.accountId == nil || entity.accountId == accountId else {
        return .missingItem(accountId: accountId, kind: kind)
      }
      return .selection(
        ListSelection(
          accountId: accountId, key: entity.id, kind: kind,
          projectId: kind == .project ? entity.itemId : nil, openLink: link(id: entity.itemId)))
    }

    switch kind {
    case .project: return selection(project?.item)
    case .label: return selection(label?.item)
    case .savedFilter: return selection(savedFilter?.item)
    case .upcoming:
      guard let entry = catalog.list(kind: kind.rawValue, days: days.rawValue) else {
        return .noAccount
      }
      return .selection(
        ListSelection(
          accountId: accountId, key: entry.key, kind: kind, openLink: link(days: days.rawValue)))
    case .today, .overdue, .favorites:
      guard let entry = catalog.list(kind: kind.rawValue) else { return .noAccount }
      return .selection(
        ListSelection(accountId: accountId, key: entry.key, kind: kind, openLink: link()))
    }
  }
}

/// Empty files under `requests/` tell the app which snapshots placed widgets
/// read, since it cannot read their configurations itself.
enum SnapshotRequests {
  private static let staleAfter: TimeInterval = 24 * 3600

  static func mark(_ key: String) {
    let path = "\(AppGroupStore.requestsDirectory)/\(key)"
    guard AppGroupStore.isFileSafe(key), !AppGroupStore.exists(path) else { return }
    AppGroupStore.createEmptyFile(path)
  }

  static func syncWithPlacedWidgets() async {
    let result = await withCheckedContinuation { continuation in
      WidgetCenter.shared.getCurrentConfigurations { continuation.resume(returning: $0) }
    }
    guard case .success(let widgets) = result else { return }
    let keys = Set(
      widgets.compactMap { widget -> String? in
        switch widget.kind {
        case WidgetKinds.tasks:
          guard
            case .selection(let selection) = widget.widgetConfigurationIntent(
              of: TasksWidgetIntent.self)?.resolution
          else { return nil }
          return selection.key
        case WidgetKinds.quickAdd:
          return widget.widgetConfigurationIntent(of: QuickAddWidgetIntent.self)?.catalog?
            .quickAddKey
        default:
          return nil
        }
      })
    keys.forEach(mark)
    prune(keeping: keys)
  }

  /// A marker is kept for a day after its widget is gone: a widget placed a
  /// moment ago may not be in the system's list yet.
  private static func prune(keeping keys: Set<String>) {
    let now = Date()
    for name in AppGroupStore.names(in: AppGroupStore.requestsDirectory) where !keys.contains(name)
    {
      let path = "\(AppGroupStore.requestsDirectory)/\(name)"
      if let modified = AppGroupStore.modificationDate(path),
        now.timeIntervalSince(modified) > staleAfter
      {
        AppGroupStore.remove(path)
      }
    }
  }
}

/// The app's widget links (`…://widget/<action>?account=…`). Each carries
/// the app's widget-link key from host.json as `k` when the app wrote one;
/// without it the app opens the link but never switches accounts silently.
enum WidgetLinks {
  static let scheme = "vikunja-io.vikunja.app"

  static func url(_ path: String, _ query: [String: String?] = [:]) -> URL? {
    var query = query
    if let key = Host.read()?.linkKey, !key.isEmpty { query["k"] = key }
    var components = URLComponents()
    components.scheme = scheme
    components.host = "widget"
    components.path = "/\(path)"
    let items = query.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) }
    }
    .sorted { $0.name < $1.name }
    components.queryItems = items.isEmpty ? nil : items
    return components.url
  }

  static func open(accountId: String? = nil) -> URL? { url("open", ["account": accountId]) }

  static func newTask(accountId: String?, projectId: Int?) -> URL? {
    url("new-task", ["account": accountId, "project": projectId.map(String.init)])
  }

  static func task(_ taskId: Int, accountId: String) -> URL? {
    url("task/\(taskId)", ["account": accountId])
  }

  /// Only links into this app are followed.
  static func parse(_ link: String?) -> URL? {
    guard let link, let url = URL(string: link), url.scheme == scheme else { return nil }
    return url
  }
}
