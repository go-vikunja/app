enum WidgetView {
  inbox,
  today,
  upcoming,
  project;

  String get displayName {
    switch (this) {
      case WidgetView.inbox:
        return 'Inbox';
      case WidgetView.today:
        return 'Today';
      case WidgetView.upcoming:
        return 'Upcoming';
      case WidgetView.project:
        return 'Project';
    }
  }

  static WidgetView fromString(String value) {
    switch (value) {
      case 'inbox':
        return WidgetView.inbox;
      case 'upcoming':
        return WidgetView.upcoming;
      case 'project':
        return WidgetView.project;
      default:
        return WidgetView.today;
    }
  }
}
