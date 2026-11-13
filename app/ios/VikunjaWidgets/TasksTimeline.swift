import SwiftUI
import WidgetKit

enum DueTone: String {
  case overdue, today, later, none
}

struct TaskRowContent: Identifiable {
  var id: Int
  var title: String
  var dueLabel: String?
  var dueTone: DueTone
  var priorityLabel: String?
  var priorityLevel: Int
  var projectTitle: String?
  var projectColor: Color?
  var canDone: Bool
  var semanticsLabel: String
  var doneLabel: String
  var link: URL?
}

struct ListContent {
  var accountId: String
  var title: String
  var subtitle: String?
  /// Why the rows may be out of date (an ended session), shown above them.
  var notice: String?
  var rows: [TaskRowContent]
  var total: Int
  var countLabel: String?
  var empty: WidgetText?
  var openLink: URL?
  var newTaskLink: URL?
  var newTaskLabel: String?
}

enum TasksEntryContent {
  case sample(redacted: Bool)
  case message(title: String?, text: String, link: URL?)
  case list(ListContent)
}

struct TasksEntry: TimelineEntry {
  var date: Date
  var content: TasksEntryContent
  var relevance: TimelineEntryRelevance?
}

struct TasksProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> TasksEntry {
    TasksEntry(date: .now, content: .sample(redacted: true))
  }

  func snapshot(for configuration: TasksWidgetIntent, in context: Context) async -> TasksEntry {
    let entry = TasksTimeline(resolution: configuration.resolution, now: .now).entries[0]
    if context.isPreview, case .message = entry.content {
      return TasksEntry(date: .now, content: .sample(redacted: false))
    }
    return entry
  }

  func timeline(for configuration: TasksWidgetIntent, in context: Context) async -> Timeline<
    TasksEntry
  > {
    let resolution = configuration.resolution
    if case .selection(let selection) = resolution {
      SnapshotRequests.mark(selection.key)
    }
    await SnapshotRequests.syncWithPlacedWidgets()
    let timeline = TasksTimeline(resolution: resolution, now: .now)
    return Timeline(entries: timeline.entries, policy: .after(timeline.reloadDate))
  }
}

/// Entries at now, at every due instant the app listed and at midnight: a row
/// due today turns overdue on time while the app is not running.
struct TasksTimeline {
  private static let maxEntries = 48

  var entries: [TasksEntry]
  var reloadDate: Date

  init(resolution: ListResolution, now: Date) {
    switch resolution {
    case .noAccount:
      self.init(
        message: String(localized: "Open Vikunja to load your tasks"), link: WidgetLinks.open(),
        now: now)
    case .accountRemoved:
      self.init(
        title: String(localized: "Account removed"),
        message: String(localized: "Edit the widget to choose another account."),
        link: WidgetLinks.open(), now: now)
    case .missingItem(let accountId, let kind):
      self.init(
        message: Self.choosePrompt(kind), link: WidgetLinks.open(accountId: accountId), now: now)
    case .selection(let selection):
      if let snapshot = ListSnapshot.load(key: selection.key) {
        self.init(snapshot: snapshot, selection: selection, now: now)
      } else {
        self.init(
          message: String(localized: "Open Vikunja to load this list"), link: selection.openLink,
          now: now)
      }
    }
  }

  private init(title: String? = nil, message: String, link: URL?, now: Date) {
    entries = [TasksEntry(date: now, content: .message(title: title, text: message, link: link))]
    reloadDate = now.addingTimeInterval(3600)
  }

  private init(snapshot: ListSnapshot, selection: ListSelection, now: Date) {
    let openLink = WidgetLinks.parse(snapshot.link) ?? selection.openLink
    let messageLink = WidgetLinks.parse(snapshot.messageLink)
    let notice: String?
    switch snapshot.listState {
    case .accountRemoved, .gone:
      entries = [
        TasksEntry(
          date: now,
          content: .message(
            title: snapshot.message?.title ?? snapshot.title,
            text: snapshot.message?.body ?? String(localized: "Not available"),
            link: messageLink ?? WidgetLinks.open(accountId: selection.accountId)))
      ]
      reloadDate = now.addingTimeInterval(3600)
      return
    case .needsReauth:
      notice = snapshot.message?.title ?? String(localized: "Sign in again")
    case .guestEnded:
      notice = snapshot.message?.title
    case .ok:
      notice = nil
    }

    let hidden = DoneTaps.hiddenTaskIds(
      accountId: selection.accountId, listGeneratedAt: snapshot.generatedAt)
    let allRows = snapshot.rows ?? []
    let rows = allRows.filter { !hidden.contains($0.id) }
    let total = max(rows.count, (snapshot.total ?? allRows.count) - (allRows.count - rows.count))
    let boundaries = (snapshot.changesAt ?? []) + [snapshot.validUntil].compactMap { $0 }
    let dates = [now] + Set(boundaries.filter { $0 > now }).sorted().prefix(Self.maxEntries - 1)

    entries = dates.map { date in
      let content = ListContent(
        accountId: selection.accountId, title: snapshot.title, subtitle: snapshot.subtitle,
        notice: notice,
        rows: rows.map { Self.rowContent($0, at: date, accountId: selection.accountId) },
        total: total, countLabel: rows.count == allRows.count ? snapshot.countLabel : nil,
        empty: snapshot.empty,
        openLink: notice == nil ? openLink : messageLink ?? openLink,
        newTaskLink: WidgetLinks.parse(snapshot.newTaskLink), newTaskLabel: snapshot.newTaskLabel)
      let urgent = content.rows.filter { $0.dueTone == .overdue || $0.dueTone == .today }.count
      return TasksEntry(
        date: date, content: .list(content),
        relevance: TimelineEntryRelevance(score: Float(urgent)))
    }
    if let validUntil = snapshot.validUntil, validUntil > now {
      reloadDate = validUntil
    } else {
      reloadDate = now.addingTimeInterval(3600)
    }
  }

  private static func rowContent(
    _ row: ListSnapshot.Row, at date: Date, accountId: String
  ) -> TaskRowContent {
    var tone = row.tone.flatMap(DueTone.init(rawValue:)) ?? .none
    if tone == .today, let dueAt = row.dueAt, dueAt <= date {
      tone = .overdue
    }
    return TaskRowContent(
      id: row.id, title: row.title, dueLabel: row.due, dueTone: tone,
      priorityLabel: row.priority, priorityLevel: row.priorityLevel ?? 0,
      projectTitle: row.project, projectColor: row.color.flatMap(Color.init(hex:)),
      canDone: row.canDone ?? false, semanticsLabel: row.label ?? row.title,
      doneLabel: row.doneLabel ?? row.title,
      link: WidgetLinks.parse(row.link) ?? WidgetLinks.task(row.id, accountId: accountId))
  }

  private static func choosePrompt(_ kind: ListKind) -> String {
    switch kind {
    case .project: return String(localized: "Edit the widget to choose a project.")
    case .label: return String(localized: "Edit the widget to choose a label.")
    default: return String(localized: "Edit the widget to choose a saved filter.")
    }
  }
}

extension Color {
  /// `rrggbb`, as the app writes project colours.
  init?(hex: String) {
    guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
    self.init(
      red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255)
  }
}
