String durationToHumanReadable(Duration dur) {
  var durString = '';
  if (dur.inDays.abs() > 1) {
    durString = "${dur.inDays.abs()} days";
  } else if (dur.inDays.abs() == 1) {
    durString = "${dur.inDays.abs()} day";
  } else if (dur.inHours.abs() > 1) {
    durString = "${dur.inHours.abs()} hours";
  } else if (dur.inHours.abs() == 1) {
    durString = "${dur.inHours.abs()} hour";
  } else if (dur.inMinutes.abs() > 1) {
    durString = "${dur.inMinutes.abs()} minutes";
  } else if (dur.inMinutes.abs() == 1) {
    durString = "${dur.inMinutes.abs()} minute";
  } else {
    durString = "less than a minute";
  }

  if (dur.isNegative) return "$durString ago";
  return "in $durString";
}
