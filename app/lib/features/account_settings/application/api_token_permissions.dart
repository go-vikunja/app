import 'package:vikunja_domain/vikunja_domain.dart';

/// The server stores the title as `varchar(255)`.
const apiTokenTitleMaxLength = 255;

/// The web's quick presets; each one replaces the whole selection.
enum ApiTokenPreset { readOnly, tasks, projects, fullAccess }

/// Per group the permissions a preset picks, null for all of them; a group
/// or permission this server does not offer is left out.
const _presetGroups = <ApiTokenPreset, Map<String, List<String>?>>{
  ApiTokenPreset.tasks: {
    'tasks': null,
    'tasks_attachments': null,
    'tasks_assignees': null,
    'tasks_labels': null,
    'tasks_comments': null,
    'tasks_relations': null,
    'labels': ['read_one', 'read_all', 'create'],
    'projects': ['read_one', 'read_all', 'views_buckets_tasks'],
    'projects_views': ['read_one', 'read_all'],
    'projects_views_tasks': ['read_one', 'read_all'],
  },
  ApiTokenPreset.projects: {
    'projects': null,
    'projects_views': null,
    'projects_teams': null,
    'projects_users': null,
    'projects_shares': null,
    'projects_webhooks': null,
    'projects_buckets': null,
    'projects_views_tasks': null,
    'tasks': ['read_one', 'read_all'],
    'teams': ['read_one', 'read_all'],
  },
};

const _readPermissions = ['read_one', 'read_all'];

/// What [preset] selects of the permissions [offered].
Map<String, Set<String>> presetSelection(
  ApiTokenPreset preset,
  ApiPermissionGroups offered,
) {
  Set<String> pick(String group, List<String>? names) => {
    for (final name in offered.groups[group] ?? const <String>[])
      if (names == null || names.contains(name)) name,
  };
  final picked = switch (preset) {
    ApiTokenPreset.readOnly => {
      for (final group in offered.groups.keys)
        group: pick(group, _readPermissions),
    },
    ApiTokenPreset.fullAccess => {
      for (final group in offered.groups.keys) group: pick(group, null),
    },
    ApiTokenPreset.tasks || ApiTokenPreset.projects => {
      for (final MapEntry(key: group, value: names)
          in _presetGroups[preset]!.entries)
        group: pick(group, names),
    },
  };
  return {
    for (final MapEntry(:key, :value) in picked.entries)
      if (value.isNotEmpty) key: value,
  };
}

/// [selected] as the server takes it: groups and permissions in the order
/// the server offers them, empty groups left out.
Map<String, List<String>> selectedPermissions(
  ApiPermissionGroups offered,
  Map<String, Set<String>> selected,
) => {
  for (final MapEntry(key: group, value: names) in offered.groups.entries)
    if (selected[group] case final picked? when picked.isNotEmpty)
      group: [
        for (final name in names)
          if (picked.contains(name)) name,
      ],
};

/// The server's name for a group or permission made readable the way the
/// web shows it, untranslated: `read_all` becomes `Read all`.
String humanizePermission(String name) {
  final spaced = name.replaceAll('_', ' ').trim();
  if (spaced.isEmpty) return name;
  return spaced[0].toUpperCase() + spaced.substring(1);
}
