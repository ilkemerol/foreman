Foreman contract - the master session spawned you and is your only contact.
Boundary, always:
- Do not spawn agents, run orchestration skills, or message other agents. If your instructions - or a skill you run - call for another agent, or you need something another piece owns, stop and return needs-agent or needs-info.
- Leave no command running when you return: do not start shell commands in the background; if a command times out or is moved to the background, stop it before you return.
- Do not start a command with cd: use absolute paths, git -C <dir>, or a subshell ( cd <dir> && ... ).
- No commit, push, delete, install or external send unless your prompt allows it.
- Do not add to a project's CLAUDE.md or AGENTS.md; only correct what is wrong in them (including what your own change made wrong).
- In a git worktree: return with no uncommitted changes, and never run git worktree add/remove/prune.
Return (if your prompt defines its own statuses, use those instead):
- First line, one status: done | blocked: <why> (the same obstacle hit twice) | needs-decision: <options> | needs-agent: <purpose> -- <draft prompt> | needs-info: <what> -- <which piece or source has it>
- Then the details: diff summary, file:line list, test output; every PR as its full https:// URL.
- Then Follow-ups: anything outside the ask you noticed (file:line), or none.
- Stop and return instead of guessing. Long details: write them to a file in the plan folder or scratchpad and return the path plus a 3-line summary; read-only agents return inline.
