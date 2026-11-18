#!/usr/bin/env python3
"""Splits the editor's package-lock.json for the advisory scan (tool/ci/osv.sh):
the packages the shipped page and its build reach, whose advisories block a
release, and those that only the editor's tests reach (TEST_ONLY and what
they alone pull in), whose advisories are shown for information.

  python3 -I tool/ci/editor_test_packages.py LOCKFILE OUT_DIR

Writes OUT_DIR/build/package-lock.json and OUT_DIR/tests/package-lock.json.
"""
import json
import os
import sys

# devDependencies of app/editor/package.json that only `npm test` uses; esbuild
# builds the page that ships, so it is not one of them.
TEST_ONLY = ('jsdom',)
DEPENDENCY_FIELDS = ('dependencies', 'optionalDependencies', 'peerDependencies')


class LockError(Exception):
    pass


def resolve(packages, name, origin):
    """The lockfile path npm's resolution gives `name` required from `origin`."""
    base = origin
    while True:
        candidate = f'{base}/node_modules/{name}' if base else f'node_modules/{name}'
        if candidate in packages:
            return candidate
        if not base:
            return None
        cut = base.rfind('/node_modules/')
        base = base[:cut] if cut >= 0 else ''


def closure(packages, roots):
    seen = set()
    pending = [path for name in roots if (path := resolve(packages, name, ''))]
    while pending:
        path = pending.pop()
        if path in seen:
            continue
        seen.add(path)
        entry = packages[path]
        for field in DEPENDENCY_FIELDS:
            for name in entry.get(field) or {}:
                found = resolve(packages, name, path)
                if found:
                    pending.append(found)
                elif field == 'dependencies':
                    raise LockError(f'{path} needs {name}, which the lockfile does not have')
    return seen


def split(lock):
    packages = lock.get('packages')
    if lock.get('lockfileVersion') not in (2, 3) or not isinstance(packages, dict) or '' not in packages:
        raise LockError('not an npm lockfile of version 2 or 3')
    root = packages['']
    direct = {name for field in ('dependencies', 'devDependencies', 'optionalDependencies')
              for name in root.get(field) or {}}
    for name in TEST_ONLY:
        if name not in (root.get('devDependencies') or {}):
            raise LockError(f'{name} is no devDependency: update TEST_ONLY in tool/ci/editor_test_packages.py')
    build = closure(packages, sorted(direct - set(TEST_ONLY)))
    tests = closure(packages, TEST_ONLY) - build
    unreached = set(packages) - {''} - build - tests
    if unreached:
        raise LockError(f'no dependency reaches {", ".join(sorted(unreached))}')

    def lockfile(paths):
        return {**lock, 'packages': {'': root, **{path: packages[path] for path in sorted(paths)}}}

    return lockfile(build), lockfile(tests)


def main(arguments):
    if len(arguments) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(arguments[0], encoding='utf-8') as f:
            build, tests = split(json.load(f))
    except (OSError, ValueError, LockError) as e:
        print(f'error: {arguments[0]}: {e}', file=sys.stderr)
        return 1
    for name, lock in (('build', build), ('tests', tests)):
        os.makedirs(os.path.join(arguments[1], name), exist_ok=True)
        with open(os.path.join(arguments[1], name, 'package-lock.json'), 'w', encoding='utf-8') as f:
            json.dump(lock, f, indent=2)
    print(f'{arguments[0]}: {len(build["packages"]) - 1} packages for the page and its build, '
          f'{len(tests["packages"]) - 1} only for the tests ({", ".join(TEST_ONLY)})')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
