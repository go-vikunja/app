String durationToHumanReadable(Duration dur) {
  var durString = '';
  if (dur.inDays.abs() > 1)
    durString = dur.inDays.abs().toString() + " days";
  else if (dur.inDays.abs() == 1)
    durString = dur.inDays.abs().toString() + " day";
  else if (dur.inHours.abs() > 1)
    durString = dur.inHours.abs().toString() + " hours";
  else if (dur.inHours.abs() == 1)
    durString = dur.inHours.abs().toString() + " hour";
  else if (dur.inMinutes.abs() > 1)
    durString = dur.inMinutes.abs().toString() + " minutes";
  else if (dur.inMinutes.abs() == 1)
    durString = dur.inMinutes.abs().toString() + " minute";
  else
    durString = "less than a minute";

  if (dur.isNegative) return durString + " ago";
  return "in " + durString;
}
