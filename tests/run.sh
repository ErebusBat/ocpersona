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
unset OCP_PROFILE
unset OCP_PROFILE_FILE
unset OCP_ACTIVE
unset OCP_OC_BIN
unset OCP_PATH
unset OCP_SHIM_DIR
unset OCP_SHELL_INTEGRATION
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
mkdir -p "$OCP_CONFIG_DIR/profiles/lebowski"
cat > "$OCP_CONFIG_DIR/profiles/lebowski/ocpersona.sh" <<'EOF'
profile_dir=${OCP_PROFILE_FILE%/*}
XDG_CONFIG_HOME="${profile_dir}/config"
XDG_DATA_HOME="${profile_dir}/data"
XDG_STATE_HOME="${profile_dir}/state"
EOF

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

"$ROOT_DIR/bin/ocpersona" link --all nvim --no-cache --force
for profile_name in lshq lebowski; do
  linked_path=$OCP_CONFIG_DIR/profiles/$profile_name/config/nvim
  if [ ! -L "$linked_path" ]; then
    printf '%s\n' "Expected --all app link for profile $profile_name" >&2
    exit 1
  fi
done

"$ROOT_DIR/bin/ocpersona" link --all --no-cache
for profile_name in lshq lebowski; do
  for linked_app in gh vim nvim; do
    linked_path=$OCP_CONFIG_DIR/profiles/$profile_name/config/$linked_app
    if [ ! -L "$linked_path" ]; then
      printf '%s\n' "Expected --all default link $linked_app for profile $profile_name" >&2
      exit 1
    fi
  done
done

repo_dir=$tmp_dir/workrepo
mkdir -p "$repo_dir"
(
  cd "$repo_dir"
  /usr/bin/env git init >/dev/null 2>&1
)

cat > "$repo_dir/.ocpersona" <<'EOF'
export OCP_PROFILE=repoauto
EOF

doctor_output=$(
  cd "$repo_dir"
  "$ROOT_DIR/bin/ocpersona" doctor
)

printf '%s\n' "$doctor_output" | /usr/bin/env grep -q '^ocp_profile=repoauto$' || {
  printf '%s\n' "Expected doctor to auto-detect OCP_PROFILE from repo .ocpersona" >&2
  exit 1
}

cat > "$repo_dir/.ocpersona" <<'EOF'
export OCP_OC_BIN=/tmp/fake-opencode
EOF

if (
  cd "$repo_dir"
  "$ROOT_DIR/bin/ocpersona" doctor >/dev/null 2>&1
); then
  printf '%s\n' "Expected doctor to fail when repo .ocpersona omits OCP_PROFILE" >&2
  exit 1
fi

cat > "$repo_dir/.ocpersona" <<'EOF'
export OCP_PROFILE=repoauto
EOF

explicit_output=$(
  cd "$repo_dir"
  OCP_PROFILE=manual "$ROOT_DIR/bin/ocpersona" doctor
)

printf '%s\n' "$explicit_output" | /usr/bin/env grep -q '^ocp_profile=manual$' || {
  printf '%s\n' "Expected explicit OCP_PROFILE to win over repo auto-detect" >&2
  exit 1
}

cat > "$repo_dir/.ocpersona" <<'EOF'
export OCP_PROFILE=repoauto
export OCP_OC_BIN=/tmp/repo-opencode
EOF

override_output=$(
  cd "$repo_dir"
  OCP_OC_BIN=/tmp/env-opencode "$ROOT_DIR/bin/ocpersona" doctor
)

printf '%s\n' "$override_output" | /usr/bin/env grep -q '^ocp_oc_bin=/tmp/repo-opencode$' || {
  printf '%s\n' "Expected repo .ocpersona OCP_OC_BIN to override process env when autodetect runs" >&2
  exit 1
}

nonrepo_dir=$tmp_dir/nonrepo
mkdir -p "$nonrepo_dir"

nonrepo_output=$(
  cd "$nonrepo_dir"
  "$ROOT_DIR/bin/ocpersona" doctor
)

printf '%s\n' "$nonrepo_output" | /usr/bin/env grep -q '^ocp_profile=$' || {
  printf '%s\n' "Expected no auto-detection outside git repos" >&2
  exit 1
}

printf '%s\n' "All tests passed"
