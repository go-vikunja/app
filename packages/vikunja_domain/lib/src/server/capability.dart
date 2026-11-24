/// Something the connected server offers: `/api/v2`, a route or behavior a
/// release added, a feature its admin can switch off in `/info`, or a pro
/// feature its license enables. Features follow these and the API versions
/// that answered, so a proxy that hides `/api/v2` or an admin who disabled
/// attachments is handled like an old server. A workaround for what an
/// older release does differently reads the server version where it
/// applies, with its own default for a version the app cannot read
/// (decision log: Servers). Values no feature checks stay: the support
/// details list every capability, and the contract tests read some.
enum Capability {
  apiV2,
  sessionRefresh,
  oauthPkce,
  websocket,
  bulkCreateTasks,
  pendingEmail,
  byIndexRedirect,

  /// v2 `PATCH /user/settings/general` as a deep merge-patch; older servers
  /// replace every setting on a write.
  userSettingsMergePatch,

  /// The server keeps deleted tasks and projects in a trash for 30 days,
  /// with routes to list, restore and delete them for good. Vikunja 2.8.0
  /// and newer, on `/api/v2` only.
  trash,

  /// The server sends a task's reminders, and its overdue e-mail, only to
  /// the task's subscribers. It subscribes creators and assignees on its
  /// own, so unfollowing a task silences it. Vikunja 2.8.0 and newer,
  /// whatever the API version: the server routes the reminders itself.
  remindersToSubscribers,

  /// Unfollowing a task or project that the user follows through a parent
  /// project opts just that one out. Older servers refuse it with a 403:
  /// only unfollowing the parent stops such a follow there. Vikunja 2.6.0
  /// and newer, on both API versions, and a v2 server whose version cannot
  /// be read (2.4 or newer), where a refusal only fails the unfollow.
  subscriptionOptOuts,

  /// Ten wrong passwords lock a local account until its password is reset,
  /// and end all its sessions. Vikunja 2.8.0 and newer, on both API versions.
  accountLockout,
  localAuth,
  ldapAuth,
  openIdConnect,
  registration,
  linkSharing,
  taskAttachments,
  taskComments,
  totp,
  caldav,
  webhooks,
  publicTeams,
  userDeletion,
  emailReminders,
  backgroundUpload,
  backgroundUnsplash,
  timeTracking,
  adminPanel,
  auditLogs,
  userInvites,
}
