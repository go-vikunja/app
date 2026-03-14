class Server {
  bool? caldavEnabled;
  bool? emailRemindersEnabled;
  String? frontendUrl;
  bool? linkSharingEnabled;
  String? maxFileSize;
  String? motd;
  bool? registrationEnabled;
  bool? taskAttachmentsEnabled;
  bool? taskCommentsEnabled;
  bool? totpEnabled;
  bool? userDeletion;
  String? version;
  String? apiMinCompatible;

  Server(
    this.caldavEnabled,
    this.emailRemindersEnabled,
    this.frontendUrl,
    this.linkSharingEnabled,
    this.maxFileSize,
    this.motd,
    this.registrationEnabled,
    this.taskAttachmentsEnabled,
    this.taskCommentsEnabled,
    this.totpEnabled,
    this.userDeletion,
    this.version,
    this.apiMinCompatible,
  );
}
