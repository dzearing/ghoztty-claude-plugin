---
name: ghoztty
description: Use when opening terminal windows, creating split pane layouts, opening a rendered markdown/doc/README, a code file, or a website in a viewer ("side") pane, listing open windows/panes, renaming window titles, rearranging pane layouts, reading terminal output, sending keystrokes to panes, setting activity state, showing a sticky status banner above a pane, or managing Ghoztty windows via CLI. Ghoztty is a terminal emulator with IPC commands for programmatic window/pane management. Use this skill whenever you need to launch a terminal, create splits, open a file or website in a side/viewer pane (rendered markdown, syntax-highlighted code, or a webpage), query window state, rename windows, rearrange layouts, read pane output, send input to panes, track activity state, post a persistent banner with status/links above a pane, or tear down layouts. When the user says "open X in a side pane", "show the readme/doc beside this", or "preview this markdown", use `+split --view=<path-or-url>`.
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
| `--view=<path-or-url>` | Open a **viewer** pane instead of a terminal: a rendered markdown file, a syntax-highlighted text/code file, or a website (http/https URL). Relative paths resolve against `--working-directory` (else caller cwd). Mutually exclusive with `--command`/`-e`. |
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
| `--view=<path-or-url>` | Open the new pane as a **viewer** (rendered markdown / highlighted code / website) instead of a terminal. Relative paths resolve against `--working-directory` (else caller cwd). Mutually exclusive with `--command`/`-e`. This is the way to "open a file/README/doc in a side pane". |
| `--shell=<path>` | Shell to use for `--command`, invoked with `-lic`. Falls back to config `command-shell`, then `$SHELL`, then `/bin/zsh`. |
| `--env=KEY=VALUE` | Environment variable for the spawned process. Repeatable. |
| `--color=<#hex\|random>` | Background color for the new pane. |
| `--working-directory=<path>` | Working directory for the new pane. |
| `-e <args...>` | Everything after `-e` becomes the command. |

### Viewer panes (`--view=<path-or-url>`)

Both `+new-window` and `+split` accept `--view` to open a **viewer pane** instead
of a terminal. This is the built-in way to honor "open the README in a side pane",
"show that doc beside this", or "preview this markdown" — **do not** shell out to
`less`/`cat`/`open` for that. The pane renders:

- **Markdown** files — fully rendered (GitHub styling, code highlighting, task
  lists), with **live reload** on save (scroll position preserved).
- **Text / code** files — syntax-highlighted, read-only.
- **Websites** — any `http(s)://` URL (this is the only mode that uses the
  network; file rendering is fully offline via bundled assets).

It follows the system/app light-dark theme automatically. Viewer panes are
**view-only** (no editing) and are ordinary leaves in the split tree, so
`--name`, `--target`, `--split-percent`, `+close`, and `+rearrange` all work on
them. Idempotent: re-running with the same `--name` focuses the existing viewer
instead of opening another. (Minor gap: while a viewer pane is focused, some
`goto_split` keybindings may not fire — click a terminal pane to regain them.)

```bash
# Open a README in a rendered pane to the right of the current pane
ghoztty +split --direction=right --view=README.md

# A doc pane at 45% width, named so you can refocus/close it later
ghoztty +split --direction=right --split-percent=45 --name=docs \
  --working-directory=/path/to/project --view=docs/design/overview.md

# A standalone viewer window for a webpage
ghoztty +new-window --target=changelog --view=https://example.com/changelog

# Editor + live-rendered markdown preview, side by side (two steps)
ghoztty +new-window --target=notes --command="nvim NOTES.md"
ghoztty +split --target=notes --direction=right --name=preview --view=NOTES.md
```

### Auto-preview conventions (build → show it beside the work)

When you produce something previewable, **show it in a viewer pane automatically**
— don't wait to be asked, and don't paste raw output into the terminal. Use a
**1/3 ⁄ 2/3 layout**: work panes stacked vertically in the left third, the
preview filling the right two-thirds. The `--split-percent=66` gives the new
right pane 2/3 of the width, leaving 1/3 for your work column.

**Trigger 1 — you author or edit a Markdown design doc / README / spec.**
Open it in a right-hand 2/3 viewer. Markdown viewers **live-reload on save**, so
you set this up once and every edit re-renders automatically (no `+reload`).

```bash
# From your working pane: doc preview fills the right 2/3
ghoztty +split --direction=right --split-percent=66 --name=preview --view=docs/design/spec.md
# ...keep editing docs/design/spec.md — the preview re-renders on each save.
```

**Trigger 2 — you scaffold or edit a mock HTML app / prototype.**
An HTML *file* opened with `--view` renders as syntax-highlighted **source**, not
a live page — so **host it** and view the URL. Run a static server (or the app's
own dev server) in a work pane in the left third, then point the preview at its
URL. URL viewers do **not** auto-reload, so `+reload` the preview after edits.

```bash
# 1. Serve the app from a work pane stacked below your session (left third)
ghoztty +split --direction=down --name=server \
  --working-directory=/path/to/app --command="python3 -m http.server 8000"
#    (framework app? use its dev server instead, e.g. --command="npm run dev")

# 2. Preview the running app in the right 2/3
ghoztty +split --direction=right --split-percent=66 --name=preview \
  --view=http://localhost:8000

# 3. After each edit, refresh the preview (URL viewers don't live-reload)
ghoztty +reload --target=preview
```

**Locking the exact 1/3-stacked ⁄ 2/3-preview layout.** When you have several
work panes and want them tiled deterministically in the left third with the
preview pinned to the right 2/3, name every pane and `+rearrange`:

```bash
ghoztty +rearrange --target=<window> --layout='{
  "direction": "horizontal",
  "ratio": 33,
  "left": {
    "direction": "vertical",
    "ratio": 50,
    "left": {"pane": "session"},
    "right": {"pane": "server"}
  },
  "right": {"pane": "preview"}
}'
```

### `ghoztty +reload`

Reload a named **viewer pane** in place — no close/reopen. Website viewers re-fetch the page from origin (bypassing caches); file viewers re-render the file preserving scroll position. Local file viewers already live-reload on save, so this mainly matters for `--view=<url>` panes (e.g. refresh a dev-server preview after a rebuild).

```
ghoztty +reload --target=<name>
```

| Flag | Description |
|------|-------------|
| `--target=<name>` | Named window or pane (or a pane id). Required. For a window target, the reload applies to its focused pane. |

- Targeting a terminal pane fails with `... is a terminal pane, nothing to reload` (exit 1) — mirroring how terminal-only commands reject viewer panes.

```bash
# Refresh a local dev-server preview after rebuilding
ghoztty +split --target=dev --name=preview --view=http://localhost:3000
# ... rebuild ...
ghoztty +reload --target=preview
```

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

### `ghoztty +set-banner`

Set or clear a **sticky banner** rendered above a pane's terminal content. The banner is a native overlay — it persists across scrolling, screen clears, and content updates until you change or clear it. Ideal for pinning status, progress, or links (e.g. a PR link) above the pane you're working in.

```
ghoztty +set-banner --target=<name> [--clear] [text...]
```

| Flag / Arg | Description |
|------------|-------------|
| `--target=<name>` | Named pane or window. Required. For a window target, the banner is applied to its focused pane (banners are per-pane). |
| `--clear` | Remove the banner. Empty text does the same. |
| Positional args | Banner text (multiple args are joined with spaces). |

**Formatting** (markdown subset):

| Syntax | Result |
|--------|--------|
| `**text**` | bold |
| `*text*` or `_text_` | italic |
| `__text__` | underline (differs from CommonMark, where `__` is bold) |
| `` `text` `` | monospace code |
| `[label](https://url)` | clickable link — the URL must include a scheme |
| `\*`, `\[`, `\\`, `\|`, … | backslash escapes the next character |
| `\n` | line break — banners can span multiple lines (display capped at 10) |

Styles nest (`**bold with a [link](https://…)**`). Unterminated delimiters render literally.

**Tables** (standard markdown pipe syntax): a `| a | b |` header line immediately followed by a `|---|---|` separator with the same column count, then `| 1 | 2 |` body rows, render as an aligned grid with a bold header. Separator cells accept `:` alignment markers (`:---` left, `:---:` center, `---:` right). Cells support the full inline subset; `\|` puts a literal pipe inside a cell. Ragged rows are padded/truncated to the header width. The separator row doesn't render, but every other table row counts toward the 10-line cap.

```bash
ghoztty +set-banner --target=dev "**PR #123** — _3 files_, +120/−45 — [view](https://github.com/org/repo/pull/123)"
ghoztty +set-banner --target=dev "**Build status**\n| Job | State |\n|:---|---:|\n| lint | ok |\n| tests | **3 failed** |"
ghoztty +set-banner --target=dev --clear
```

Multi-line banners are **collapsible** in the UI: a chevron button (top-right) or a click anywhere on the banner background toggles between the full banner (default) and a collapsed single-line preview with a bottom fade. This is a display-only, per-pane UI state — it doesn't change the stored banner text, and there's no CLI flag for it.

Processes inside the pane can also set the banner without IPC via OSC escape sequence: `\033]7778;<text>\007` (empty text clears; note the OSC parser drops raw newlines, so OSC banners are single-line — use the CLI for tables/multi-line). Interactive users can press Cmd+R ("Set Pane Banner…", also in the command palette) for a multi-line editor (Return = newline, Cmd+Return = save).

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

### Pin a live status banner above your working pane

Post a PR link plus live stats above the pane you're working in, and keep it updated as work progresses. The banner is sticky — it stays put while the terminal scrolls underneath.

```bash
# When the PR is opened
ghoztty +set-banner --target=dev "**PR #123** — _draft_ — [view](https://github.com/org/repo/pull/123)"

# Update as work progresses (idempotent — just set it again)
ghoztty +set-banner --target=dev "**PR #123** — _3 files_, +120/−45 — CI __running__ — [view](https://github.com/org/repo/pull/123)"
ghoztty +set-banner --target=dev "**PR #123** — CI **green** — ready for review — [view](https://github.com/org/repo/pull/123)"

# Clear when done
ghoztty +set-banner --target=dev --clear
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
- **Don't `less`/`cat`/`open` a file to show it in a pane** — that dumps raw text (unrendered markdown) or opens an external app. Use `+split --view=<path>` for a rendered, live-reloading viewer pane.
- **Don't leave a design doc or mock HTML app preview-less** — when you author Markdown or scaffold an HTML prototype, auto-open it in a right-hand 2/3 viewer (see *Auto-preview conventions*). Markdown live-reloads; for an HTML app, serve it and `--view` the URL, then `+reload` the preview after edits (`--view` of an `.html` file shows source, not a live page).
