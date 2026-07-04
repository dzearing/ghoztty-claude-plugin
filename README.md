# ghoztty-skill

A [Claude Code](https://claude.com/claude-code) plugin that teaches Claude how to drive [Ghoztty](https://github.com/dzearing/ghoztty) — a fork of Ghostty with CLI-driven window management over a Unix domain socket.

With this skill installed, Claude Code can:

- Open named terminal windows and split-pane layouts
- List open windows, tabs, and panes (human-readable or JSON)
- Read terminal output from any named pane
- Send keystrokes and control sequences to running processes
- Rearrange split layouts declaratively while preserving terminal state
- Rename windows and track activity state (`idle` / `busy` / `needs_input`)

## Prerequisites

Install [Ghoztty](https://github.com/dzearing/ghoztty/releases) and make sure the `ghoztty` binary is on your `PATH`.

## Installation

In Claude Code:

```
/plugin marketplace add dzearing/ghoztty-skill
/plugin install ghoztty@ghoztty-skill
```

## Usage

Once installed, the skill activates automatically whenever you ask Claude Code to work with terminal windows, e.g.:

- "Open a terminal in this repo and run the dev server"
- "Split the window and tail the logs in the right pane"
- "What's running in my terminal windows?"
- "Send Ctrl-C to the build pane"

## License

MIT
