import AppIntents
import UserNotifications
import WidgetKit

/// Runs in the extension: it only records the tap and takes away the task's
/// reminders. The app sends the Done at its next run, so the extension never
/// needs a token or the network (decision log: Notifications and widgets).
struct MarkDoneIntent: AppIntent {
  static let title: LocalizedStringResource = "Mark task as done"
  static let isDiscoverable = false
  // The default runs it on a locked device too (StandBy, the lock screen).
  static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @Parameter(title: "Account") var accountId: String
  @Parameter(title: "Task") var taskId: Int
  @Parameter(title: "Due date") var dueAt: Date?
  // False in a button drawn before the rows said what they showed.
  @Parameter(title: "Row known", default: false) var showsRow: Bool

  init() {}

  init(accountId: String, taskId: Int, dueAt: Date?) {
    self.accountId = accountId
    self.taskId = taskId
    self.dueAt = dueAt
    self.showsRow = true
  }

  func perform() async throws -> some IntentResult {
    let recorded = try DoneTaps.record(
      accountId: accountId, taskId: taskId, shown: showsRow ? ShownRow(dueAt: dueAt) : nil)
    if recorded {
      await TaskNotifications.remove(accountId: accountId, taskId: taskId)
    }
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKinds.tasks)
    return .result()
  }
}

/// The task's reminders and due-date notification, scheduled and shown, which
/// would otherwise go on until the app imports the tap (ExternalDone cancels
/// them then). Matched by the payload flutter_local_notifications keeps under
/// "payload": its account, and a key of notification_plan.dart.
enum TaskNotifications {
  static func remove(accountId: String, taskId: Int) async {
    let center = UNUserNotificationCenter.current()
    let pending = await center.pendingNotificationRequests()
    center.removePendingNotificationRequests(
      withIdentifiers: pending.filter {
        belongs($0.content.userInfo, accountId: accountId, taskId: taskId)
      }.map(\.identifier))
    let shown = await center.deliveredNotifications()
    center.removeDeliveredNotifications(
      withIdentifiers: shown.filter {
        belongs($0.request.content.userInfo, accountId: accountId, taskId: taskId)
      }.map(\.request.identifier))
  }

  private static func belongs(_ userInfo: [AnyHashable: Any], accountId: String, taskId: Int)
    -> Bool
  {
    guard let payload = (userInfo["payload"] as? String)?.data(using: .utf8),
      let fields = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any],
      fields["account"] as? String == accountId,
      let key = fields["key"] as? String
    else { return false }
    return key == "\(taskId):due" || key.hasPrefix("\(taskId):reminder:")
  }
}
