import 'package:vikunja_app/domain/entities/server.dart';

class ServerDto {
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


  ServerDto(
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
      this.version);

  ServerDto.fromJson(Map<String, dynamic> json)
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

  Server toDomain() => Server(
      caldavEnabled,
      emailRemindersEnabled,
      frontendUrl,
      linkSharingEnabled,
      maxFileSize,
      motd,
      registrationEnabled,
      taskAttachmentsEnabled,
      taskCommentsEnabled,
      totpEnabled,
      userDeletion,
      version
  );

  static ServerDto fromDomain(Server b) => ServerDto(
      b.caldavEnabled,
      b.emailRemindersEnabled,
      b.frontendUrl,
      b.linkSharingEnabled,
      b.maxFileSize,
      b.motd,
      b.registrationEnabled,
      b.taskAttachmentsEnabled,
      b.taskCommentsEnabled,
      b.totpEnabled,
      b. userDeletion,
      b.version);
}
