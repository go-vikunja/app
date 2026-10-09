final BigInt _maxUint64 = (BigInt.one << 64) - BigInt.one;
final BigInt _maxInt64 = BigInt.parse('9223372036854775807');
const _mebibyteShift = 20;
const _serverFallbackMebibytes = 20;

final _numberAndUnit = RegExp(r'^(\d*)(.*)$', dotAll: true);

// Units of github.com/c2h5oh/datasize, which the server uses to read
// `files.maxsize`: binary multiples, case-insensitive, no fractions.
const _unitShifts = {
  '': 0,
  'b': 0,
  'byte': 0,
  'k': 10,
  'kb': 10,
  'kilo': 10,
  'kilobyte': 10,
  'kilobytes': 10,
  'm': 20,
  'mb': 20,
  'mega': 20,
  'megabyte': 20,
  'megabytes': 20,
  'g': 30,
  'gb': 30,
  'giga': 30,
  'gigabyte': 30,
  'gigabytes': 30,
  't': 40,
  'tb': 40,
  'tera': 40,
  'terabyte': 40,
  'terabytes': 40,
  'p': 50,
  'pb': 50,
  'peta': 50,
  'petabyte': 50,
  'petabytes': 50,
  'e': 60,
  'eb': 60,
};

// datasize rejects these spellings as bits before lowercasing the unit.
const _bitUnits = {'Kb', 'Mb', 'Gb', 'Tb', 'Pb', 'Eb'};

/// The upload limit in bytes that a server enforces for its `max_file_size`,
/// or null when the value is not one the server could have started with.
///
/// The server truncates the parsed size to whole MiB and falls back to 20 MiB
/// when that is 0 (`SetMaxFileSizeMBytesFromString` and
/// `GetMaxFileSizeInMBytes` in `pkg/config/config.go`).
int? maxFileSizeInBytes(String configured) {
  final match = _numberAndUnit.firstMatch(configured)!;
  final digits = match.group(1)!;
  if (digits.isEmpty && configured.isNotEmpty) return null;

  final unit = match.group(2)!.trim();
  if (_bitUnits.contains(unit)) return null;
  final shift = _unitShifts[unit.toLowerCase()];
  if (shift == null) return null;

  final bytes = BigInt.parse(digits.isEmpty ? '0' : digits) << shift;
  if (bytes > _maxUint64) return null;

  var mebibytes = bytes >> _mebibyteShift;
  if (mebibytes == BigInt.zero) {
    mebibytes = BigInt.from(_serverFallbackMebibytes);
  }
  final limit = mebibytes << _mebibyteShift;
  return (limit > _maxInt64 ? _maxInt64 : limit).toInt();
}
