# ghoztty-claude-plugin

A [Claude Code](https://claude.com/claude-code) plugin that teaches Claude how to drive [Ghoztty](https://github.com/dzearing/ghoztty) — a fork of Ghostty with CLI-driven window management over a Unix domain socket.

With this skill installed, Claude Code can:

- Open named terminal windows and split-pane layouts
- List open windows, tabs, and panes (human-readable or JSON)
- Read terminal output from any named pane
- Send keystrokes and control sequences to running processes
- Rearrange split layouts declaratively while preserving terminal state
- Rename windows and track activity state (`idle` / `busy` / `needs_input`)
- Keep a live per-pane **status banner** for the session (see below)
- Work through feedback you file from a viewer pane, with **`/process-feedback`** (see below)

## Status banner

The plugin ships hooks that maintain a sticky banner above the active pane,
so you can see at a glance what the session is doing:

- **Title** (an `#### ` heading, rendered slightly larger), then a key/value
  table of **Goal**, **Status**, **You asked**, **What I did**, and a clickable
  **PR** link.
- Claude keeps the banner current by calling `~/.claude/scripts/ghoztty-banner.sh`
  (symlinked from the plugin on session start). "You asked" / "What I did" are
  short paraphrases, auto-seeded from the prompt and last tool action.
- Stale content is pruned automatically: a new ask clears the previous "What I
  did", switching tasks drops the old PR link, and a PR that has been
  closed/merged is removed on the next idle (best-effort, via `gh`).

The banner requires a Ghoztty build with banner support (`+set-banner`, markdown
tables, and headings); on older builds the hooks silently no-op.

## `/process-feedback`

Ghoztty's viewer panes have a feedback button that files a report — your
message, any screenshots, and the passages you quoted — into
`<worktree>/temp/feedback/new/` as one self-contained folder.

`/process-feedback` is the other half: it drains that queue in the current
worktree, **one report per context**, so a long backlog never runs out of room
to think.

```
claim oldest  →  plan  →  reproduce  →  fix (TDD)  →  validate  →  commit  →  reset context  →  next
```

- Reports move `new/` → `in-progress/` → `complete/`, one `mv` per transition.
  Anything it can't finish confidently goes to `blocked/` with a written
  question for you, rather than a guessed fix.
- It reproduces before diagnosing, and drives testable defects with a failing
  test first.
- Progress lives in `in-progress/<report>/notes.md`, so a context reset mid-report
  resumes instead of restarting.
- It commits each completed report; it never pushes or merges.
- An empty queue arms a watcher and picks up the next report as it lands.

The queue sits under `temp/`, which is gitignored by convention, so filed
reports never show up in `git status`.

## Prerequisites

Install [Ghoztty](https://github.com/dzearing/ghoztty/releases) and make sure the `ghoztty` binary is on your `PATH`.

## Installation

In Claude Code:

```
/plugin marketplace add dzearing/ghoztty-claude-plugin
/plugin install ghoztty@ghoztty-claude-plugin
```

## Usage

Once installed, the skill activates automatically whenever you ask Claude Code to work with terminal windows, e.g.:

- "Open a terminal in this repo and run the dev server"
- "Split the window and tail the logs in the right pane"
- "What's running in my terminal windows?"
- "Send Ctrl-C to the build pane"

## License

MIT
