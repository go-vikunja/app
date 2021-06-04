datetimeToUnixTimestamp(DateTime dt) {
  return dt?.millisecondsSinceEpoch == null
      ? null
      : (dt.millisecondsSinceEpoch / 1000).round();
}

dateTimeFromUnixTimestamp(int timestamp) {
  return timestamp == null
      ? 0
      : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
}