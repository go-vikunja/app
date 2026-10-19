/// The server's `MinPositionSpacing`: a position below it makes the server
/// recalculate every position of the view.
const minPositionSpacing = 0.01;

const _gap = 65536.0;

/// The position for an item dropped between the neighbours [before] and
/// [after] (null where it has none), as the web computes it. Without any
/// neighbour it is 2^16 instead of the web's 0, which would make the
/// server recalculate the whole view.
double calculateItemPosition(double? before, double? after) =>
    switch ((before, after)) {
      (final before?, final after?) when before == after =>
        after + minPositionSpacing,
      (null, null) => _gap,
      (null, final after?) => after / 2,
      (final before?, null) => before + _gap,
      (final before?, final after?) => before + (after - before) / 2,
    };
