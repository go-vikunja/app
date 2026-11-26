import UserNotifications
import XCTest

final class NotificationResponsesTests: XCTestCase {
  private var responses: NotificationResponses!
  private var uiEngineAlive = false
  private var answered: [String] = []

  override func setUp() {
    responses = NotificationResponses()
    uiEngineAlive = false
    answered = []
  }

  private func receive(_ action: String, foregroundActions: [String] = []) {
    responses.receive(
      action: action, foregroundActions: foregroundActions, uiEngineAlive: uiEngineAlive,
      toUIEngine: { [unowned self] in answered.append("ui:\(action)") },
      toLaunchPlugin: { [unowned self] in answered.append("launch:\(action)") })
  }

  func testDoneOrSnoozeBeforeAnySceneConnectedRunsThroughThePluginMadeAtLaunch() {
    receive("done")
    receive("snooze_1h")

    XCTAssertEqual(answered, ["launch:done", "launch:snooze_1h"])
  }

  func testWithTheUIEngineAliveTheUIEnginesPluginAloneAnswers() {
    uiEngineAlive = true

    receive("done")
    receive(UNNotificationDefaultActionIdentifier)
    receive(UNNotificationDismissActionIdentifier)

    XCTAssertEqual(
      answered,
      [
        "ui:done", "ui:\(UNNotificationDefaultActionIdentifier)",
        "ui:\(UNNotificationDismissActionIdentifier)",
      ])
  }

  func testATapThatOpensTheAppWaitsForTheUIEngineAndIsAnsweredOnce() {
    receive(UNNotificationDefaultActionIdentifier)
    receive("open", foregroundActions: ["open"])
    XCTAssertEqual(answered, [])

    responses.uiEngineRegistered()
    responses.uiEngineRegistered()

    XCTAssertEqual(answered, ["ui:\(UNNotificationDefaultActionIdentifier)", "ui:open"])
  }

  func testADismissBeforeAnySceneConnectedGoesToThePluginMadeAtLaunch() {
    receive(UNNotificationDismissActionIdentifier)

    XCTAssertEqual(answered, ["launch:\(UNNotificationDismissActionIdentifier)"])
  }

  func testOnlyATapOrAForegroundActionOpensTheApp() {
    XCTAssertTrue(
      NotificationResponses.opensApp(UNNotificationDefaultActionIdentifier, foregroundActions: []))
    XCTAssertTrue(NotificationResponses.opensApp("open", foregroundActions: ["open"]))
    XCTAssertFalse(NotificationResponses.opensApp("done", foregroundActions: ["open"]))
    XCTAssertFalse(
      NotificationResponses.opensApp(UNNotificationDismissActionIdentifier, foregroundActions: []))
  }

  func testOnlyANotificationWithThePluginsKeysIsTheirs() {
    let plugins: [AnyHashable: Any] = [
      "NotificationId": 3, "presentAlert": true, "presentSound": true, "presentBadge": false,
      "payload": "{}",
    ]
    XCTAssertTrue(NotificationResponses.isPluginNotification(plugins))
    for key in plugins.keys {
      var without = plugins
      without[key] = nil
      XCTAssertFalse(NotificationResponses.isPluginNotification(without), "\(key)")
    }
    XCTAssertFalse(NotificationResponses.isPluginNotification(["title": "Sync ran"]))
  }

  func testInABackgroundEngineOnlyTheNotificationPluginIsNoApplicationDelegate() {
    let filter = ApplicationDelegateFilter()
    XCTAssertTrue(filter.keepsApplicationDelegate("WorkmanagerPlugin"))
    XCTAssertFalse(filter.sawNotificationPlugin)

    XCTAssertFalse(filter.keepsApplicationDelegate("FlutterLocalNotificationsPlugin"))

    XCTAssertTrue(filter.sawNotificationPlugin)
    XCTAssertTrue(filter.keepsApplicationDelegate("FLTSharedPreferencesPlugin"))
  }

  func testTheCompletionHandlerRunsOnce() {
    var calls = 0
    let completion = NotificationResponses.once { calls += 1 }

    completion()
    completion()

    XCTAssertEqual(calls, 1)
  }

  func testAfterTheUIEngineIsGoneABackgroundActionRunsThroughThePluginMadeAtLaunchAgain() {
    uiEngineAlive = true
    receive("done")
    uiEngineAlive = false

    receive("done")

    XCTAssertEqual(answered, ["ui:done", "launch:done"])
  }
}
