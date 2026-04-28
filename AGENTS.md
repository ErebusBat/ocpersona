# AGENTS.md

## Purpose

`ocpersona` provides lightweight persona-aware launch tooling for OpenCode-family commands.

The repository should stay generic and reusable:

- Keep profile-specific values out of tracked files.
- Put user- or employer-specific settings in external profile shell files.
- Treat `persona` as the tool/runtime concept and `profile` as the selected configuration.

## Git

Use `/usr/bin/env git` for all Git operations.

## Implementation Notes

- Prefer portable shell over heavier runtime dependencies for the core launcher.
- Keep shims thin and put decision-making logic in `bin/ocpersona`.
- Default to explicit behavior. Avoid auto-discovery until it is intentionally designed.
- Favor additive configuration with `OCP_`-prefixed variables so the environment contract can grow without renaming.
- The install flow should point `OCP_PATH` at the active checkout instead of copying runtime files elsewhere.
- Treat `install` as managed shell integration setup and `doctor` as the primary inspection/debugging entrypoint.
