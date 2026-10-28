#!/usr/bin/env bash
# SubagentStart hook. While foreman mode is on (on|task) for the session, injects
# references/agent-contract.md (Boundary/Return rules) into every agent's context
# as additionalContext, so the master's prompts no longer carry it.
# Skips agents with an empty agent_type (Claude Code internal) and workflow-subagent.
# Prints nothing and exits 0 when off, on bad input or an unreadable contract file.
# The session id comes from the payload; Windows jq ends lines with \r, hence the tr.

here="$(cd "$(dirname "$0")/.." && pwd)"
p=$(cat)
IFS=$'\x1f' read -r sid atype < <(printf '%s' "$p" | jq -r '[(.session_id // "" | gsub("[^a-zA-Z0-9-]"; "")), (.agent_type // "" | tostring | gsub("[\r\n\u001f]"; " "))] | join("\u001f")' 2>/dev/null | tr -d '\r')
[ -n "$sid" ] && [ -n "$atype" ] && [ "$atype" != workflow-subagent ] || exit 0
f="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/foreman/state/active-$sid"
[ ! -L "$f" ] && [ -f "$f" ] || exit 0
case "$(head -n1 "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z')" in on|task) ;; *) exit 0 ;; esac
c="$here/references/agent-contract.md"
[ -r "$c" ] || exit 0
jq -nrc --rawfile m "$c" '{hookSpecificOutput:{hookEventName:"SubagentStart",additionalContext:$m}}' 2>/dev/null
exit 0
