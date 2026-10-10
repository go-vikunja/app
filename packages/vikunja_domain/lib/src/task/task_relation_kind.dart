enum TaskRelationKind {
  subtask('subtask'),
  parentTask('parenttask'),
  related('related'),
  duplicateOf('duplicateof'),
  duplicates('duplicates'),
  blocking('blocking'),
  blocked('blocked'),
  precedes('precedes'),
  follows('follows'),
  copiedFrom('copiedfrom'),
  copiedTo('copiedto');

  new(this.wireName);

  final String wireName;

  static TaskRelationKind? fromWire(String? name) =>
      values.where((k) => k.wireName == name).firstOrNull;
}
