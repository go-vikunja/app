String durationToHumanReadable(Duration dur) {
  if(dur.inDays.abs() > 1)
    return dur.inDays.toString() + " days";
  if(dur.inDays.abs() == 1)
    return dur.inDays.toString() + " day";
  if(dur.inHours.abs() > 1)
    return dur.inHours.toString() + " hours";
  if(dur.inHours.abs() == 1)
    return dur.inHours.toString() + "1 hour";
  return "under 1 hour";
}