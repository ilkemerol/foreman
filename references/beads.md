# Beads (bd) tracking for foreman

Read by the master at `SKILL.md` *Tracking with beads*, before deciding to
track, installing bd or running any `bd` command. Only the master runs `bd`.

## When to track

**When:** only if the task will span sessions or the user asks; within one
session the board and the called skill's own ledger are enough. It needs a
plan folder: the folder the called skill saves its plan in, or the folder of a
plan written during this task. No plan folder means no tracking. Never write
to a repo's own `.beads/`: it is the project's tracker.

**bd missing** (`command -v bd` fails): tell the user tracking needs beads
(`bd`), which is not installed, and ask whether to install it. On no, or if
the install fails, don't track: the board covers this session; say so once.

## Install (only after the user said yes)

Install with the official method for the platform, then check `bd version`
(tested with bd 1.2.2):
- Windows: `powershell -NoProfile -Command "irm https://raw.githubusercontent.com/gastownhall/beads/main/install.ps1 | iex"`
- macOS / Linux: `brew install beads` if Homebrew exists, otherwise
  `curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash`
- if the user prefers npm: `npm install -g @beads/bd`

## Workspace and commands

**Setup.** `bd init` always wants a git repo: in a folder outside git it
creates an empty `.git/` there, and inside a repo it commits its files into
that repo or rewrites its excludes. So the workspace `d` is the plan folder
only when that folder is not inside a git repo; otherwise it is a folder
foreman owns, named after the plan folder. The flags keep bd from writing
agent files (`AGENTS.md`, `CLAUDE.md`, `.claude/`), installing git hooks,
committing, or prompting:

```bash
p="<plan folder>"
if [ -d "$p/.beads" ] || ! git -C "$p" rev-parse --show-toplevel >/dev/null 2>&1; then
  d="$p"
else
  d="$HOME/.claude/foreman/beads/$(basename "$p")"; mkdir -p "$d"
fi
[ -d "$d/.beads" ] || (cd "$d" && bd init --non-interactive --stealth --skip-agents --skip-hooks --role maintainer -q && git config beads.role maintainer)
```

`d` follows from the plan folder, so it can be recomputed after a compaction.
**Every** `bd` call pins the workspace, so bd never walks up to another
`.beads/`: `BEADS_DIR="$d/.beads" bd -C "$d" ...`. Only you run `bd`. A
`beads.role not configured` warning on stderr is harmless.

| Moment | Command (each as `BEADS_DIR="$d/.beads" bd -C "$d" ...`) |
|--------|---------|
| Tracking starts | `bd q "<task>" -t epic` |
| Each piece | `bd create "<piece>" --parent <epic> --silent`; dependency: `bd dep add <piece> <needed-piece>` |
| Right after the Agent call returns | `bd update <id> --claim` and `bd comments add <id> "agent=<agentId> worktree=<path or none>"` |
| `needs-agent` / `needs-info` | `bd comments add <id> "<what was requested>"` (stays in_progress) |
| `blocked` / `needs-decision` | `bd update <id> -s blocked` and `bd comments add <id> "<why>"` |
| Verified `done` | `bd close <id> --reason "<one-line result>"` |
| What to spawn next | `bd ready` |
| Reconcile (`SKILL.md` *Agent board*) | `bd list -s in_progress` alongside the board |

bd writes straight to its database; there is nothing to sync or commit.
