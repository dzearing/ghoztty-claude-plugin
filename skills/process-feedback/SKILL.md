---
name: process-feedback
description: Use when the user invokes /process-feedback to drain the Ghoztty viewer feedback queue - claim the oldest report folder in temp/feedback/new/, plan and investigate it, reproduce the problem, fix it (TDD where applicable), validate with a real build and test run, then move it to temp/feedback/complete/ and reset context to process the next one. Also use to resume an interrupted report already sitting in temp/feedback/in-progress/.
---

# Process Feedback

Drain the feedback queue that Ghoztty's viewer-pane feedback button produces,
one report at a time, in the current worktree.

Each pass handles **exactly one** report and then resets context, so every
report starts with a full context budget. The loop is:

```
claim oldest  →  plan  →  reproduce  →  fix (TDD)  →  validate  →  complete  →  /reset-context /process-feedback
```

## Queue layout

The producer (Ghoztty) only ever writes `new/`. This skill owns the rest.

```
<repo-root>/temp/feedback/
    .staging/            producer's scratch — NEVER read or claim from here
    new/                 unclaimed reports (producer writes here)
    in-progress/         claimed; at most one, and it is yours
    complete/            done and committed
    blocked/             needs the user; see blocked.md inside
```

A report folder is self-contained:

```
20260721T214512Z-a3f9c2/
    report.json
    images/image-1.png
```

**Reports are published atomically — do not sleep, poll, or debounce.**
`ViewerFeedbackReport.write` builds the whole folder under
`temp/feedback/.staging/<stem>` and publishes it with a single `rename(2)` onto
the same filesystem. A folder visible in `new/` is therefore complete by
construction, every image already on disk. There is no partially-populated
window to wait out and no separate "ready" directory is needed. Two cheap
guards cover everything else: ignore any entry whose name starts with `.`, and
require `report.json` to exist before claiming.

Folder names sort **lexically = chronologically** (`yyyyMMddTHHmmssZ-<hex>`), so
the oldest report is simply the first name in sorted order.

## Instructions

### Step 1: Locate the queue and check for an interrupted report

```bash
root=$(git rev-parse --show-toplevel) || exit 1
q="$root/temp/feedback"
mkdir -p "$q/new" "$q/in-progress" "$q/complete" "$q/blocked"
echo "QUEUE=$q"
echo "--- in-progress ---"; ls -1 "$q/in-progress" 2>/dev/null
echo "--- new ---";         ls -1 "$q/new" 2>/dev/null | grep -v '^\.' || true
```

Only this repo's queue is in scope — reports are filed into the worktree they
were attributed to, and the work belongs there.

- **Something in `in-progress/`** → you were interrupted (a context reset, a
  crash). Do NOT claim a new report. Read its `notes.md` (Step 4) and resume
  from the step it records.
- **`in-progress/` empty, `new/` non-empty** → go to Step 2.
- **Both empty** → go to Step 9 (wait).

If more than one folder is in `in-progress/`, stop and tell the user — that
means two agents are draining the same queue and they need to sort out which.

### Step 2: Claim the oldest report

Claiming is a single `rename`, so if another agent claimed it first the `mv`
fails and nothing is half-moved.

```bash
stem=""
for c in $(ls -1 "$q/new" 2>/dev/null | grep -v '^\.' | sort); do
  if [ -f "$q/new/$c/report.json" ]; then stem="$c"; break; fi
  echo "NO_REPORT_JSON: $c"
done
[ -n "$stem" ] || { echo "EMPTY"; exit 0; }
[ -e "$q/in-progress/$stem" ] && { echo "ALREADY_CLAIMED: $stem"; exit 1; }
mv "$q/new/$stem" "$q/in-progress/$stem" && echo "CLAIMED=$stem"
```

Selection walks the sorted list and takes the oldest folder that actually holds
a `report.json`, so one malformed entry cannot wedge the queue behind it.

- `NO_REPORT_JSON` lines → those folders were hand-copied in rather than filed
  by the app. Move each to `blocked/` with a `blocked.md` saying so. They are
  already skipped, so this does not block the claim.
- `ALREADY_CLAIMED` → Step 1 should have caught it; re-read `in-progress/`.
- The `mv` is the claim. If it fails, another agent won the race — re-run
  Step 1 rather than retrying the move.

Set the pane banner now so the user can see what is being worked (the banner
script ships with this plugin; skip this if it is not installed):

```bash
[ -x ~/.claude/scripts/ghoztty-banner.sh ] && \
  ~/.claude/scripts/ghoztty-banner.sh set --title 'process-feedback' \
    --goal '<one-line restatement of the report>' \
    --status 'Claimed <stem> — investigating'
```

### Step 3: Read the report — all of it

```bash
cat "$q/in-progress/$stem/report.json"
ls -1 "$q/in-progress/$stem/images" 2>/dev/null
```

Then **Read every image with the Read tool.** Screenshots are usually the whole
point of the report; a body that says "this is misaligned" is meaningless
without the picture.

Fields worth using rather than skimming:

| Field | Use |
| --- | --- |
| `body` | The user's message. Markdown; `![Image #N](images/image-N.png)` marks where each screenshot belongs, and `> …` blocks are page quotes. |
| `source.location` | Where they were — a file path or a URL. Reopen it. |
| `source.relativePath` | Repo-relative path of the viewed file — start here. |
| `source.selection` | What they had selected, i.e. what they were pointing at. |
| `source.pageTitle`, `source.viewport` | Which page, at what size (layout bugs). |
| `worktree.branch`, `worktree.commit` | The exact revision they saw. If HEAD has moved, check whether the problem still reproduces before fixing. |
| `quotes[]` | Per quote: `headingText`, `blockSelector`, `blockText`, and for file viewers a 1-based `sourceLine` into the source file. This is the precise anchor — use it instead of grepping for the passage. |
| `images[]` | Pixel dimensions; a 2x-scale screenshot's coordinates are half its pixel numbers. |

A quote's `sourceLine` may be `null` — that means the resolver could not find
the passage confidently, not that it is line 0. Fall back to searching.

### Step 4: Write the plan into the report folder

Create `in-progress/<stem>/notes.md` **before** touching code. This is the
resume point after a context reset — assume the next session knows nothing but
what this file says.

```markdown
# <stem>

**Ask:** <what the user actually wants, in one or two sentences>
**Where:** <file:line / URL the report points at>

## Plan
- [ ] Reproduce: <the exact command, file, or URL that shows the problem>
- [ ] <investigation step>
- [ ] <fix step>
- [ ] Validate: <build + test command>

## Log
- <timestamp> claimed
```

Keep the checklist current as you go — tick items and append to the Log after
each meaningful step. Break the work down further here if the report turns out
to contain several distinct asks; one report folder can produce several plan
items, but it stays one report.

Mirror the plan into your TodoWrite list too, so progress is visible live.

### Step 5: Reproduce before diagnosing

**Do not claim to understand the problem until you have seen it.** The report
is a user's description of a symptom; it may be a misunderstanding, a stale
build, an already-fixed bug, or something different from what it looks like.

- File viewer report → open that file, at that revision if HEAD moved.
- `localhost:PORT` report → confirm the dev server is actually running and
  serving that path before concluding anything about the code.
- UI/layout report → reproduce in the debug build (see the project's CLAUDE.md
  for how to build and launch it), or in an offscreen test harness where that
  is faster and more reliable than driving the GUI.

Record what you observed in the Log. If it does **not** reproduce, do not
"fix" it speculatively — go to Step 8 (blocked) and say exactly what you tried.

### Step 6: Fix, test-first where the defect is testable

If the defect can be expressed as a test — wrong value, wrong layout metric,
wrong parse, wrong file written — write the failing test first, watch it fail
for the right reason, then fix until it passes. That is what makes the fix
verifiable rather than plausible.

Where a test genuinely cannot express it (a visual judgement, a native
appearance), say so in `notes.md` and validate by observation instead, with the
evidence recorded.

Finish the whole change. No TODOs, no "follow-up needed", no partial
semantics left behind — if the report exposes an adjacent gap, fix it or write
it up in `notes.md` as a finding for the user, but do not leave a marker in the
code.

### Step 7: Validate for real

Run the project's actual build and test commands (from its CLAUDE.md — for
Ghoztty that is `zig build -Doptimize=Debug` plus the relevant Swift tests).

Validation means:
- the build succeeds,
- the new test passes and the surrounding suite still passes,
- the original reproduction no longer shows the problem.

Paste the outcome into `notes.md`. If tests fail, say so plainly — a failing
suite is never "done".

### Step 8: Complete, or block

**High confidence it is correct** — reproduced, fixed, tests green:

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix(<area>): <what changed, from the user's report>

Feedback report <stem>: <one-line paraphrase of the ask>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
mv "$q/in-progress/$stem" "$q/complete/$stem"
```

Commit but **never push and never merge** — `/wrapup` owns that. Committing
each report keeps `git log` a readable trail of what the queue produced and
leaves a clean tree for the next report's reproduction step. The queue itself
lives under gitignored `temp/`, so the report folders never enter a commit.

**Not confident** — could not reproduce, the ask is ambiguous, the fix needs a
product decision, or validation did not come out clean:

```bash
mv "$q/in-progress/$stem" "$q/blocked/$stem"
```

Write `blocked/<stem>/blocked.md` first: what you tried, what you observed, and
the specific question the user needs to answer. Then stop and tell the user —
do **not** reset context past a blocked report, since the answer has to come
from them. Leave any partial work uncommitted for them to look at.

### Step 9: Advance to the next report

After a **completed** report (only after Step 8's commit and move):

1. Update the banner with what landed (if the banner script is installed):
   `~/.claude/scripts/ghoztty-banner.sh set --status 'Completed <stem>' --did '<the actual fix>'`
2. Tell the user in one or two lines what the report asked and what changed.
3. Invoke the `/reset-context` skill via the Skill tool with the continuation
   text `/process-feedback`. That clears this session and re-enters this skill with
   a fresh context, which claims the next report.

Do not skip the reset and loop in-place — the whole point is that report N+1
does not inherit report N's context.

### Step 10: Empty queue — wait for one to arrive

When `new/` and `in-progress/` are both empty, arm a single background watcher
rather than polling in the conversation. It exits the moment a complete report
folder appears, which re-invokes you:

```bash
q="$(git rev-parse --show-toplevel)/temp/feedback"
for _ in $(seq 600); do
  found=$(find "$q/new" -mindepth 1 -maxdepth 1 -type d -not -name '.*' \
            -exec test -f {}/report.json \; -print -quit 2>/dev/null)
  [ -n "$found" ] && { echo "REPORT: $found"; exit 0; }
  sleep 5
done
echo "TIMEOUT"
```

Run it with `run_in_background: true`. The `-exec test -f {}/report.json`
guard means it only fires on a folder that really is a report.

- Tell the user the queue is empty and that you are watching it, then end the
  turn.
- On `REPORT:` → go to Step 1 and process it.
- On `TIMEOUT` (50 minutes of quiet) → re-arm the same watcher once, and if
  the second window also times out, tell the user you have stopped watching.
