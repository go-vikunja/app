import AppIntents
import WidgetKit

enum ListKind: String, AppEnum {
  case today, upcoming, overdue, favorites, project, label, savedFilter

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "List"
  static let caseDisplayRepresentations: [ListKind: DisplayRepresentation] = [
    .today: "Today",
    .upcoming: "Upcoming",
    .overdue: "Overdue",
    .favorites: "Favorite tasks",
    .project: "Project",
    .label: "Label",
    .savedFilter: "Saved filter",
  ]
}

enum UpcomingDays: Int, AppEnum {
  case three = 3
  case seven = 7
  case fourteen = 14

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Days"
  static let caseDisplayRepresentations: [UpcomingDays: DisplayRepresentation] = [
    .three: "Next 3 days",
    .seven: "Next 7 days",
    .fourteen: "Next 14 days",
  ]
}

struct AccountEntity: AppEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Account"
  static let defaultQuery = AccountQuery()

  var id: String
  var name: String
  var host: String?

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)", subtitle: host.map { "\($0)" })
  }

  init(_ account: AccountCatalog.Account) {
    id = account.id
    name = account.name
    host = account.host
  }

  /// Keeps a widget bound to a signed-out account, so it says so instead of
  /// silently showing another account.
  init(removed id: String) {
    self.id = id
    name = String(localized: "Account removed")
  }
}

struct AccountQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [AccountEntity] {
    let accounts = Catalogs.all().map(\.account)
    return identifiers.map { id in
      accounts.first { $0.id == id }.map(AccountEntity.init) ?? AccountEntity(removed: id)
    }
  }

  func suggestedEntities() async throws -> [AccountEntity] {
    Catalogs.all().map { AccountEntity($0.account) }
  }

  func defaultResult() async -> AccountEntity? {
    Catalogs.all().first.map { AccountEntity($0.account) }
  }
}

/// A project, label or saved filter from the account's catalog. Its id is
/// the snapshot key, which still names the app's "gone" snapshot after the
/// list itself has left the catalog.
struct ListItem: Identifiable {
  var id: String
  var accountId: String?
  var itemId: Int?
  var title: String
  var parent: String?
  var writable: Bool

  static func all(kind: ListKind, of accountId: String) -> [ListItem] {
    (Catalogs.catalog(for: accountId)?.lists ?? []).filter { $0.kind == kind.rawValue }.map {
      ListItem(
        id: $0.key, accountId: accountId, itemId: $0.id, title: $0.title, parent: $0.parent,
        writable: $0.writable ?? false)
    }
  }

  static func resolve(_ identifiers: [String], kind: ListKind) -> [ListItem] {
    let known = Catalogs.all().flatMap { all(kind: kind, of: $0.account.id) }
    return identifiers.filter(AppGroupStore.isFileSafe).map { key in
      known.first { $0.id == key }
        ?? ListItem(
          id: key, accountId: nil, itemId: nil, title: String(localized: "Not available"),
          writable: false)
    }
  }

  static func matching(_ items: [ListItem], _ text: String) -> [ListItem] {
    items.filter { $0.title.localizedCaseInsensitiveContains(text) }
  }

  /// The picker cannot indent, so a nested project names its parents.
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(title)", subtitle: parent.map { "in \($0)" })
  }
}

private func accountId(or chosen: String?) -> String? {
  chosen ?? Catalogs.all().first?.account.id
}

struct ProjectEntity: AppEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Project"
  static let defaultQuery = ProjectQuery()

  var item: ListItem
  var id: String { item.id }
  var displayRepresentation: DisplayRepresentation { item.displayRepresentation }
}

struct ProjectQuery: EntityStringQuery {
  @IntentParameterDependency<TasksWidgetIntent>(\.$account) var tasksWidget

  private var choices: [ListItem] {
    accountId(or: tasksWidget?.account.id).map { ListItem.all(kind: .project, of: $0) } ?? []
  }

  func entities(for identifiers: [String]) async throws -> [ProjectEntity] {
    ListItem.resolve(identifiers, kind: .project).map(ProjectEntity.init)
  }

  func entities(matching string: String) async throws -> [ProjectEntity] {
    ListItem.matching(choices, string).map(ProjectEntity.init)
  }

  func suggestedEntities() async throws -> [ProjectEntity] { choices.map(ProjectEntity.init) }
}

/// A new task can only go into a project the user may add tasks to.
struct WritableProjectOptions: DynamicOptionsProvider {
  @IntentParameterDependency<QuickAddWidgetIntent>(\.$account) var quickAdd

  func results() async throws -> [ProjectEntity] {
    (accountId(or: quickAdd?.account.id).map { ListItem.all(kind: .project, of: $0) } ?? [])
      .filter(\.writable).map(ProjectEntity.init)
  }
}

struct LabelEntity: AppEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Label"
  static let defaultQuery = LabelQuery()

  var item: ListItem
  var id: String { item.id }
  var displayRepresentation: DisplayRepresentation { item.displayRepresentation }
}

struct LabelQuery: EntityStringQuery {
  @IntentParameterDependency<TasksWidgetIntent>(\.$account) var tasksWidget

  private var choices: [ListItem] {
    accountId(or: tasksWidget?.account.id).map { ListItem.all(kind: .label, of: $0) } ?? []
  }

  func entities(for identifiers: [String]) async throws -> [LabelEntity] {
    ListItem.resolve(identifiers, kind: .label).map(LabelEntity.init)
  }

  func entities(matching string: String) async throws -> [LabelEntity] {
    ListItem.matching(choices, string).map(LabelEntity.init)
  }

  func suggestedEntities() async throws -> [LabelEntity] { choices.map(LabelEntity.init) }
}

struct SavedFilterEntity: AppEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Saved filter"
  static let defaultQuery = SavedFilterQuery()

  var item: ListItem
  var id: String { item.id }
  var displayRepresentation: DisplayRepresentation { item.displayRepresentation }
}

struct SavedFilterQuery: EntityStringQuery {
  @IntentParameterDependency<TasksWidgetIntent>(\.$account) var tasksWidget

  private var choices: [ListItem] {
    accountId(or: tasksWidget?.account.id).map { ListItem.all(kind: .savedFilter, of: $0) } ?? []
  }

  func entities(for identifiers: [String]) async throws -> [SavedFilterEntity] {
    ListItem.resolve(identifiers, kind: .savedFilter).map(SavedFilterEntity.init)
  }

  func entities(matching string: String) async throws -> [SavedFilterEntity] {
    ListItem.matching(choices, string).map(SavedFilterEntity.init)
  }

  func suggestedEntities() async throws -> [SavedFilterEntity] {
    choices.map(SavedFilterEntity.init)
  }
}

struct TasksWidgetIntent: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Choose a list"
  static let description = IntentDescription("Shows the open tasks of a list.")

  @Parameter(title: "Account") var account: AccountEntity?
  @Parameter(title: "List", default: .today) var kind: ListKind
  @Parameter(title: "Days", default: .seven) var days: UpcomingDays
  @Parameter(title: "Project") var project: ProjectEntity?
  @Parameter(title: "Label") var label: LabelEntity?
  @Parameter(title: "Saved filter") var savedFilter: SavedFilterEntity?

  static var parameterSummary: some ParameterSummary {
    Switch(\.$kind) {
      Case(.upcoming) {
        Summary {
          \.$account
          \.$kind
          \.$days
        }
      }
      Case(.project) {
        Summary {
          \.$account
          \.$kind
          \.$project
        }
      }
      Case(.label) {
        Summary {
          \.$account
          \.$kind
          \.$label
        }
      }
      Case(.savedFilter) {
        Summary {
          \.$account
          \.$kind
          \.$savedFilter
        }
      }
      DefaultCase {
        Summary {
          \.$account
          \.$kind
        }
      }
    }
  }
}

struct QuickAddWidgetIntent: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "New task"
  static let description = IntentDescription("Opens a new task in Vikunja.")

  @Parameter(title: "Account") var account: AccountEntity?
  @Parameter(title: "Project", optionsProvider: WritableProjectOptions()) var project:
    ProjectEntity?
}
