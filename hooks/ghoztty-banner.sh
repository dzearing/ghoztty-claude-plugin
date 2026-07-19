#!/bin/bash
# ghoztty-banner.sh — keep a Ghoztty pane banner current for a Claude Code session.
#
# Banner layout: the title as an `## ` h2 heading on its own line (larger than
# the body text), then a key/value table (empty header row so the label column
# stays narrow), then the "Last result" block and PR link below it:
#   ## <title>
#   |  |  |
#   |---|---|
#   | **Goal** | <goal> |
#   | **Bugs fixed** | <bug links> |   # only when the task is a bug fix
#   | **Prompt** | <asked> |
#   | **Status** | <status> · <activity> |
#   **Last result**
#   <did>                     # plain-language summary; may be a multi-line
#                             # checklist ("- [x] item" per line) that a table
#                             # cell can't hold, so it lives below the table
#   **PR** [<url>](<url>)
#
# "Prompt"/"Last result" are model-provided paraphrases (set --asked/--did):
# "Prompt" is a plain-language paraphrase of the user's prompt (not a verbatim
# quote) and is auto-seeded from the raw prompt as a fallback; "Last result"
# names only the actual code fixes/features that landed this turn and is set
# ONLY by the model's explicit --did (never auto-seeded from tool calls, which
# are steps, not results). "Bugs fixed" (--bugs) is set only when the prompt is
# fixing a specific bug, and holds clickable markdown link(s) to the bug(s). The
# PR is a clickable markdown link. Fields persist in a per-tty state file, so
# each call only passes what changed.
# Delivery: ghoztty +set-banner CLI (multi-line + tables) targeting the
# cached/resolved pane name; falls back to a single-line OSC 7778 write to the
# tty device when the pane can't be resolved (the OSC parser drops newlines, so
# the table/multi-line form is CLI-only).
#
# Usage:
#   ghoztty-banner.sh set [--title T] [--goal G] [--status S] [--asked A] [--did D] [--pr URL]
#   ghoztty-banner.sh status <text>     # shorthand for set --status
#   ghoztty-banner.sh activity <text>   # hook-owned suffix (working/idle)
#   ghoztty-banner.sh prompt-hook       # UserPromptSubmit: activity=working + context JSON
#   ghoztty-banner.sh session-start-hook # SessionStart(startup|clear): wipe + clear banner
#   ghoztty-banner.sh stop-hook         # Stop: activity=idle
#   ghoztty-banner.sh clear
#
# Silently no-ops when not running inside Ghoztty.

set -u

[ "${TERM_PROGRAM:-}" = "ghostty" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

STATE_DIR="$HOME/.claude/ghoztty-banner"
mkdir -p "$STATE_DIR"

# Walk up the process tree until we find an ancestor with a controlling tty.
# (The hook shell and the Bash-tool shell have no tty; the claude process does.)
find_tty() {
    local pid=$$ t
    while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; do
        t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -n "$t" ] && [ "$t" != "??" ]; then
            echo "$t"
            return 0
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
    return 1
}

TTY_NAME=$(find_tty) || exit 0
STATE_FILE="$STATE_DIR/$TTY_NAME.json"

read_field() { # field
    [ -f "$STATE_FILE" ] && jq -r --arg k "$1" '.[$k] // empty' "$STATE_FILE" 2>/dev/null
}

# Merge key/value pairs into the state file with a single jq call.
jq_merge() { # k1 v1 [k2 v2 ...]
    local cur='{}'
    [ -f "$STATE_FILE" ] && cur=$(cat "$STATE_FILE" 2>/dev/null) && [ -n "$cur" ] || cur='{}'
    local prog='.' i=0 jqargs=()
    while [ $# -ge 2 ]; do
        i=$((i + 1))
        prog="$prog | .[\$k$i] = \$v$i"
        jqargs+=(--arg "k$i" "$1" --arg "v$i" "$2")
        shift 2
    done
    echo "$cur" | jq "${jqargs[@]}" "$prog" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# Strip control characters that would corrupt an OSC sequence or IPC payload.
sanitize() {
    printf '%s' "$1" | tr -d '\000-\037' | tr -d '\177'
}

# Escape unescaped pipes so a value can't break out of its table cell.
esc_cell() {
    printf '%s' "$1" | sed 's/|/\\|/g'
}

# Render a PR URL as a clickable markdown link whose visible text is the URL.
pr_link() {
    printf '[%s](%s)' "$1" "$1"
}

send_osc() { # single-line text
    printf '\033]7778;%s\007' "$1" > "/dev/$TTY_NAME" 2>/dev/null
}

# Resolve this tty to a registered pane name. Order: cached name (validated
# against the live pane list), then +list --tty (works for non-persistence
# panes; session-persistence panes report an empty tty until the
# Remote.zig getProcessInfo TODO is fixed). Caches on success.
resolve_pane() {
    command -v ghoztty >/dev/null 2>&1 || return 1
    local cached pane list
    cached=$(read_field pane)
    list=$(ghoztty +list --json 2>/dev/null) || return 1
    if [ -n "$cached" ] && echo "$list" | jq -e --arg n "$cached" \
        'any(.. | objects; .name? == $n)' >/dev/null 2>&1; then
        echo "$cached"
        return 0
    fi
    pane=$(ghoztty +list --tty="$TTY_NAME" 2>/dev/null) && [ -n "$pane" ] || return 1
    jq_merge pane "$pane"
    echo "$pane"
}

render() {
    local title goal status activity asked did pr bugs
    title=$(read_field title)
    goal=$(read_field goal)
    status=$(read_field status)
    activity=$(read_field activity)
    asked=$(read_field asked)
    did=$(read_field did)
    pr=$(read_field pr)
    bugs=$(read_field bugs)

    # Nothing meaningful set yet (only activity): don't paint a banner.
    if [ -z "$title$goal$status$asked$did$pr$bugs" ]; then
        return 0
    fi

    # Display the activity sentence-cased ("Working"/"Idle") regardless of the
    # lowercase token stored in the state file.
    local statline="$status"
    if [ -n "$activity" ]; then
        local act_disp="$(printf '%s' "${activity:0:1}" | tr '[:lower:]' '[:upper:]')${activity:1}"
        [ -n "$statline" ] && statline="$statline · $act_disp" || statline="$act_disp"
    fi

    local pane
    if pane=$(resolve_pane) && [ -n "$pane" ]; then
        # CLI path ("\n" converted to newlines by the IPC server): the title
        # is the table's bold header cell so its divider sits flush beneath
        # it — no blank header row, no paragraph gap.
        local rows=""
        add_row() { # label value
            [ -n "$2" ] || return 0
            rows="$rows\n| **$1** | $(esc_cell "$2") |"
        }
        add_row "Goal" "$goal"
        add_row "Bugs fixed" "$bugs"
        add_row "Prompt" "$asked"
        add_row "Status" "$statline"

        # Title as an `## ` h2 heading on its own line above the table, so it
        # reads larger than the body. The table keeps an empty header row so
        # its label column stays as narrow as the labels.
        local text=""
        [ -n "$title" ] && text="## $title"
        if [ -n "$rows" ]; then
            [ -n "$text" ] && text="$text\n"
            text="$text|  |  |\n|---|---|$rows"
        fi
        # "Last result" lives below the table as its own block: it may be a
        # multi-line checklist/bullet list (items joined with \n by the model),
        # which a single-line table cell can't hold. Passed raw so its own \n
        # line breaks survive to the renderer.
        if [ -n "$did" ]; then
            [ -n "$text" ] && text="$text\n"
            text="$text**Last result**\n$did"
        fi
        if [ -n "$pr" ]; then
            [ -n "$text" ] && text="$text\n"
            text="$text**PR** $(pr_link "$pr")"
        fi
        ghoztty +set-banner --target="$pane" "$text" >/dev/null 2>&1 && return 0
    fi

    # OSC fallback: single line (no newlines/tables), bold title + labels.
    local line="" sep=" · "
    [ -n "$title" ] && line="**$title**"
    add_seg() { # label value
        [ -n "$2" ] || return 0
        [ -n "$line" ] && line="$line$sep"
        line="$line**$1:** $2"
    }
    add_seg "Goal" "$goal"
    add_seg "Bugs fixed" "$bugs"
    add_seg "Prompt" "$asked"
    add_seg "Status" "$statline"
    add_seg "Last result" "$did"
    [ -n "$pr" ] && { [ -n "$line" ] && line="$line$sep"; line="$line**PR:** $(pr_link "$pr")"; }
    send_osc "$line"
}

cmd="${1:-}"
shift 2>/dev/null || true

case "$cmd" in
set)
    pairs=()
    newtitle=""; newtitle_set=0; pr_set=0; did_set=0; bugs_set=0
    while [ $# -gt 0 ]; do
        case "$1" in
        --title)  newtitle=$(sanitize "${2:-}"); newtitle_set=1; pairs+=(title "$newtitle"); shift 2 ;;
        --goal)   pairs+=(goal "$(sanitize "${2:-}")"); shift 2 ;;
        --status) pairs+=(status "$(sanitize "${2:-}")"); shift 2 ;;
        --asked)  pairs+=(asked "$(sanitize "${2:-}")"); shift 2 ;;
        --did)    did_set=1; pairs+=(did "$(sanitize "${2:-}")"); shift 2 ;;
        --bugs)   bugs_set=1; pairs+=(bugs "$(sanitize "${2:-}")"); shift 2 ;;
        --pr)     pr_set=1; pairs+=(pr "$(sanitize "${2:-}")"); shift 2 ;;
        --title=*)  newtitle=$(sanitize "${1#*=}"); newtitle_set=1; pairs+=(title "$newtitle"); shift ;;
        --goal=*)   pairs+=(goal "$(sanitize "${1#*=}")"); shift ;;
        --status=*) pairs+=(status "$(sanitize "${1#*=}")"); shift ;;
        --asked=*)  pairs+=(asked "$(sanitize "${1#*=}")"); shift ;;
        --did=*)    did_set=1; pairs+=(did "$(sanitize "${1#*=}")"); shift ;;
        --bugs=*)   bugs_set=1; pairs+=(bugs "$(sanitize "${1#*=}")"); shift ;;
        --pr=*)     pr_set=1; pairs+=(pr "$(sanitize "${1#*=}")"); shift ;;
        *) shift ;;
        esac
    done
    # A changed title means a new task: drop fields that would otherwise
    # linger from the previous one (a stale PR link, the old "Last result", a
    # prior bug reference), but never clobber a value passed explicitly in this
    # same call.
    if [ "$newtitle_set" = 1 ] && [ "$newtitle" != "$(read_field title)" ]; then
        [ "$pr_set" = 1 ]   || pairs+=(pr "")
        [ "$did_set" = 1 ]  || pairs+=(did "")
        [ "$bugs_set" = 1 ] || pairs+=(bugs "")
    fi
    [ ${#pairs[@]} -gt 0 ] && jq_merge "${pairs[@]}"
    render
    ;;
status)
    jq_merge status "$(sanitize "${1:-}")"
    render
    ;;
activity)
    jq_merge activity "$(sanitize "${1:-}")"
    render
    ;;
prompt-hook)
    # Seed "You asked" with the raw prompt (first line, truncated) as a
    # default the model refines into a paraphrase during the turn.
    input=$(cat)
    asked=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null | head -n1)
    asked=$(sanitize "$asked")
    [ ${#asked} -gt 100 ] && asked="${asked:0:97}..."

    # A new ask starts fresh: clear "What I did" so the previous turn's work
    # isn't shown until something new actually happens this turn.
    pairs=(activity "working" did "")
    [ -n "$asked" ] && pairs+=(asked "$asked")

    # The state file is keyed by tty, so a fresh Claude session starting in a
    # pane inherits the PREVIOUS session's task fields (title/goal/status/pr).
    # Detect a new session by its id and wipe the stale task identity, so a
    # fresh context begins with a blank banner instead of another session's
    # task. A resumed session keeps its id, so its banner is preserved.
    session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
    if [ -n "$session" ] && [ "$session" != "$(read_field session)" ]; then
        pairs+=(session "$session" title "" goal "" status "" pr "" bugs "" last "")
    fi

    jq_merge "${pairs[@]}"
    render
    cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"This session runs in a Ghoztty pane with a persistent status banner. Keep it current: run `~/.claude/scripts/ghoztty-banner.sh set --title '<short task title>' --goal '<current goal>' --status '<one-line progress note>' [--asked '<plain-language paraphrase of the user's last prompt, NOT a verbatim quote>'] [--did '<the actual code fix/feature that landed>'] [--bugs '<markdown link(s) to the bug(s) being fixed>'] [--pr <url>]` when a task starts, whenever the goal/status meaningfully changes, and when a PR is created. --asked shows as 'Prompt' and --did as 'Last result'; keep both as short human-readable paraphrases (never raw tool names or quotes). IMPORTANT: --did is for ACTUAL fixes/features applied to the code, set it only once real changes have landed — never for exploration, reads, or intermediate tool calls (those are steps, not results); leave it alone until then. When more than one fix landed, pass a checklist with one item per line using \\n, e.g. --did '- [x] Renamed Last prompt to Prompt\\n- [x] Stopped auto-seeding Last result from tool calls'. When the prompt is fixing a specific bug (an issue link, a bug id, or a clearly identified defect), set --bugs to a clickable markdown link to it, e.g. --bugs '[#123](https://github.com/org/repo/issues/123)' (comma-separate multiple); it shows as a 'Bugs fixed' row under Goal. Omit --bugs entirely when the task is not a bug fix. Fields persist between calls, so pass only what changed."}}
EOF
    ;;
session-start-hook)
    # Fires on SessionStart. `/clear` (source=clear) and a fresh launch
    # (source=startup) begin a new task in this pane, so wipe the previous
    # session's task identity AND clear the on-screen banner immediately —
    # don't wait for the next prompt to blank stale data. `resume`/`compact`
    # continue the same task, so their banners are left untouched (this hook
    # is registered with a `startup|clear` matcher, so it isn't called then).
    input=$(cat)
    session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
    pane=$(resolve_pane)
    [ -n "$pane" ] && ghoztty +set-banner --target="$pane" --clear >/dev/null 2>&1
    # Reset task fields but keep the resolved pane cache; record the new id so
    # the prompt-hook doesn't re-wipe on this session's first prompt.
    pairs=(title "" goal "" status "" asked "" did "" pr "" bugs "" last "" activity "")
    [ -n "$session" ] && pairs+=(session "$session")
    jq_merge "${pairs[@]}"
    ;;
stop-hook)
    jq_merge activity "idle"
    render
    # Best-effort: drop a PR link once it's no longer open (closed/merged),
    # so the banner never shows a stale PR. GitHub + gh only; silent on any
    # failure (no gh, not authed, non-GitHub host, network error).
    pr=$(read_field pr)
    if [ -n "$pr" ] && command -v gh >/dev/null 2>&1; then
        case "$pr" in
        *github.com*)
            state=$(gh pr view "$pr" --json state -q .state 2>/dev/null)
            if [ -n "$state" ] && [ "$state" != "OPEN" ]; then
                jq_merge pr ""
                render
            fi
            ;;
        esac
    fi
    ;;
clear)
    pane=$(resolve_pane)
    rm -f "$STATE_FILE"
    [ -n "$pane" ] && ghoztty +set-banner --target="$pane" --clear >/dev/null 2>&1
    send_osc ""
    ;;
*)
    echo "usage: ghoztty-banner.sh set|status|activity|prompt-hook|session-start-hook|stop-hook|clear" >&2
    exit 2
    ;;
esac
exit 0
