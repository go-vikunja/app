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

  Server.fromJson(Map<String, dynamic> json)
      : caldavEnabled = json['caldav_enabled'],
        emailRemindersEnabled = json['email_reminders_enabled'],
        frontendUrl = json['frontend_url'],
        linkSharingEnabled = json['link_sharing_enabled'],
        maxFileSize = json['max_file_size'],
        motd = json['motd'],
        registrationEnabled = json['registration_enabled'],
        taskAttachmentsEnabled = json['task_attachments_enabled'],
        taskCommentsEnabled = json['task_comments_enabled'],
        totpEnabled = json['totp_enabled'],
        userDeletion = json['user_deletion'],
        version = json['version'];
}
