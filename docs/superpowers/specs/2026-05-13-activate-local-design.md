# activate --local: Write/Update Repo Marker on Activation

## Summary

Extend `ocp-on` (backed by `ocpersona activate`) to create or update the `.ocpersona` repo marker file when activating a profile, and to remove the profile entry with `--unset`.

## Motivation

Currently, associating a repo with a profile requires manually creating a `.ocpersona` file at the repo root. This is error-prone and disconnected from the activation workflow. Adding `--local` to `activate` makes profile-to-repo binding a single step.

## Approach

Add `--local` and `--unset` flags to the existing `activate` command in `bin/ocpersona`. Update `ocp-on` in the zsh plugin to pass `--local` through.

## Changes

### `bin/ocpersona` — `cmd_activate`

New flags:

- `--local <profile>` — after emitting activation shell code, write or update `<repo-root>/.ocpersona` with `export OCP_PROFILE=<profile>`. Fails if not inside a git repo.
- `--unset` — remove the `export OCP_PROFILE=...` line from `<repo-root>/.ocpersona`. Does not activate a profile. Fails if not inside a git repo.

`--local` and `--unset` are mutually exclusive. `<profile>` is required with `--local` and forbidden with `--unset`.

#### File write behavior for `--local`

1. `.ocpersona` does not exist: create with `export OCP_PROFILE=<name>`
2. `.ocpersona` exists with `export OCP_PROFILE=...` line: replace that line
3. `.ocpersona` exists without `OCP_PROFILE` line: append `export OCP_PROFILE=<name>`
4. All other lines in the file are preserved in every case

#### File write behavior for `--unset`

1. Remove the `export OCP_PROFILE=...` line if present
2. If the resulting file is empty, remove the file
3. All other lines are preserved

#### `usage()` update

```
  activate [--local] <profile>       Print shell code to activate a profile
                                      --local also writes .ocpersona in the repo root
  activate --unset                   Remove OCP_PROFILE from the repo .ocpersona
```

### `contrib/ocpersona.plugin.zsh` — `ocp-on`

```sh
ocp-on() {
  if [ "${1:-}" = "--unset" ]; then
    ocpersona activate --unset
  else
    ocpersona activate --local "$@"
  fi
}
```

`ocp-off` is unchanged.

### `tests/run.sh`

New test cases:

1. `activate --local <profile>` inside a git repo creates `.ocpersona` with `export OCP_PROFILE=<profile>`
2. `activate --local <profile>` updates an existing `export OCP_PROFILE=...` line without touching other lines
3. `activate --local <profile>` from outside a git repo fails
4. `activate --local` without a profile name fails with a usage error
5. `activate --unset` removes the `export OCP_PROFILE=...` line, preserves other lines
6. `activate --unset` removes the file if it becomes empty after removing the line
7. `activate --local <profile> --unset` fails (mutually exclusive flags)
8. Plain `activate <profile>` (no flags) continues to work identically

### `README.md`

Add documentation for `--local` and `--unset` to the `activate` section and update the `ocp-on` description.

## What Does Not Change

- `auto_detect_profile_if_unset` — continues reading `.ocpersona` as before
- `activate` output without flags — identical to current behavior
- `deactivate` / `ocp-off` — unchanged
- The `.ocpersona` file format — still a sourced shell file, same marker path
