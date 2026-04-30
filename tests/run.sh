#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

"$ROOT_DIR/bin/ocpersona" link lshq nvim --no-cache || true
"$ROOT_DIR/bin/ocpersona" link lshq nvim --no-cache || true
"$ROOT_DIR/bin/ocpersona" link lshq nvim --no-cache --force

if "$ROOT_DIR/bin/ocpersona" link lshq nvim --bad-flag >/dev/null 2>&1; then
  printf '%s\n' "Expected invalid-flag test to fail" >&2
  exit 1
fi

if "$ROOT_DIR/bin/ocpersona" link lshq bad/name >/dev/null 2>&1; then
  printf '%s\n' "Expected invalid-app-name test to fail" >&2
  exit 1
fi

if "$ROOT_DIR/bin/ocpersona" link lshq opencode --force >/dev/null 2>&1; then
  printf '%s\n' "Expected reserved-app-name test to fail" >&2
  exit 1
fi

printf '%s\n' "All tests passed"
