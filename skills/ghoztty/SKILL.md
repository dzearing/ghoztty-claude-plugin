---
name: ghoztty
description: Use when opening terminal windows, creating split pane layouts, listing open windows/panes, renaming window titles, rearranging pane layouts, reading terminal output, sending keystrokes to panes, setting activity state, or managing Ghoztty windows via CLI. Ghoztty is a terminal emulator with IPC commands for programmatic window/pane management. Use this skill whenever you need to launch a terminal, create splits, query window state, rename windows, rearrange layouts, read pane output, send input to panes, track activity state, or tear down layouts.
---

# Ghoztty CLI Reference

Ghoztty is a fork of Ghostty that adds CLI-driven window management over a Unix domain socket. All IPC commands are **idempotent** — named targets that already exist are focused instead of recreated.

## Prerequisites

Before running any `ghoztty` commands, verify it's available:

```bash
command -v ghoztty
```

If not found, tell the user:

> **ghoztty not found.** Install it from https://github.com/dzearing/ghoztty/releases and make sure it's in your PATH.

Do NOT proceed if `ghoztty` is unavailable.

## Commands

### `ghoztty +new-window`

Create or focus a terminal window. **Auto-launches Ghoztty if no instance is running.**

```
ghoztty +new-window [flags]
```

| Flag | Description |
|------|-------------|
| `--target=<name>` | Register window with a name. If it already exists, focuses it instead. |
| `--working-directory=<path>` | Working directory for the terminal. Relative paths are resolved from CWD. `~` is expanded. If omitted, uses the CWD where `ghoztty` is invoked. |
| `--command=<cmd>` | Command to run in the terminal. Auto-wrapped in the user's login shell with profile loaded. |
| `--shell=<path>` | Shell to use for `--command`/`--split-command`, invoked with `-lic`. Falls back to config `command-shell`, then `$SHELL`, then `/bin/zsh`. |
| `--env=KEY=VALUE` | Environment variable for the spawned process. Repeatable. |
| `--no-activate` | Create the window without stealing focus from the current workspace. Useful for automation and background agent windows. |
| `--title=<title>` | Override the window/tab title. |
| `--split=right\|down\|left\|up` | Atomically create a split pane alongside the main pane. |
| `--color=<#hex\|random>` | Background color for the window. Hex (`#rrggbb` or `#rgb`) or `random` for a random dark tint. |
| `--split-color=<#hex\|random>` | Background color for the split pane (only with `--split`). |
| `--split-command=<cmd>` | Command for the split pane (only with `--split`). |
| `--split-percent=<1-99>` | Percentage of space for the new split pane (default 50, only with `--split`). |
| `-e <args...>` | Everything after `-e` becomes the command. No more flags are parsed. |

### `ghoztty +split`

Create a split pane in a running window.

```
ghoztty +split [flags]
```

| Flag | Description |
|------|-------------|
| `--direction=right\|down\|left\|up` | Split direction. Default: `right`. |
| `--target=<name>` | Window or pane to split in. Must have been created with `--target` or `--name`. Default: most recently focused window. |
| `--name=<name>` | Register the new pane with a name. If it already exists, focuses it instead. |
| `--command=<cmd>` | Command to run in the new pane. Auto-wrapped in the user's login shell with profile loaded. |
| `--shell=<path>` | Shell to use for `--command`, invoked with `-lic`. Falls back to config `command-shell`, then `$SHELL`, then `/bin/zsh`. |
| `--env=KEY=VALUE` | Environment variable for the spawned process. Repeatable. |
| `--color=<#hex\|random>` | Background color for the new pane. |
| `--working-directory=<path>` | Working directory for the new pane. |
| `-e <args...>` | Everything after `-e` becomes the command. |

### `ghoztty +list`

List all open windows, tabs, and panes. Human-readable tree view by default, `--json` for machine-readable output. Requires a running Ghoztty instance.

```
ghoztty +list [flags]
```

| Flag | Description |
|------|-------------|
| `--json` | Output machine-readable JSON instead of the default tree view. |

**Human-readable output:**

```
Window: "Editor" [target: editor] (focused)
  Tab 1: "Editor" (selected)
    ├─ ~/projects  /Users/david/projects  pid:12345  /dev/ttys003  [name: main-editor]
    ├─ ~/logs  /Users/david/logs  pid:12346  /dev/ttys004  [name: logs]
    └─ ~/src  /Users/david/src  pid:12347  /dev/ttys005  [name: terminal] *
Window: "~/docs"
  Tab 1: "~/docs" (selected)
    ~/docs  /Users/david/docs  pid:12348  /dev/ttys006 *
```

- Single-pane tabs show the terminal inline (no tree characters)
- Multi-pane tabs use `├─`/`└─` tree connectors
- `*` marks the focused terminal in each tab
- `[target: X]` and `[name: X]` shown when set
- Empty state prints `No windows open.`

**JSON output structure (`--json`):**

```json
{
  "success": true,
  "data": {
    "windows": [
      {
        "id": "tab-group-8f436dd60",
        "title": "Editor",
        "target": "editor",
        "focused": true,
        "tabs": [
          {
            "id": "tab-8f5985200",
            "title": "Editor",
            "index": 1,
            "selected": true,
            "splits": {
              "type": "leaf",
              "terminal": {
                "id": "485DECDE-...",
                "title": "~/projects",
                "working_directory": "/Users/david/projects",
                "pid": 12345,
                "tty": "/dev/ttys003",
                "name": "main-editor",
                "focused": true,
                "exit_code": null
              }
            }
          }
        ]
      }
    ]
  }
}
```

**Key JSON fields:**
- **`target`** (on windows): User-provided name from `+new-window --target=X`, or auto-generated (`window-1`, `window-2`, etc.)
- **`name`** (on terminals): User-provided from `+split --name=X`, or auto-generated UUID
- **`splits`**: Recursive tree — `"type":"leaf"` contains a `terminal` object, `"type":"split"` contains `direction` (`horizontal`/`vertical`), `ratio`, `left`, `right`
- **`focused`**: On windows = frontmost window. On terminals = focused pane in its tab.
- **`exit_code`**: `null` if the process is still running, or the exit code (e.g. `0`, `1`) if it has exited. Human-readable output shows `running` or `exited(N)`.

**Side effect:** `+list` auto-registers all discovered windows and panes in the target registry, so names from the output can immediately be used with `+close --target=<name>` or `+split --target=<name>`.

### `ghoztty +rename`

Change the display title of a named window. The target registry name is **not** affected.

```
ghoztty +rename --target=<name> --title=<new-title>
```

| Flag | Description |
|------|-------------|
| `--target=<name>` | The named window or pane whose title to change. Required. |
| `--title=<new-title>` | The new display title for the window/tab title bar. Required. |

Returns an error if the target doesn't exist in the registry.

### `ghoztty +rearrange`

Rebuild the split tree of a window to match a declarative JSON layout. **Preserves terminal state** — running processes, scrollback, and focus are kept intact. Panes are reparented in the tree, not destroyed and recreated.

```
ghoztty +rearrange [flags]
```

| Flag | Description |
|------|-------------|
| `--target=<name>` | Window to rearrange. Default: most recently focused window. |
| `--layout=<json>` | JSON layout descriptor (required). See format below. |

**Layout JSON format:**

The layout is a tree with two node types:

- **Leaf**: `{"pane": "<name>"}` — references an existing named pane
- **Split**: `{"direction": "horizontal|vertical", "ratio": <0-100>, "left": <node>, "right": <node>}`

| Field | Description |
|-------|-------------|
| `direction` | `"horizontal"` (left\|right) or `"vertical"` (top\|bottom) |
| `ratio` | Percentage given to the left/top child. Default: 50. Clamped to 10–90. |
| `left`, `right` | Child nodes (each is a leaf or another split) |

**Behavior:**
- All pane names in the layout must exist in the target window's registry.
- Panes **not** mentioned in the layout are removed from the tree.
- Focus is preserved if the focused pane is in the new layout; otherwise moves to the first leaf.
- Supports undo (Cmd+Z restores the previous layout).

**Example — editor at 40%, three workers stacked vertically:**

```bash
ghoztty +rearrange --target=ide --layout='{
  "direction": "horizontal",
  "ratio": 40,
  "left": {"pane": "editor"},
  "right": {
    "direction": "vertical",
    "ratio": 33,
    "left": {"pane": "worker1"},
    "right": {
      "direction": "vertical",
      "ratio": 50,
      "left": {"pane": "worker2"},
      "right": {"pane": "worker3"}
    }
  }
}'
```

**Example — swap two panes:**

```bash
# Before: editor left, terminal right
# After: terminal left, editor right
ghoztty +rearrange --target=ide --layout='{
  "direction": "horizontal",
  "ratio": 50,
  "left": {"pane": "terminal"},
  "right": {"pane": "editor"}
}'
```

**Example — query then rearrange:**

```bash
# Get current state, then rebuild layout
state=$(ghoztty +list --json)
# Parse pane names from $state, construct new layout, then:
ghoztty +rearrange --target=mywin --layout='...'
```

### `ghoztty +close`

Close a named pane or window. **Closing a nonexistent target succeeds silently** (idempotent).

```
ghoztty +close --target=<name>
```

### `ghoztty +read`

Read the last N lines of terminal output from a named pane and print to stdout. Useful for inspecting command output, logs, or checking if a process has finished.

```
ghoztty +read --name=<pane> [--lines=<N>]
```

| Flag | Description |
|------|-------------|
| `--name=<pane>` | Named pane to read from. Required. |
| `--lines=<N>` | Number of lines from the end of scrollback (default: 50). |

### `ghoztty +send-keys`

Send text and key sequences to a named pane's terminal PTY. Enables scripted interaction with running processes.

```
ghoztty +send-keys --target=<name> <text|key>...
```

| Flag / Arg | Description |
|------------|-------------|
| `--target=<name>` | Named pane or window to send input to. Required. |
| Positional args | Text strings and key names, concatenated and written to the PTY. |

**Key notation:**
- Control keys: `C-c` (Ctrl-C), `C-d` (Ctrl-D), `C-z` (Ctrl-Z), etc.
- Named keys: `Enter`, `Tab`, `Escape`, `Space`, `Backspace`
- Escape sequences in text: `\n`, `\t`, `\r`, `\\`, `\e`

```bash
ghoztty +send-keys --target=term "ls -la" Enter
ghoztty +send-keys --target=term C-c
ghoztty +send-keys --target=term "hello\tworld\n"
```

### `ghoztty +set-state`

Set the activity state of a named window or pane. State is aggregated across all panes in a window (priority: `needs_input` > `busy` > `idle`) and shown as a title suffix and custom `AXWindowActivityState` accessibility attribute. Transition to `needs_input` triggers `requestUserAttention`.

```
ghoztty +set-state --target=<name> --state=<idle|busy|needs_input>
```

| Flag | Description |
|------|-------------|
| `--target=<name>` | Named window or pane. Required. |
| `--state=<state>` | Activity state: `idle`, `busy`, or `needs_input`. Required. |

Processes can also set state via OSC escape sequence: `\033]7777;<state>\007`

```bash
ghoztty +set-state --target=dev --state=busy
ghoztty +set-state --target=dev --state=needs_input
ghoztty +set-state --target=dev --state=idle
```

## Naming System

- `+new-window --target=<name>` registers a **window**
- `+split --name=<name>` registers a **pane**
- `+split --target` and `+close --target` can reference **either** kind
- Names are unique across all windows and panes

## Background Colors

- `--color=#1a1a2e` sets a specific hex background color on a window or pane.
- `--color=random` generates a random dark-tinted background (charcoal with subtle hue).
- When splitting a pane (ctrl-d or `+split`), the child pane automatically inherits a slightly lighter version of the parent's background for visual depth.
- Right-click a pane → "Background Color..." opens a live color picker.

## Key Behaviors

1. **Idempotency**: Re-running a command with the same `--target` or `--name` focuses the existing window/pane instead of creating a duplicate. This makes commands safe to retry.
2. **Auto-launch**: `+new-window` launches Ghoztty.app if no instance is running. `+split` and `+close` require a running instance.
3. **Atomic splits**: Use `+new-window --split=<dir>` to create a window with a split in one command, avoiding timing issues from sequential `+new-window` then `+split`.
4. **Shell initialization**: `--command` auto-wraps in the user's login shell with profile loaded, so aliases, PATH, nvm, etc. work out of the box. Use `--shell` to override which shell is used.

## Patterns

### Open a named window with a command

```bash
ghoztty +new-window --target=myapp --working-directory=/path/to/project --command="nvim ."
```

### Two-pane layout (editor + shell)

```bash
ghoztty +new-window \
  --target=dev \
  --working-directory=/path/to/project \
  --command="nvim ." \
  --split=down \
  --split-command="exec zsh -l"
```

### Three-pane layout (built sequentially)

```bash
ghoztty +new-window --target=ide --command="nvim ."
ghoztty +split --target=ide --name=term --direction=down --command=zsh
ghoztty +split --target=ide --name=logs --direction=right --command="tail -f app.log"
```

### Launch Claude Code in a named window

```bash
wt_path="$(cd /path/to/project && pwd)"
ghoztty +new-window \
  --target=task-name \
  --working-directory="${wt_path}" \
  --title="project: task-name" \
  --command="cl \"your prompt here\""
```

### Rename a window's title

```bash
ghoztty +rename --target=dev --title="Project: my-feature"
```

### Discover what's running, then target it

```bash
# Get JSON state
state=$(ghoztty +list --json)
# Parse with jq to find a specific pane, then close it
target=$(echo "$state" | jq -r '.data.windows[0].target')
ghoztty +close --target="$target"
```

### Rearrange: prioritize one pane, tile the rest

```bash
# Create 4 panes
ghoztty +new-window --target=work --command=zsh
ghoztty +split --target=work --name=main --direction=right --command=zsh
ghoztty +split --target=work --name=aux1 --direction=down --pane=main --command=zsh
ghoztty +split --target=work --name=aux2 --direction=right --pane=aux1 --command=zsh

# Rearrange: main gets 70% left, aux panes tile 2x1 on right
ghoztty +rearrange --target=work --layout='{
  "direction": "horizontal",
  "ratio": 70,
  "left": {"pane": "main"},
  "right": {
    "direction": "vertical",
    "ratio": 50,
    "left": {"pane": "aux1"},
    "right": {"pane": "aux2"}
  }
}'
```

### Read output from a pane

```bash
# Check what a running process has printed
ghoztty +read --name=term --lines=10

# Capture output for processing
output=$(ghoztty +read --name=build --lines=100)
echo "$output" | grep "error"
```

### Send commands to a running pane

```bash
# Run a command in an existing pane
ghoztty +send-keys --target=term "npm test" Enter

# Interrupt a running process
ghoztty +send-keys --target=term C-c

# Send EOF to close a shell
ghoztty +send-keys --target=term C-d
```

### Track activity state

```bash
# Mark a pane as busy while working
ghoztty +set-state --target=dev --state=busy
# Signal that user input is needed
ghoztty +set-state --target=dev --state=needs_input
# Mark idle when done
ghoztty +set-state --target=dev --state=idle
```

### Pass environment variables

```bash
ghoztty +new-window \
  --target=api \
  --env=API_KEY=sk-123 \
  --env=DEBUG=true \
  --command="node server.js"
```

### Clean teardown (reverse order)

```bash
ghoztty +close --target=logs
ghoztty +close --target=term
ghoztty +close --target=ide
```

Closing a nonexistent target is a no-op, so teardown scripts are safe even if some panes were already closed.

## Common Mistakes to Avoid

- **Don't use `+split` before `+new-window`** — there must be a running instance and a target window.
- **Don't manually wrap with `zsh -lic`** — `--command` auto-wraps in the user's login shell. Use `--shell` only if you need a different shell.
- **Don't use sequential `+new-window` then `+split`** for the initial layout — use `--split` and `--split-command` on `+new-window` for atomicity.
- **Don't assume `--working-directory` propagates to `--split-command`** — the split pane must `cd` explicitly if it needs the same directory.
