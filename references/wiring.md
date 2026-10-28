# Wiring

Read when a hook, the badge or the board misbehaves, or before changing this
plugin's hooks or scripts (`SKILL.md` *Wiring and tests*). Paths below are
relative to foreman's folder: the plugin root (`${CLAUDE_PLUGIN_ROOT}`) or
the repo clone at `~/.claude/skills/foreman`. `~/.claude` stands for
`$CLAUDE_CONFIG_DIR` when that is set.

- `hooks/hooks.json` - foreman's hooks. Both install methods load them as a
  plugin, and nothing goes into `settings.json`: the marketplace install is
  `foreman@foreman`; a repo clone holds `.claude-plugin/plugin.json`, so
  Claude Code loads it as `foreman@skills-dir`. Hooks an older clone merged
  into `settings.json` (commands with `/skills/foreman/hooks/`) must go, and
  so must one of two installs: either way every hook would run twice
  (`INSTALL.md` steps 4 and 5). SessionStart runs
  `hooks/session-start.sh`; PreToolUse runs `hooks/nested-agent-guard.sh`
  (matcher
  `Agent|Task|SendMessage|Workflow|CronCreate|RemoteTrigger|EnterWorktree|Skill|Monitor`)
  and `hooks/master-edit-guard.sh` (matcher `Edit|Write|NotebookEdit`).
  PostToolUse (matcher `Agent|Task`), SubagentStart and SubagentStop run
  `hooks/board-sync.sh`, which keeps the board rows; SubagentStart
  also runs `hooks/subagent-contract.sh`, which injects
  `references/agent-contract.md` while the flag is `on` or `task`.
- `~/.claude/foreman/state/` - the flag and board files (`active-<sid>`,
  `board-<sid>`); SessionStart deletes ones idle for 14 days. `vision.log` is
  the output of the server `foreman-vision.sh start` launched.
- `~/.claude/foreman/foreman-statusline.sh` - a copy of
  `bin/foreman-statusline.sh` that SessionStart refreshes when it is missing
  or changed. The plugin folder moves on every update; this path does not.
  A plugin cannot set `statusLine`, so the user points `statusLine` in
  `~/.claude/settings.json` at the copy, directly or from their own status
  line script. It reads the flag and counts the board's stages in pure bash,
  renders the badge.
- `~/.claude/settings.json` - holds no foreman hooks. `foreman-vision.sh`
  only reads it, to find foreman-vision's repo from its installed
  `<repo>/hook/fv-hook.sh` hook.
- `references/agent-contract.md` - the standing contract every agent gets.
- `eval/check.sh` tests all of it, the matchers in `hooks/hooks.json`
  included; `eval/SCENARIOS.md` lists behavior scenarios.
