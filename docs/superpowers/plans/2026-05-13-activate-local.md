# activate --local Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `--local` and `--unset` flags to `activate` so that `ocp-on` can create, update, or remove the `OCP_PROFILE` line in the repo `.ocpersona` marker file.

**Architecture:** Extend `cmd_activate` in `bin/ocpersona` to parse two new mutually-exclusive flags. `--local` writes/updates the `.ocpersona` file at the git repo root. `--unset` removes the `OCP_PROFILE` line. The zsh plugin's `ocp-on` function routes to the appropriate flag. All logic lives in the existing shell script; no new files.

**Tech Stack:** POSIX sh, shellcheck, existing test harness (`tests/run.sh`)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `bin/ocpersona` | Modify | Add `--local`/`--unset` flag parsing to `cmd_activate`, add `update_marker_file` and `remove_marker_profile_line` helpers |
| `contrib/ocpersona.plugin.zsh` | Modify | Route `ocp-on --unset` to `activate --unset`, otherwise pass `--local` |
| `tests/run.sh` | Modify | Add 8 test cases covering all flag combinations and edge cases |
| `README.md` | Modify | Document `--local` and `--unset` on `activate` and update `ocp-on` description |

---

### Task 1: Add marker file helper functions to `bin/ocpersona`

**Files:**
- Modify: `bin/ocpersona` (insert after `emit_ocp_env_from_marker` at ~line 304)

- [ ] **Step 1: Add `update_marker_file` function**

Insert after the `apply_ocp_env_lines` function (after line 318):

```sh
update_marker_file() {
  marker_file=$1
  profile_name=$2
  ensure_profile_name "$profile_name"
  profile_line="export OCP_PROFILE=$profile_name"

  if [ ! -f "$marker_file" ]; then
    printf '%s\n' "$profile_line" > "$marker_file"
    return 0
  fi

  if grep -Fq "export OCP_PROFILE=" "$marker_file"; then
    tmp_file=$marker_file.ocpersona.tmp
    sed "s|^export OCP_PROFILE=.*$|$profile_line|" "$marker_file" > "$tmp_file"
    mv "$tmp_file" "$marker_file"
    return 0
  fi

  printf '%s\n' "$profile_line" >> "$marker_file"
}
```

- [ ] **Step 2: Add `remove_marker_profile_line` function**

Insert immediately after `update_marker_file`:

```sh
remove_marker_profile_line() {
  marker_file=$1

  [ -f "$marker_file" ] || return 0

  if ! grep -Fq "export OCP_PROFILE=" "$marker_file"; then
    return 0
  fi

  tmp_file=$marker_file.ocpersona.tmp
  grep -v "^export OCP_PROFILE=" "$marker_file" > "$tmp_file"
  mv "$tmp_file" "$marker_file"

  if [ ! -s "$marker_file" ]; then
    rm -f "$marker_file"
  fi
}
```

- [ ] **Step 3: Run shellcheck to verify**

Run: `shellcheck bin/ocpersona`
Expected: No new errors related to the two new functions.

- [ ] **Step 4: Commit**

```bash
git add bin/ocpersona
git commit -m "Add update_marker_file and remove_marker_profile_line helpers"
```

---

### Task 2: Extend `cmd_activate` with `--local` and `--unset` flags

**Files:**
- Modify: `bin/ocpersona` (`cmd_activate` at ~line 418, `usage` at ~line 28)

- [ ] **Step 1: Update `usage()` to document new flags**

Replace the `activate` line in `usage()` (line 35):

Old:
```
  activate <profile>               Print shell code to activate a profile
```

New:
```
  activate [--local] <profile>     Print shell code to activate a profile
                                    --local also writes .ocpersona in the repo root
  activate --unset                 Remove OCP_PROFILE from the repo .ocpersona
```

- [ ] **Step 2: Rewrite `cmd_activate` with flag parsing**

Replace the entire `cmd_activate` function (lines 418-448) with:

```sh
cmd_activate() {
  do_local=0
  do_unset=0
  profile_name=

  while [ $# -gt 0 ]; do
    case "$1" in
      --local)
        do_local=1
        ;;
      --unset)
        do_unset=1
        ;;
      --*)
        fail "Unknown flag: $1"
        ;;
      *)
        if [ -n "$profile_name" ]; then
          fail "Unexpected argument: $1"
        fi
        profile_name=$1
        ;;
    esac
    shift
  done

  if [ "$do_local" = "1" ] && [ "$do_unset" = "1" ]; then
    fail "--local and --unset are mutually exclusive"
  fi

  if [ "$do_unset" = "1" ]; then
    [ -z "$profile_name" ] || fail "--unset does not accept a profile name"
    repo_root=$(git_repo_root_for_pwd) || fail "Not inside a git repository"
    marker_file=$repo_root/.ocpersona
    remove_marker_profile_line "$marker_file"
    printf 'Removed OCP_PROFILE from %s\n' "$marker_file"
    return 0
  fi

  [ -n "$profile_name" ] || fail "Usage: ocpersona activate [--local] <profile> or ocpersona activate --unset"
  ensure_profile_name "$profile_name"
  profile_file=$(profile_file_for "$profile_name")
  [ -f "$profile_file" ] || fail "Profile file not found: $profile_file"

  if [ "$do_local" = "1" ]; then
    repo_root=$(git_repo_root_for_pwd) || fail "Not inside a git repository"
    marker_file=$repo_root/.ocpersona
    update_marker_file "$marker_file" "$profile_name"
    printf 'Set OCP_PROFILE=%s in %s\n' "$profile_name" "$marker_file" >&2
  fi

  cat <<EOF
export OCP_PROFILE='$profile_name'
export OCP_PROFILE_FILE='$profile_file'
export OCP_CONFIG_DIR='${DEFAULT_CONFIG_DIR}'
export OCP_PATH='${DEFAULT_OCP_PATH}'
export OCP_SHIM_DIR='$(runtime_shim_dir)'
$(emit_prepend_path_snippet "$(runtime_shim_dir)")
if command -v rehash >/dev/null 2>&1; then
  rehash
elif command -v hash >/dev/null 2>&1; then
  hash -r 2>/dev/null || true
fi
unset OCP_ACTIVE
unset XDG_CONFIG_HOME
unset XDG_DATA_HOME
unset XDG_STATE_HOME
unset XDG_CACHE_HOME
if command -v rehash >/dev/null 2>&1; then
  rehash
elif command -v hash >/dev/null 2>&1; then
  hash -r 2>/dev/null || true
fi
EOF
}
```

- [ ] **Step 3: Run shellcheck**

Run: `shellcheck bin/ocpersona`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add bin/ocpersona
git commit -m "Add --local and --unset flags to activate command"
```

---

### Task 3: Update `ocp-on` in the zsh plugin

**Files:**
- Modify: `contrib/ocpersona.plugin.zsh` (line 12-14)

- [ ] **Step 1: Update `ocp-on` function**

Replace lines 12-14:

Old:
```sh
ocp-on() {
  ocpersona activate "$@"
}
```

New:
```sh
ocp-on() {
  if [ "${1:-}" = "--unset" ]; then
    ocpersona activate --unset
  else
    ocpersona activate --local "$@"
  fi
}
```

- [ ] **Step 2: Commit**

```bash
git add contrib/ocpersona.plugin.zsh
git commit -m "Route ocp-on through activate --local"
```

---

### Task 4: Add tests for `--local` and `--unset`

**Files:**
- Modify: `tests/run.sh` (append before the final `printf 'All tests passed'`)

- [ ] **Step 1: Add test cases**

Append the following block before the final `printf '%s\n' "All tests passed"` line:

```sh
# --- activate --local tests ---

marker_repo=$tmp_dir/marker-repo
mkdir -p "$marker_repo"
(
  cd "$marker_repo"
  /usr/bin/env git init >/dev/null 2>&1
)

# Test 1: --local creates .ocpersona with correct content
(
  cd "$marker_repo"
  "$ROOT_DIR/bin/ocpersona" activate --local lshq >/dev/null
)
marker_path=$marker_repo/.ocpersona
[ -f "$marker_path" ] || {
  printf '%s\n' "Expected --local to create .ocpersona" >&2
  exit 1
}
/usr/bin/env grep -q '^export OCP_PROFILE=lshq$' "$marker_path" || {
  printf '%s\n' "Expected .ocpersona to contain export OCP_PROFILE=lshq" >&2
  exit 1
}

# Test 2: --local updates existing OCP_PROFILE line, preserves other lines
cat > "$marker_path" <<'MARKER'
export OCP_OC_BIN=/tmp/fake-bin
export OCP_PROFILE=oldname
export OCP_EXTRA=value
MARKER
(
  cd "$marker_repo"
  "$ROOT_DIR/bin/ocpersona" activate --local lebowski >/dev/null
)
/usr/bin/env grep -q '^export OCP_OC_BIN=/tmp/fake-bin$' "$marker_path" || {
  printf '%s\n' "Expected --local to preserve OCP_OC_BIN line" >&2
  exit 1
}
/usr/bin/env grep -q '^export OCP_PROFILE=lebowski$' "$marker_path" || {
  printf '%s\n' "Expected --local to update OCP_PROFILE line" >&2
  exit 1
}
/usr/bin/env grep -q '^export OCP_EXTRA=value$' "$marker_path" || {
  printf '%s\n' "Expected --local to preserve OCP_EXTRA line" >&2
  exit 1
}
old_count=$(/usr/bin/env grep -c '^export OCP_PROFILE=' "$marker_path")
[ "$old_count" = "1" ] || {
  printf '%s\n' "Expected exactly one OCP_PROFILE line, got $old_count" >&2
  exit 1
}

# Test 3: --local without git repo fails
if (
  cd "$nonrepo_dir"
  "$ROOT_DIR/bin/ocpersona" activate --local lshq >/dev/null 2>&1
); then
  printf '%s\n' "Expected --local to fail outside git repo" >&2
  exit 1
fi

# Test 4: --local without profile name fails
if (
  cd "$marker_repo"
  "$ROOT_DIR/bin/ocpersona" activate --local >/dev/null 2>&1
); then
  printf '%s\n' "Expected --local without profile to fail" >&2
  exit 1
fi

# Test 5: --unset removes OCP_PROFILE line, preserves others
cat > "$marker_path" <<'MARKER'
export OCP_OC_BIN=/tmp/fake-bin
export OCP_PROFILE=lebowski
export OCP_EXTRA=value
MARKER
(
  cd "$marker_repo"
  "$ROOT_DIR/bin/ocpersona" activate --unset >/dev/null
)
/usr/bin/env grep -q '^export OCP_OC_BIN=/tmp/fake-bin$' "$marker_path" || {
  printf '%s\n' "Expected --unset to preserve OCP_OC_BIN line" >&2
  exit 1
}
/usr/bin/env grep -q '^export OCP_EXTRA=value$' "$marker_path" || {
  printf '%s\n' "Expected --unset to preserve OCP_EXTRA line" >&2
  exit 1
}
if /usr/bin/env grep -q '^export OCP_PROFILE=' "$marker_path"; then
  printf '%s\n' "Expected --unset to remove OCP_PROFILE line" >&2
  exit 1
fi

# Test 6: --unset removes file when empty after removing line
printf '%s\n' "export OCP_PROFILE=solo" > "$marker_path"
(
  cd "$marker_repo"
  "$ROOT_DIR/bin/ocpersona" activate --unset >/dev/null
)
if [ -f "$marker_path" ]; then
  printf '%s\n' "Expected --unset to remove empty .ocpersona file" >&2
  exit 1
fi

# Test 7: --local and --unset together fails
if (
  cd "$marker_repo"
  "$ROOT_DIR/bin/ocpersona" activate --local lshq --unset >/dev/null 2>&1
); then
  printf '%s\n' "Expected --local --unset to fail as mutually exclusive" >&2
  exit 1
fi

# Test 8: plain activate still works
plain_output=$(
  cd "$marker_repo"
  "$ROOT_DIR/bin/ocpersona" activate lshq
)
printf '%s\n' "$plain_output" | /usr/bin/env grep -q "^export OCP_PROFILE='lshq'" || {
  printf '%s\n' "Expected plain activate to still work" >&2
  exit 1
}
```

- [ ] **Step 2: Run the full test suite**

Run: `cd /Users/andrew.burns/src/erebusbat/ocpersona && sh tests/run.sh`
Expected: `All tests passed`

- [ ] **Step 3: Commit**

```bash
git add tests/run.sh
git commit -m "Add tests for activate --local and --unset"
```

---

### Task 5: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the `activate` section**

In the "Print shell code to activate a profile" section (around line 113-121), add after the existing `activate` examples:

```md
Write the profile to the repo marker file and activate:

```sh
bin/ocpersona activate --local lshq
```

Remove the profile from the repo marker file:

```sh
bin/ocpersona activate --unset
```

`--local` writes or updates `export OCP_PROFILE=<profile>` in `<repo-root>/.ocpersona`. If the file already exists with other `export` lines (for example, `OCP_OC_BIN`), those lines are preserved. If the file does not exist, it is created. The command fails if not inside a git repository.

`--unset` removes the `export OCP_PROFILE=...` line from `<repo-root>/.ocpersona`, preserving all other lines. If the file is empty after removal, it is deleted. The command fails if not inside a git repository.

`--local` and `--unset` are mutually exclusive.
```

- [ ] **Step 2: Update the `ocp-on` description**

In the zsh plugin section (around line 309), update:

Old: "adds `ocp-on` and `ocp-off` convenience wrappers"

New: "adds `ocp-on` and `ocp-off` convenience wrappers — `ocp-on <profile>` activates and writes `.ocpersona`, `ocp-on --unset` removes the profile from `.ocpersona`"

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Document activate --local and --unset in README"
```
