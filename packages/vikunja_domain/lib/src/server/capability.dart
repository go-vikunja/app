/// Something the connected server can do. Features are gated on these, never
/// on raw version strings, so a server whose proxy hides `/api/v2` or whose
/// admin disabled attachments is handled the same way as an old server.
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
