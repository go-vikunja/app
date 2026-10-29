import AppIntents
import SwiftUI
import WidgetKit

struct TasksWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: WidgetKinds.tasks, intent: TasksWidgetIntent.self, provider: TasksProvider()
    ) { entry in
      TasksWidgetView(entry: entry)
    }
    .configurationDisplayName("Tasks")
    .description("Open tasks of a list. Tick one to mark it as done.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
      .accessoryRectangular, .accessoryInline, .accessoryCircular,
    ])
  }
}

struct TasksWidgetView: View {
  var entry: TasksEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    content.widgetBackground(family)
  }

  @ViewBuilder private var content: some View {
    switch entry.content {
    case .sample(let redacted):
      list(.sample).redacted(reason: redacted ? .placeholder : [])
    case .message(let title, let text, let link):
      MessageView(title: title, text: text, family: family).widgetURL(link)
    case .list(let content):
      list(content).widgetURL(content.openLink)
    }
  }

  @ViewBuilder private func list(_ content: ListContent) -> some View {
    switch family {
    case .accessoryInline: InlineView(content: content)
    case .accessoryCircular: CircularView(content: content)
    case .accessoryRectangular: RectangularView(content: content)
    case .systemSmall: SmallView(content: content)
    default: ListView(content: content, family: family)
    }
  }
}

extension View {
  /// Required since iOS 17; tinted and clear modes and StandBy replace it.
  func widgetBackground(_ family: WidgetFamily) -> some View {
    containerBackground(for: .widget) {
      if family.isAccessory { Color.clear } else { Color("WidgetBackground") }
    }
  }
}

extension WidgetFamily {
  var isAccessory: Bool {
    self == .accessoryInline || self == .accessoryCircular || self == .accessoryRectangular
  }
}

private struct MessageView: View {
  var title: String?
  var text: String
  var family: WidgetFamily

  var body: some View {
    switch family {
    case .accessoryInline:
      Text(text)
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        Image(systemName: "checklist").font(.title3)
      }
      .accessibilityLabel(Text(text))
    default:
      VStack(alignment: .leading, spacing: 4) {
        if let title {
          Text(title).font(.headline).lineLimit(2).widgetAccentable()
        }
        Text(text).font(.caption).foregroundStyle(.secondary)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct ListView: View {
  var content: ListContent
  var family: WidgetFamily
  @Environment(\.dynamicTypeSize) private var typeSize

  private var compact: Bool { family == .systemMedium }

  /// Fewer rows at large text sizes instead of smaller text.
  private var rowLimit: Int {
    var limit = compact ? 3 : 7
    if typeSize >= .accessibility1 {
      limit = compact ? 1 : 2
    } else if typeSize >= .xLarge {
      limit -= compact ? 1 : 2
    }
    return max(1, limit - (content.notice == nil ? 0 : 1))
  }

  private var spacing: CGFloat { compact ? 4 : 6 }

  var body: some View {
    VStack(alignment: .leading, spacing: spacing) {
      ListHeader(content: content)
      if let notice = content.notice {
        Label(notice, systemImage: "exclamationmark.triangle")
          .font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      if content.rows.isEmpty {
        Spacer(minLength: 0)
        EmptyListText(empty: content.empty)
      } else {
        // The header stays whole: rows that do not fit the family's height
        // at this text size are counted in "+N more" instead.
        ViewThatFits(in: .vertical) {
          ForEach(Array((1...min(rowLimit, content.rows.count)).reversed()), id: \.self) { count in
            rows(count)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func rows(_ count: Int) -> some View {
    let shown = Array(content.rows.prefix(count))
    let notShown = content.total - shown.count
    let reservesCheckbox = shown.contains(where: \.canDone)
    return VStack(alignment: .leading, spacing: spacing) {
      ForEach(shown) { row in
        TaskRowView(
          row: row, accountId: content.accountId, compact: compact,
          reservesCheckbox: reservesCheckbox)
      }
      if notShown > 0, !compact, let openLink = content.openLink {
        Link(destination: openLink) {
          Text("+\(notShown) more").font(.caption).foregroundStyle(.secondary)
        }
      }
    }
  }
}

private struct ListHeader: View {
  var content: ListContent

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      VStack(alignment: .leading, spacing: 0) {
        Text(content.title).font(.headline).lineLimit(1).widgetAccentable()
        if let subtitle = content.subtitle {
          Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      Spacer(minLength: 4)
      CountText(content: content).font(.headline).foregroundStyle(.secondary)
      if let newTaskLink = content.newTaskLink {
        Link(destination: newTaskLink) {
          Image(systemName: "plus.circle.fill").font(.title3).widgetAccentable()
        }
        .accessibilityLabel(Text(content.newTaskLabel ?? String(localized: "New task")))
      }
    }
  }
}

private struct CountText: View {
  var content: ListContent

  var body: some View {
    if let countLabel = content.countLabel {
      Text(content.total, format: .number).accessibilityLabel(Text(countLabel))
    } else {
      Text(content.total, format: .number)
    }
  }
}

private struct EmptyListText: View {
  var empty: WidgetText?

  var body: some View {
    VStack(spacing: 2) {
      Text(empty?.title ?? String(localized: "All done")).font(.subheadline)
      if let body = empty?.body {
        Text(body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
      }
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
  }
}

private struct TaskRowView: View {
  var row: TaskRowContent
  var accountId: String
  var compact: Bool
  var reservesCheckbox: Bool

  var body: some View {
    HStack(alignment: compact ? .center : .firstTextBaseline, spacing: 8) {
      if row.canDone {
        DoneButton(row: row, accountId: accountId)
      } else if reservesCheckbox {
        Image(systemName: "square").font(.body).hidden()
      }
      if let link = row.link {
        Link(destination: link) { label }
      } else {
        label
      }
    }
    .invalidatableContent()
  }

  private var label: some View {
    Group {
      if compact {
        HStack(spacing: 6) {
          Text(row.title).font(.subheadline).lineLimit(1)
          Spacer(minLength: 4)
          DueText(row: row)
        }
      } else {
        VStack(alignment: .leading, spacing: 1) {
          Text(row.title).font(.subheadline).lineLimit(1)
          MetaLine(row: row)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(row.semanticsLabel))
    // After the label, so that the title it names is redacted too.
    .privacySensitive()
  }
}

private struct DoneButton: View {
  var row: TaskRowContent
  var accountId: String

  var body: some View {
    Button(intent: MarkDoneIntent(accountId: accountId, taskId: row.id)) {
      Image(systemName: "square").font(.body).foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .widgetAccentable()
    .accessibilityLabel(Text(row.doneLabel))
    .privacySensitive()
  }
}

private struct DueText: View {
  var row: TaskRowContent

  var body: some View {
    if let dueLabel = row.dueLabel {
      // Tinted and clear modes draw every colour alike, so overdue has its own icon.
      HStack(spacing: 2) {
        Image(systemName: row.dueTone == .overdue ? "exclamationmark.circle" : "calendar")
        Text(dueLabel)
      }
      .font(.caption2)
      .foregroundStyle(row.dueTone.color)
      .lineLimit(1)
    }
  }
}

private struct MetaLine: View {
  var row: TaskRowContent

  var body: some View {
    HStack(spacing: 8) {
      DueText(row: row)
      if let priorityLabel = row.priorityLabel {
        HStack(spacing: 2) {
          Image(systemName: "flag.fill")
          Text(priorityLabel)
        }
        .foregroundStyle(priorityColor)
      }
      if let projectTitle = row.projectTitle {
        HStack(spacing: 3) {
          Circle().fill(row.projectColor ?? .secondary).frame(width: 6, height: 6)
          Text(projectTitle)
        }
        .foregroundStyle(.secondary)
      }
    }
    .font(.caption2)
    .lineLimit(1)
  }

  private var priorityColor: Color {
    switch row.priorityLevel {
    case 4...: return Color("Overdue")
    case 3: return Color("Highlight")
    default: return .secondary
    }
  }
}

private struct SmallView: View {
  var content: ListContent

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(content.title).font(.headline).lineLimit(1).widgetAccentable()
      CountText(content: content)
        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
        .widgetAccentable()
      Spacer(minLength: 0)
      if let next = content.rows.first {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          if next.canDone {
            DoneButton(row: next, accountId: content.accountId)
          }
          VStack(alignment: .leading, spacing: 1) {
            Text(next.title).font(.caption).lineLimit(2)
            DueText(row: next)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(Text(next.semanticsLabel))
          .privacySensitive()
        }
        .invalidatableContent()
      } else {
        Text(content.empty?.title ?? String(localized: "All done"))
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct RectangularView: View {
  var content: ListContent

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(content.title).font(.headline).lineLimit(1).widgetAccentable()
        Spacer(minLength: 4)
        CountText(content: content).font(.headline)
      }
      if let next = content.rows.first {
        Text(next.title).lineLimit(1).privacySensitive()
        if let dueLabel = next.dueLabel {
          Text(dueLabel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
      } else {
        Text(content.empty?.title ?? String(localized: "All done")).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct InlineView: View {
  var content: ListContent

  var body: some View {
    Label {
      Text(verbatim: "\(content.title) \(content.total)")
    } icon: {
      Image(systemName: "checklist")
    }
  }
}

private struct CircularView: View {
  var content: ListContent

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      VStack(spacing: 0) {
        Image(systemName: "checklist").font(.caption2)
        Text(content.total, format: .number).font(.title3.weight(.semibold))
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      Text(verbatim: "\(content.title), \(content.countLabel ?? String(content.total))"))
  }
}

extension DueTone {
  var color: Color {
    switch self {
    case .overdue: return Color("Overdue")
    case .today: return Color("Today")
    case .later, .none: return .secondary
    }
  }
}

extension ListContent {
  /// For the placeholder and the gallery before the app has written data.
  static var sample: ListContent {
    let titles = [
      String(localized: "Buy groceries"), String(localized: "Call the plumber"),
      String(localized: "Plan the trip"),
    ]
    return ListContent(
      accountId: "", title: String(localized: "Today"),
      rows: titles.enumerated().map { index, title in
        TaskRowContent(
          id: index, title: title, dueLabel: String(localized: "Today"), dueTone: .today,
          priorityLevel: 0, canDone: true, semanticsLabel: title, doneLabel: title)
      },
      total: titles.count)
  }
}
