# ocpersona

`ocpersona` is a small launcher for persona-aware OpenCode sessions.

The first pass focuses on one explicit contract:

- `OCP_PROFILE` selects a profile
- `OCP_PATH` points at the installed `ocpersona` runtime
- profile files are external shell snippets
- `opencode` is intercepted through a shim on `PATH`

This keeps configuration separate from implementation and makes it possible to isolate credentials and runtime state by profile.

## Concepts

- `persona`: the tool/runtime behavior provided by `ocpersona`
- `profile`: a specific configuration selected through `OCP_PROFILE`

## Current Design

`ocpersona` loads a profile shell file, exports `OCP_` variables, sets isolated XDG directories by profile, and then executes the requested command.

The `opencode` shim is intentionally thin:

- if `OCP_PROFILE` is unset, it falls through to the real `opencode`
- if `OCP_PROFILE` is set, it delegates back to `ocpersona`

This allows commands like `ocx oc -p lshq` to stay inside the selected profile when `ocx` shells out to `opencode`.

## Profile Files

By default, profile files are loaded from:

```text
${OCP_CONFIG_DIR:-$HOME/.config/ocpersona}/profiles/<profile>/ocpersona.sh
```

These files are sourced by `ocpersona` and can define values such as:

```sh
profile_dir="${OCP_PROFILE_FILE%/*}"
XDG_CONFIG_HOME="${profile_dir}/config"
OCP_OC_BIN=/opt/homebrew/Cellar/opencode/1.14.28/bin/opencode
XDG_DATA_HOME="${profile_dir}/data"
XDG_STATE_HOME="${profile_dir}/state"
XDG_CACHE_HOME="$HOME/.cache/opencode-work"
```

`OCP_PROFILE_FILE` is exported before the profile file is sourced, so profile snippets can derive paths from it.
If a profile does not set them explicitly, `ocpersona` defaults `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_STATE_HOME` to profile-scoped directories under `~/.config/ocpersona/profiles/<profile>/`.

If `OCP_OC_BIN` is unset, `ocpersona` defaults it to the full real path of `command -v opencode` before shim interception.

## Runtime Location

By default, `ocpersona` runs directly from its checkout path:

```text
${OCP_PATH:-<current checkout>}
```

That location holds:

- `bin/ocpersona`
- `shims/opencode`
- `contrib/ocpersona.plugin.zsh`
- `examples/profile.sh.example`

Tracked repository files should not contain personal or employer-specific paths unless they are generic examples.

## Commands

Run a command inside a profile:

```sh
bin/ocpersona exec lshq -- ocx oc -p lshq
```

Print shell code to activate a profile:

```sh
bin/ocpersona activate lshq
```

Activate it in the current shell:

```sh
eval "$(bin/ocpersona activate lshq)"
```

Deactivate the current profile:

```sh
eval "$(bin/ocpersona deactivate)"
```

Install the zsh plugin block into your shell config:

```sh
bin/ocpersona install
```

By default this writes to `${ZSHRC}`, then `${ZDOTDIR}/.zshrc`, then `~/.zshrc`.
It writes `${OCP_CONFIG_DIR:-$HOME/.config/ocpersona}/config.sh`, which sets `OCP_PATH` if it is unset and prefers a `$HOME`-relative value when the checkout lives under your home directory, and the managed shell block sources `$HOME/.config/ocpersona/config.sh` before loading that checkout's `contrib/ocpersona.plugin.zsh`.

Install into a different file instead:

```sh
bin/ocpersona install ~/.config/zsh-antibody/ocpersona/ocpersona.plugin.zsh
```

Install a managed Starship block that shows the active `OCP_PROFILE`:

```sh
bin/ocpersona install-starship
```

By default this writes to `${STARSHIP_CONFIG}`, if set, otherwise `~/.config/starship.toml`.
It installs an `[env_var.OCP_PROFILE]` module, which works with Starship's default `format = '$all'`.
If you use a custom Starship prompt format that omits `$env_var`, add `${env_var.OCP_PROFILE}` or `$env_var` explicitly.

Install into a different Starship config file instead:

```sh
bin/ocpersona install-starship ~/.config/starship.toml
```

Clone your existing OpenCode config into a new profile:

```sh
bin/ocpersona clone-default
bin/ocpersona clone-default lebowski
```

The source directory is `${XDG_CONFIG_HOME:-$HOME/.config}/opencode`.
If your shell already exports `XDG_CONFIG_HOME`, `clone-default` uses that value even when `HOME` points somewhere else.
If present, `clone-default` also copies `${XDG_DATA_HOME:-$HOME/.local/share}/opencode` and `${XDG_STATE_HOME:-$HOME/.local/state}/opencode` into the profile's default data and state homes.

This creates:

- `${OCP_CONFIG_DIR:-$HOME/.config/ocpersona}/profiles/<profile>/ocpersona.sh`
- `${OCP_CONFIG_DIR:-$HOME/.config/ocpersona}/profiles/<profile>/config/opencode`
- `${OCP_CONFIG_DIR:-$HOME/.config/ocpersona}/profiles/<profile>/data/opencode` when source data exists
- `${OCP_CONFIG_DIR:-$HOME/.config/ocpersona}/profiles/<profile>/state/opencode` when source state exists

The generated profile file derives `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_STATE_HOME` from `OCP_PROFILE_FILE` so that the profile stays self-contained under one directory.
Cache is intentionally not cloned.

Purge a profile and remove all of its profile-scoped files:

```sh
bin/ocpersona purge
bin/ocpersona purge lebowski
```

This removes:

- `${OCP_CONFIG_DIR:-$HOME/.config/ocpersona}/profiles/<profile>`
- `$HOME/.cache/ocpersona/<profile>`

Print shell init code:

```sh
eval "$(bin/ocpersona init zsh)"
```

After init, the `ocpersona` shell function handles activation for you:

```sh
ocpersona activate lshq
opencode
ocpersona deactivate
```

With an active profile, normal `opencode` usage is routed through the shim:

```sh
export OCP_PROFILE=lshq
opencode
```

The explicit activation flow keeps the first version simple:

- `activate` sets `OCP_PROFILE` and shim-related variables in the current shell
- the shim loads the full profile file only when `opencode` is actually launched
- `deactivate` clears the active profile state without removing the shim from `PATH`

Inspect the current setup:

```sh
ocpersona doctor
```

This prints:

- whether the current shell is using the shell integration or a direct command path
- the active `opencode` command on `PATH`
- `OCP_PATH`, `OCP_PROFILE`, `OCP_PROFILE_FILE`, and related variables
- whether a profile is selected and whether its runtime environment is currently loaded
- the current `XDG_*` values and the effective profile-scoped XDG homes
- profile-defined values like `OCP_OC_BIN` and profile XDG overrides when a profile file exists
- effective config and XDG home values that would apply once the selected profile is loaded
- the effective resolved `opencode` binary path
- the current XDG directories
- the Starship config path `install-starship` will target and whether the managed block is present

## Zsh Plugin

A small zsh plugin snippet lives at [contrib/ocpersona.plugin.zsh](/Users/andrew.burns/src/erebusbat/ocpersona/contrib/ocpersona.plugin.zsh).

It:

- initializes the shim on `PATH`
- defines an `ocpersona` shell function that can activate and deactivate profiles
- adds `ocp-on` and `ocp-off` convenience wrappers

You can source it directly or adapt it into your dotfiles. When sourced directly, it defaults `OCP_PATH` to the checkout that contains the plugin file.

The `install` command appends a managed block that sources `$HOME/.config/ocpersona/config.sh` and then sources this plugin file from the current checkout. Rerunning `install` refreshes that managed `config.sh` file to the current checkout path, using a `$HOME`-relative value when possible, which doubles as the upgrade story after you update the repository. If you use a more custom setup, point `install` at the file you want to manage instead of your default `ZSHRC`.

## Starship

If you use [Starship](https://starship.rs/), `ocpersona` can manage a small config block that displays the active `OCP_PROFILE` in your prompt:

```sh
bin/ocpersona install-starship
```

This writes an `[env_var.OCP_PROFILE]` block into `${STARSHIP_CONFIG}` or `~/.config/starship.toml` by default. The managed block is replaced on rerun, similar to `install`.

The installed block looks like:

```toml
[env_var.OCP_PROFILE]
variable = "OCP_PROFILE"
format = "[ocp:$env_value]($style) "
style = "bold fg:39"
description = "The active ocpersona profile"
```

According to the Starship configuration docs, `env_var` modules are included by default when you use the default top-level prompt format (`format = '$all'`). If you use a custom format that omits `$env_var`, add `$env_var` or `${env_var.OCP_PROFILE}` explicitly so the profile module renders.

## Future Directions

The initial version is explicit by design. Later enhancements could include:

- profile activation helpers
- directory-based profile discovery
- project marker files
- wrappers for additional commands beyond `opencode`
