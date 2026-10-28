#!/usr/bin/env bash
# PostToolUse (matcher Agent), SubagentStart and SubagentStop hook. While
# foreman mode is on for the session, keeps the agent board in step with the
# master's agents through bin/foreman-state.sh (the board's only writer):
#   PostToolUse   the master spawned an agent: upsert its row by agent id.
#                 Background launches (status async_launched) land running;
#                 any other status means the agent already finished: verifying.
#   SubagentStart row -> running (SendMessage resume); unknown ids are ignored.
#   SubagentStop  running -> verifying; waiting/done/failed are kept.
# A subagent's own Agent call carries agent_id and is skipped. Internal agents
# have an empty agent_type and no row. PostToolUse and SubagentStart can arrive
# in either order, so neither depends on the other.
# Prints nothing, always exits 0, fails open on unreadable input. The session id
# comes from the payload, not the environment. Fields are split on \x1f (read
# merges empty leading tab fields); Windows jq ends lines with \r, hence the tr.

here="$(cd "$(dirname "$0")/.." && pwd)"
p=$(cat)
IFS=$'\x1f' read -r ev sid aid atype rid rtype st job < <(printf '%s' "$p" | jq -r '[
  .hook_event_name // "", (.session_id // "" | gsub("[^a-zA-Z0-9-]"; "")), .agent_id // "", .agent_type // "",
  (.tool_response | if type == "object" then .agentId // "" else "" end),
  (.tool_input.subagent_type // .tool_response.agentType // "general-purpose"),
  (.tool_response | if type == "object" then .status // "" else "" end),
  (.tool_input.description // "" | if . == "" then "-" else . end)
  ] | map(tostring | gsub("[\r\n\u001f]"; " ")) | join("\u001f")' 2>/dev/null | tr -d '\r')
[ -n "$sid" ] || exit 0
f="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/foreman/state/active-$sid"
[ ! -L "$f" ] && [ -f "$f" ] || exit 0
case "$(head -n1 "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z')" in on|task) ;; *) exit 0 ;; esac

fs() { CLAUDE_CODE_SESSION_ID=$sid bash "$here/bin/foreman-state.sh" "$@" >/dev/null 2>&1; }
case "$ev" in
  PostToolUse)
    [ -z "$aid" ] && [ -n "$rid" ] || exit 0
    stage=verifying; [ "$st" = async_launched ] && stage=running
    fs spawned "$rid" "$rtype" "$job" "$stage" ;;
  SubagentStart) [ -n "$aid" ] && [ -n "$atype" ] && fs event start "$aid" ;;
  SubagentStop)  [ -n "$aid" ] && [ -n "$atype" ] && fs event stop "$aid" ;;
esac
exit 0
