String durationToHumanReadable(Duration dur) {
  if(dur.inDays.abs() > 1)
    return dur.inDays.toString() + " days";
  if(dur.inDays.abs() == 1)
    return dur.inDays.toString() + " day";

  if(dur.inHours.abs() > 1)
    return dur.inHours.toString() + " hours";
  if(dur.inHours.abs() == 1)
    return dur.inHours.toString() + " hour";

  if(dur.inMinutes.abs() > 1)
    return dur.inMinutes.toString() + " minutes";
  if(dur.inMinutes.abs() == 1)
    return dur.inMinutes.toString() + " minute";
  return "under 1 minute";
}