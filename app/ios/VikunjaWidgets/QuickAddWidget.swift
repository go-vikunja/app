import AppIntents
import SwiftUI
import WidgetKit

struct QuickAddWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: WidgetKinds.quickAdd, intent: QuickAddWidgetIntent.self, provider: QuickAddProvider()
    ) { entry in
      QuickAddView(entry: entry)
    }
    .configurationDisplayName("New task")
    .description("Opens a new task in Vikunja.")
    .supportedFamilies([.systemSmall, .accessoryCircular])
  }
}

extension QuickAddWidgetIntent {
  var catalog: AccountCatalog? {
    guard let account else { return Catalogs.all().first }
    return Catalogs.catalog(for: account.id)
  }
}

struct QuickAddEntry: TimelineEntry {
  var date: Date
  var title: String
  var detail: String?
  var canAdd: Bool
  var link: URL?
}

struct QuickAddProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> QuickAddEntry {
    QuickAddEntry(date: .now, title: String(localized: "New task"), canAdd: true)
  }

  func snapshot(for configuration: QuickAddWidgetIntent, in context: Context) async -> QuickAddEntry
  {
    entry(for: configuration)
  }

  func timeline(for configuration: QuickAddWidgetIntent, in context: Context) async -> Timeline<
    QuickAddEntry
  > {
    if let key = configuration.catalog?.quickAddKey {
      SnapshotRequests.mark(key)
    }
    return Timeline(entries: [entry(for: configuration)], policy: .never)
  }

  /// Without a catalog (the app has not run, or the account was removed)
  /// the button still opens a new task in the app's active account.
  private func entry(for configuration: QuickAddWidgetIntent) -> QuickAddEntry {
    let catalog = configuration.catalog
    let snapshot = catalog?.quickAddKey.flatMap(ListSnapshot.load(key:))
    let canAdd = catalog?.canAddTasks ?? true
    let project = configuration.project?.item
    let projectOfAccount =
      project?.accountId != nil && project?.accountId == catalog?.account.id ? project : nil
    let title = snapshot?.newTaskLabel ?? String(localized: "New task")
    guard canAdd else {
      return QuickAddEntry(
        date: .now, title: title, detail: snapshot?.empty?.title, canAdd: false,
        link: WidgetLinks.open(accountId: catalog?.account.id))
    }
    return QuickAddEntry(
      date: .now, title: title,
      detail: projectOfAccount?.title ?? (Catalogs.all().count > 1 ? catalog?.account.name : nil),
      canAdd: true,
      link: WidgetLinks.newTask(accountId: catalog?.account.id, projectId: projectOfAccount?.itemId)
    )
  }
}

struct QuickAddView: View {
  var entry: QuickAddEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    content
      .widgetURL(entry.link)
      .widgetBackground(family)
  }

  @ViewBuilder private var content: some View {
    if family == .accessoryCircular {
      ZStack {
        AccessoryWidgetBackground()
        Image(systemName: "plus").font(.title2.weight(.semibold))
      }
      .accessibilityLabel(Text(entry.title))
    } else {
      VStack(alignment: .leading, spacing: 4) {
        Image(systemName: "plus.circle.fill")
          .font(.largeTitle)
          .foregroundStyle(entry.canAdd ? Color.accentColor : Color.secondary)
          .widgetAccentable()
        Spacer(minLength: 0)
        Text(entry.title).font(.headline).lineLimit(2)
        if let detail = entry.detail {
          Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
