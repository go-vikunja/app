#!/usr/bin/env bash
# Fails when hand-written Dart sources are not formatted. Generated code is
# skipped because its generators decide its layout.
#
# Usage: tool/check_format.sh          check only (CI)
#        tool/check_format.sh --fix    format in place
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

roots=()
for dir in app/lib app/test app/integration_test packages plugins; do
  if [[ -d "$dir" ]]; then
    roots+=("$dir")
  fi
done

files=()
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(find "${roots[@]}" -type f -name '*.dart' \
  ! -name '*.g.dart' \
  ! -name '*.freezed.dart' \
  ! -path 'app/lib/l10n/generated/*' \
  ! -path '*/.dart_tool/*' \
  ! -path '*/build/*' \
  -print0)

if ((${#files[@]} == 0)); then
  echo "No Dart files to check."
  exit 0
fi

if [[ "${1:-}" == "--fix" ]]; then
  exec dart format "${files[@]}"
fi
exec dart format --output=none --set-exit-if-changed "${files[@]}"
