datetimeToUnixTimestamp(DateTime dt) {
  return (dt.millisecondsSinceEpoch / 1000).round();
}

dateTimeFromUnixTimestamp(int timestamp) {
  return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
}
