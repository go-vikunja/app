import AppIntents
import WidgetKit

/// Runs in the extension: it only records the tap. The app sends it at its
/// next run, so the extension never needs a token or the network (D24).
struct MarkDoneIntent: AppIntent {
  static let title: LocalizedStringResource = "Mark task done"
  static let isDiscoverable = false
  // The default runs it on a locked device too (StandBy, the lock screen).
  static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

  @Parameter(title: "Account") var accountId: String
  @Parameter(title: "Task") var taskId: Int

  init() {}

  init(accountId: String, taskId: Int) {
    self.accountId = accountId
    self.taskId = taskId
  }

  func perform() async throws -> some IntentResult {
    try DoneTaps.record(accountId: accountId, taskId: taskId)
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKinds.tasks)
    return .result()
  }
}
