#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

tmp_dir=$(mktemp -d)
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

export HOME=$tmp_dir
export OCP_CONFIG_DIR=$tmp_dir/ocpersona-config
mkdir -p "$OCP_CONFIG_DIR"
cat > "$OCP_CONFIG_DIR/config.sh" <<'EOF'
OCP_DEFAULT_LINK_APPS="gh vim nvim"
EOF

export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export XDG_CACHE_HOME=$HOME/.cache

mkdir -p "$XDG_CONFIG_HOME/opencode" "$XDG_DATA_HOME/opencode" "$XDG_STATE_HOME/opencode"
mkdir -p "$XDG_CONFIG_HOME/gh" "$XDG_CONFIG_HOME/vim" "$XDG_CONFIG_HOME/nvim"
mkdir -p "$XDG_DATA_HOME/nvim" "$XDG_STATE_HOME/nvim"

"$ROOT_DIR/bin/ocpersona" clone-default lshq

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

for linked_app in gh vim nvim; do
  linked_path=$OCP_CONFIG_DIR/profiles/lshq/config/$linked_app
  if [ ! -L "$linked_path" ]; then
    printf '%s\n' "Expected clone-default to link $linked_app config path" >&2
    exit 1
  fi
done

printf '%s\n' "All tests passed"
