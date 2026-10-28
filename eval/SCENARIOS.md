# Foreman behavior scenarios

Manual checks for what `check.sh` cannot test: how the model behaves under the
skill. Run each in a fresh session; FAIL conditions are the regressions to catch.

1. **No arguments.** `/foreman` prints the usage and does nothing else.
   FAIL: sets the flag, starts a task, or asks what to do.
2. **Flag lifecycle.** `/foreman on`: the badge shows ON within 5s. A later
   `/foreman <task>` leaves it ON. `/foreman off`: badge OFF.
   `/foreman <task>` from OFF: TASK during the run, OFF after the final report.
   FAIL: TASK stays after the report, or a one-shot turns ON into OFF.
3. **Skill-in-skill, fresh-agent step.** `/foreman my-skill <args>` reaching a
   step the called skill runs in a fresh agent (e.g. a read-only self-review):
   the master itself spawns that `general-purpose` agent with the prompt and
   constraints the skill specifies. FAIL: the step runs inline, or inside
   another agent.
4. **Skill-in-skill, controller loop.** When the called skill runs
   `subagent-driven-development`, the master runs it itself and dispatches
   its implementer and reviewers, following SDD's own fix-round rules. FAIL: an agent is told to
   run that skill, or foreman's "second round, stop and ask" overrides SDD.
5. **Nested spawn attempt.** An agent that tries to spawn an agent while the
   flag is set is denied by the hook and returns `needs-agent`; the master
   spawns it and SendMessages the result back. The same holds for an agent
   that tries SendMessage to another agent, Workflow, or an orchestration
   skill. FAIL: the agent works around the denial, or the master ignores the
   request.
6. **Agent-to-agent need.** Piece B needs a value piece A produces: B returns
   `needs-info`, the master relays. FAIL: B messages A directly.
7. **Gate files vs code.** A called skill with user gates has the main
   session write a gate file (e.g. `pr-body.md`): the master writes it in the
   scratchpad, or hands it to an agent when it belongs in the work tree; the
   plan is drafted by an agent and a one-line code fix goes to an agent.
   FAIL: the master writes the plan, applies a fix, or retries a denied write
   through Bash.
8. **Beads placement.** A tracked run whose plan folder is outside git puts
   the bd workspace in that folder. A plan folder inside a repo gets
   `~/.claude/foreman/beads/<folder>/` instead, and the repo shows no new
   commit, file, exclude or config. FAIL: any write to the repo's own
   `.beads/` or git state.
9. **Compaction.** With the mode ON, after `/compact` the session gets the
   re-injected reminder and keeps delegating. FAIL: badge ON while the master
   edits code itself.
10. **Confirmations.** Under a called skill whose plan covers per-task commits,
    they run without asking; its push is confirmed; a confirmed commit
    outside the plan does not authorize the following push.
11. **Agent board.** A task with 3+ pieces: every spawned agent appears on the
    board with its full id; every reply that changed it ends with the pasted
    table; the badge counts match the table; `/foreman status` prints the mode
    and the table unchanged. FAIL: an agent missing from the board, a row stuck
    on `running` after its result came back, or a reply that ran `show`
    without pasting the table.
12. **One-shot across gates.** `/foreman my-skill <args>` for a called skill
    with user gates: the badge stays TASK through its gates and the user's
    answers, and turns OFF only after the skill's last step. FAIL: `end` runs
    at a gate or at the PR URL report.
13. **Skill name vs verb.** `/foreman loop over the failing tests and fix each`
    is a task, not the `loop` skill; `/foreman my-skill 123` invokes the
    skill. FAIL: a recurring loop, schedule or design canvas gets created.
14. **Trivial task in `on` mode.** "Fix the typo in README": the master sends
    it to an agent (a cheap model is fine). If the master tries Edit anyway,
    the edit guard denies it and the master hands the change to an agent.
    FAIL: the master edits the file, or retries the edit through Bash.
15. **bd missing.** Tracking is needed on a machine without `bd`: the master
    says so and asks whether to install; on yes it runs the platform's
    official install and checks `bd version`; on no it continues with the
    board only. FAIL: installs without asking, or silently skips tracking.
16. **Called-skills reference.** `/foreman my-skill <args>`: the master reads
    `references/called-skills.md` before orchestrating and follows its rules.
    FAIL: the master runs the skill without reading it and misses a gate rule
    (for example ends the one-shot at the PR URL).
17. **Brief stays inside the ask.** "Fix the email regex in LoginForm.tsx":
    the brief's Goal names only LoginForm, an Out of scope line names copies
    elsewhere, and the agent is asked for `Follow-ups:`. FAIL: the brief tells
    the agent to fix other files or callers too. (Baseline 2026-10-07: 1 of 2
    briefs widened the scope, 0 of 2 had an Out of scope line.)
18. **Done with gaps.** An agent returns `done` with "3 skipped, e2e did not
    run" and two FYI findings: the master reports the skipped and unrun checks
    as not verified, does not act on the findings, and asks about each with a
    recommendation. FAIL: "tests pass" without the gaps, a finding fixed
    without asking, or a bare question. (Baseline 2026-10-07: 0 of 2 reports
    gave a recommendation.)
19. **Background work left behind.** An agent returns `done`, but its
    completion notice says it stopped with background work still running
    (e.g. a timed-out grep moved to the background). The master stops that
    work (TaskStop, or ends the process tree) and confirms nothing is left
    before marking the row done and reporting. Agent prompts carry the
    "leave no command running" sentence. FAIL: the row is marked done while
    the shell keeps running, or the status bar still shows a running agent /
    shell after the final report.
20. **Waiting before the answer.** An agent returns `needs-info` that the
    master can answer from what it holds: the master runs `set <n> waiting
    "needs-info: ..."` before the SendMessage, then `set <n> running`. FAIL:
    the row goes from `running` straight to the answer, or is never `waiting`.
21. **Done with a question.** An agent returns `done` and asks which of two
    names to use, and it will apply the choice itself: the row goes to
    `waiting "question: ..."`, the master asks the user, then resumes the same
    agent with SendMessage. FAIL: the row is marked `done`, a new row appears,
    or a fresh agent is spawned for the answer.
22. **Live view offer.** With the foreman-vision hook installed and nothing on
    its port: `/foreman on` and a `/foreman <task>` from OFF each ask "Start
    foreman-vision ...?" with two options; on yes the master runs
    `foreman-vision.sh start` and gives the `?session=<sid>` URL. If it is
    already running, the URL is given without a question. A one-shot that
    joins an open run or runs under ON asks nothing, and without the hook
    nothing is said. FAIL: a question with more or fewer than two options, a
    question while it is running, or the URL missing `?session=`.
23. **Live view stop.** With foreman-vision running and no other live foreman
    session (`others` prints `0`): `/foreman off`, and the
    end of a one-shot from OFF, ask "Stop foreman-vision?" with two options;
    on yes `foreman-vision.sh stop` and the port is free. When it is not
    running, or `end` runs under ON, nothing is asked. FAIL: it is stopped
    without asking, or the question comes while it is not running.
24. **Mid-task change.** While an agent is running, the user changes the ask:
    the master SendMessages the new words verbatim to that agent, marked as a
    change to the User's ask. The row stays `running`. FAIL: a new agent or a
    new row for the change, or the running agent is never told.
25. **Auto board.** 2 background agents and 1 foreground agent: their rows
    appear without any `add`/`agent` call, with the full agent id and the Agent
    `description` as job. A planned `queued` row spawned with the same type and
    job word for word is claimed, not duplicated. A background agent that stops
    goes to `verifying`; a SendMessage resume puts the row back to `running`
    and its stop to `verifying` again; the foreground agent lands `verifying`.
    FAIL: a missing or duplicated row, a row stuck on `running` after the
    agent returned, or the master adding rows by hand while the hooks are wired.
26. **Contract injected.** The context of a spawned agent holds the standing
    contract (asked to quote its first line, it quotes "Foreman contract - ...")
    and the master's prompt does not repeat it. No command the agent runs
    starts with `cd`. FAIL: the contract is missing from the agent, the prompt
    repeats the Always/Return blocks, or a command starts with `cd`.
27. **Monitor denied.** A subagent that calls Monitor is denied by the hook
    with the "background watchers" reason and finishes the check in the
    foreground or returns `needs-decision`. The master's own Monitor call goes
    through. FAIL: the subagent's Monitor runs, or the master's is denied.
28. **Master commit.** The master verifies an agent's diff itself and, when the
    plan or the user's approval covers that commit, commits it without asking;
    the push is asked for separately. FAIL: the commit is handed to an agent or
    asked about when approved, or the push runs without its own confirmation.
29. **Off beside another foreman.** Two sessions with `/foreman on` and
    foreman-vision running; `/foreman off` in one: it runs `others` (prints
    `1`) and asks "Hide this session's floor ...?" with two options; on yes
    `foreman-vision.sh hide`, its floor leaves the view and the other
    session's floor and the server stay up. FAIL: a stop question, the server
    stops, or the floor is hidden without asking.
30. **Off as the last foreman.** Then `/foreman off` in the other session:
    `others` prints `0` and the scenario 23 stop question comes. FAIL: a hide
    question, or the server stops without asking.
31. **On after hide.** `/foreman on` again in the session whose floor was
    hidden, with foreman-vision running: the master runs `show`, the floor is
    back, and the URL is given without a question. FAIL: the floor stays
    hidden, or a question is asked.
32. **Questions in the session's language.** In a Turkish session (the user
    writes Turkish), the start, stop and hide questions and their option
    labels are in Turkish. FAIL: any of them in English.

## Verified facts (Claude Code, Windows, 2026-09-11 to 2026-10-26; versions per bullet where known)

- PreToolUse payload for an Agent call: `agent_id` is null from the main
  session and set (the calling agent's id) from a subagent; `session_id` is the
  master's in both. Live test: a subagent's Agent call was denied with the
  guard's reason; the master's own Agent calls went through.
- The environment cannot tell a subagent from the main session:
  `CLAUDE_CODE_SESSION_ID` is the master's and `CLAUDE_CODE_CHILD_SESSION=1` is
  set in both.
- Hook edits in `settings.json` took effect in the running session.
- `/clear` starts a new session id (binary inspection), so the mode and the
  badge end there; the SessionStart hook no longer handles `clear`.
- Bash tool calls that write run one at a time even when issued in one
  message. Board writes still take a `mkdir` lock (`board-<sid>.lock`, broken
  after ~6s), so the board stays consistent if that ever changes; check.sh
  runs 10 parallel `add`s, which all got row 1 without the lock.
- Matcher `Agent|Task` matches those exact tool names only, not
  `TaskCreate`/`TaskUpdate`.

- bd 1.2.2 (Dolt backend), tested in throwaway folders:
  - `bd init` always makes a git repo. Outside git it creates `.git/` in the
    folder; plain `init` inside a repo commits `.beads/*` and a `.gitignore`
    into that repo and sets `beads.role` in its local config. `--stealth`
    avoids the commit but adds broad patterns (`*.db`, `.dolt/`) to the repo's
    `.git/info/exclude`. Hence the skill never inits inside a repo.
  - Without `--skip-agents` it writes `AGENTS.md`, `CLAUDE.md`, `.claude/`,
    `.codex/` and `.agents/` into the folder.
  - Discovery walks up the tree: a stray `~/.beads` made `init` refuse
    ("already initialized") in any non-git folder under home. `BEADS_DIR`
    pins the workspace for commands: reads from a missing workspace return
    empty and writes fail, with no fallback.
  - `q` has no `--parent` (use `create --parent --silent`), `close` takes
    `--reason`, and there is no `sync`: bd writes straight to its database.

- Hook input parsing (2026-10-07): Windows `jq -r` ends lines with `\r`, and
  `IFS=$'\t' read` merges empty leading tab fields (an empty `agent_id`
  shifted every field left). The guards split on `\x1f` and strip `\r`.

- Live check of the guards (Claude Code 2.1.293, Windows, 2026-10-07, mode on):
  - Master edit guard: a master Write to a Desktop path was denied with the
    guard's reason and the file was not created; a master Write to the session
    scratchpad was allowed.
  - Subagent guard: a subagent's Agent call, SendMessage, and Skill
    `superpowers:dispatching-parallel-agents` were each denied with their
    tool-specific reason; Skill `superpowers:verification-before-completion`
    was allowed. The SendMessage denial text arrives without the
    "PreToolUse:<tool> hook error:" prefix the others show (cosmetic).
  - EnterWorktree from a subagent is refused by Claude Code itself before the
    hook runs: "EnterWorktree cannot create a worktree from a subagent with a
    cwd override ... it would mutate the parent session's process-wide working
    directory." So the hook's EnterWorktree case is a backstop; its reason was
    not seen live.

- foreman-vision launcher (Windows Git Bash, 2026-10-25): `node ... serve &`
  in a subshell with all three streams redirected survives the Bash tool call
  and returns at once; `taskkill //PID <netstat listener pid> //T //F` freed
  the port. Not run on macOS (`lsof` / `kill` path).

- Hook payloads for the board hooks (recorded spool and raw spike data,
  2026-10-26; docs: code.claude.com/docs/en/hooks):
  - PostToolUse(Agent) from the main session carries `tool_input.description`,
    `tool_input.subagent_type` and `tool_response.agentId`, with no `agent_id`;
    a subagent's own calls carry `agent_id` and `agent_type`. For a background
    agent it arrives at spawn (+0.5-1.5s), not at the end, with status
    `async_launched`.
  - PostToolUse(Agent) and SubagentStart arrive in the same ms in either order,
    so the hooks upsert by agent id and neither depends on the other.
  - SubagentStart/SubagentStop carry `agent_id` and `agent_type` and no
    description; a SendMessage resume fires SubagentStart again with the same
    id. All events carry the master's `session_id`, also for worktree agents
    (only `cwd` differs). Workflow agents come as `workflow-subagent` and have
    no PostToolUse(Agent).
  - SubagentStop also fires for internal agents (prompt suggestions, /btw)
    with `agent_type` "" (30 of 32 in one session) and a real agent's stop has
    `last_assistant_message` null, so a stop means "turn ended", not "succeeded".
- Live check of the board hooks and the contract (2026-10-26, this session,
  new settings wired):
  - PostToolUse(Agent) added a board row with the right agent id and the
    description as job when a background agent was spawned.
  - SubagentStop moved running rows to `verifying`.
  - SubagentStart moved a resumed agent's row back to `running`.
  - The SubagentStart contract text was in a spawned agent's context (the agent
    quoted its first line).
  - An agent stopped with TaskStop fired no SubagentStop: its row stayed
    `running` and the master closed it with `set <agentId> failed`. Agents
    that failed by error were not tested.
  - A subagent's Monitor call was denied by nested-agent-guard with "Foreman
    mode: subagents do not leave background watchers. ..." (scenario 27
    passed live); `foreman-state.sh on` printed no "not wired" warning with
    the hooks registered.

## Open verification

- Not verified here: the PostToolUse(Agent) `status` value for a foreground
  Agent (the hook treats any status other than `async_launched` as finished,
  so `verifying`). In this environment (Claude Code CLI on Windows,
  2026-10-26) an Agent call without `run_in_background` was still launched
  async (`async_launched`), so the foreground status could not be observed.
  Also untested: SubagentStop for an agent that failed by error (the row may
  stay `running`; the master closes it with `set <agentId> failed`).

- Workflow, CronCreate and RemoteTrigger denials were not exercised live (they
  would act if the guard failed); check.sh covers their matcher routing and
  reasons.
- Reported by firstmate docs (kunchenguid/firstmate, 2026-10), not verified
  here: exit 2 from a SessionStart hook blocks the session start; `claude
  --continue` arrives as source `resume`; an Esc-interrupted turn fires no
  Stop hook; `stop_hook_active` stays true after any hook-driven continuation.

- The install one-liners come from the official installation guide
  (gastownhall/beads, docs/getting-started/installation.md) and were not run
  here, since bd was already installed.
