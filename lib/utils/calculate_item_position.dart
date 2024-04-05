import 'dart:math';

double calculateItemPosition({double? positionBefore, double? positionAfter}) {
  // only
  if (positionBefore == null && positionAfter == null) {
    return 0;
  }

  // first
  if (positionBefore == null && positionAfter != null) {
    return positionAfter / 2;
  }

  // last
  if (positionBefore != null && positionAfter == null) {
    return positionBefore + pow(2.0, 16.0);
  }

  // in the middle (positionBefore != null && positionAfter != null)
  return (positionBefore! + positionAfter!) / 2;
}
