const _base = 36;
const _tMin = 1;
const _tMax = 26;
const _skew = 38;
const _damp = 700;
const _initialBias = 72;
const _initialN = 0x80;

/// RFC 3492 encoding of one label, without the `xn--` prefix.
String punycodeEncode(String label) {
  final codePoints = label.runes.toList();
  final output = StringBuffer();
  for (final codePoint in codePoints) {
    if (codePoint < _initialN) output.writeCharCode(codePoint);
  }
  final basicCount = output.length;
  if (basicCount > 0) output.write('-');

  var handled = basicCount;
  var n = _initialN;
  var delta = 0;
  var bias = _initialBias;
  while (handled < codePoints.length) {
    final next = codePoints
        .where((codePoint) => codePoint >= n)
        .reduce((a, b) => a < b ? a : b);
    delta += (next - n) * (handled + 1);
    n = next;
    for (final codePoint in codePoints) {
      if (codePoint < n) delta++;
      if (codePoint != n) continue;
      var q = delta;
      for (var k = _base; ; k += _base) {
        final t = k <= bias ? _tMin : (k >= bias + _tMax ? _tMax : k - bias);
        if (q < t) break;
        output.writeCharCode(_digit(t + (q - t) % (_base - t)));
        q = (q - t) ~/ (_base - t);
      }
      output.writeCharCode(_digit(q));
      bias = _adapt(delta, handled + 1, isFirst: handled == basicCount);
      delta = 0;
      handled++;
    }
    delta++;
    n++;
  }
  return output.toString();
}

int _adapt(int delta, int pointCount, {required bool isFirst}) {
  var scaled = isFirst ? delta ~/ _damp : delta ~/ 2;
  scaled += scaled ~/ pointCount;
  var k = 0;
  while (scaled > ((_base - _tMin) * _tMax) ~/ 2) {
    scaled ~/= _base - _tMin;
    k += _base;
  }
  return k + ((_base - _tMin + 1) * scaled) ~/ (scaled + _skew);
}

int _digit(int value) => value < 26 ? 0x61 + value : 0x16 + value;
