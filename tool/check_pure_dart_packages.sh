#!/usr/bin/env bash
# packages/*/lib must compile on the plain Dart VM: no Flutter and no dart:ui,
# directly or through a dependency. Background isolates and a future CLI share
# this code. The tests cannot show it, because they run under `flutter test`
# (D9).
#
# Needs jq and a resolved workspace (`flutter pub get` at the root).
# Must run on macOS's bash 3.2.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 2
fi

failed=0

flutter_import="^[[:space:]]*(import|export)[[:space:]]+['\"](package:(flutter[a-z0-9_]*|material_ui|cupertino_ui)/|dart:ui['\"])"
set +e
matches="$(grep -rnE --include='*.dart' "$flutter_import" packages/*/lib)"
status=$?
set -e
case "$status" in
  0)
    echo "error: packages/*/lib must not import Flutter (package:flutter*, material_ui, cupertino_ui, dart:ui):" >&2
    echo "$matches" >&2
    failed=1
    ;;
  1) ;;
  *)
    echo "error: grep failed with status ${status}" >&2
    exit "$status"
    ;;
esac

pure_packages=()
for pubspec in packages/*/pubspec.yaml; do
  pure_packages+=("$(sed -n -E 's/^name:[[:space:]]*([a-z0-9_]+).*/\1/p' "$pubspec")")
done

# Root packages list their dev dependencies under `dependencies` too, so only
# `directDependencies` counts for them. The graph has cycles, hence the seen set.
flutter_dependents="$(dart pub deps --json | jq -r '
  (.packages
    | map({key: .name,
           value: (if .kind == "root" then .directDependencies
                   else (.dependencies // []) end)})
    | from_entries) as $deps
  | .packages[]
  | select(.kind == "root" and (.name | IN($ARGS.positional[])))
  | .name as $root
  | {seen: [], todo: .directDependencies}
  | until(.todo == [];
      .todo[0] as $next
      | if (.seen | index($next)) then .todo |= .[1:]
        else .seen += [$next] | .todo = .todo[1:] + ($deps[$next] // [])
        end)
  | select(.seen | index("flutter"))
  | "\($root) depends on flutter"
' --args "${pure_packages[@]}")"
if [[ -n "$flutter_dependents" ]]; then
  echo "error: pure packages must not depend on Flutter, not even transitively:" >&2
  echo "$flutter_dependents" >&2
  failed=1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
entry="${tmp}/entry.dart"
count=0
for dir in packages/*/; do
  name="$(sed -n -E 's/^name:[[:space:]]*([a-z0-9_]+).*/\1/p' "${dir}pubspec.yaml")"
  while IFS= read -r file; do
    if grep -qE '^part[[:space:]]+of[[:space:]]' "$file"; then
      continue
    fi
    echo "import 'package:${name}/${file#"${dir}lib/"}' as i${count};" >>"$entry"
    count=$((count + 1))
  done < <(find "${dir}lib" -type f -name '*.dart' | sort)
done
echo 'void main() {}' >>"$entry"

if ! dart compile kernel --packages=.dart_tool/package_config.json \
  -o "${tmp}/out.dill" "$entry" >"${tmp}/compile.log" 2>&1; then
  echo "error: packages/*/lib does not compile on the plain Dart VM (first lines):" >&2
  head -n 20 "${tmp}/compile.log" >&2
  failed=1
fi

if ((failed)); then
  exit 1
fi
echo "OK: packages ${pure_packages[*]} are pure Dart (${count} libraries compiled for the Dart VM)."
