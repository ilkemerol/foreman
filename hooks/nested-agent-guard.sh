#!/usr/bin/env bash
# PreToolUse hook (wired in hooks/hooks.json, matcher
# Agent|Task|SendMessage|Workflow|CronCreate|RemoteTrigger|EnterWorktree|Skill|Monitor).
# While foreman mode is on for the session, a subagent may not spawn agents,
# message other agents, start workflows, schedules or worktrees, or run an
# orchestration skill: it returns `needs-agent` / `needs-info` to the master,
# which acts and relays. Other skills stay allowed. The main session is never
# blocked. Fails open on unreadable input.
# A subagent is recognized only by the payload's agent_id: the environment
# (CLAUDE_CODE_CHILD_SESSION included) is identical in main and subagents.
# Fields are split on \x1f, not tab: read merges empty leading tab fields.
# Windows jq ends lines with \r, hence the tr.

p=$(cat)
IFS=$'\x1f' read -r agent_id sid tool skill < <(printf '%s' "$p" |
  jq -r '[.agent_id // "", (.session_id // "" | gsub("[^a-zA-Z0-9-]"; "")), .tool_name // "", .tool_input.skill // ""] | join("\u001f")' 2>/dev/null | tr -d '\r')
[ -n "$agent_id" ] && [ -n "$sid" ] || exit 0
if [ "$tool" = Skill ]; then
  case "${skill##*:}" in subagent-driven-development|dispatching-parallel-agents|foreman) ;; *) exit 0 ;; esac
fi
f="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/foreman/state/active-$sid"
[ ! -L "$f" ] && [ -f "$f" ] || exit 0
case "$(head -n1 "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z')" in on|task) ;; *) exit 0 ;; esac

case "$tool" in
  Agent|Task) reason="Foreman mode: subagents do not spawn agents. Stop and return 'needs-agent: <purpose> -- <draft prompt>' to the master; it spawns that agent and sends you the result." ;;
  SendMessage) reason="Foreman mode: subagents do not message other agents or the master mid-task. Put what you need in your return: 'needs-info: <what> -- <source>' or 'needs-agent: <purpose> -- <draft prompt>'; the master relays." ;;
  Workflow) reason="Foreman mode: subagents do not start workflows. If the work needs more agents, return 'needs-agent: <purpose> -- <draft prompt>' to the master." ;;
  CronCreate|RemoteTrigger) reason="Foreman mode: subagents do not schedule or trigger runs. Return 'needs-decision: <what should run, when>' to the master; scheduling is the user's call." ;;
  EnterWorktree) reason="Foreman mode: the master gives worktree isolation when it spawns an agent (isolation: worktree). Keep working in your current directory, or return 'needs-decision: isolated worktree needed -- <why>' to the master." ;;
  Monitor) reason="Foreman mode: subagents do not leave background watchers. Run the check in the foreground and finish it before you return, or return 'needs-decision: <what to wait for>' to the master." ;;
  Skill) reason="Foreman mode: subagents do not run orchestration skills (${skill##*:}). Do your piece directly without it, or return 'needs-agent: <purpose> -- <draft prompt>' to the master." ;;
  *) reason="Foreman mode: subagents do not spawn agents, message other agents, start workflows/schedules/worktrees, or run orchestration skills. Stop and return 'needs-agent: <purpose> -- <draft prompt>' or 'needs-info: <what> -- <source>' to the master; it acts and sends you the result." ;;
esac
jq -nc --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
