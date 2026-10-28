#!/usr/bin/env bash
# PreToolUse hook on Edit|Write|NotebookEdit (wired in hooks/hooks.json).
# While foreman mode is on, the master does not edit the work's files: every
# change goes to an agent. Still allowed for the master: the config dir
# (memory, plans, skills) and the session scratchpad. Subagents (payload
# agent_id set) are never blocked.
# ponytail: Bash writes (sed, heredoc) pass unseen; matching Bash would run this
# on every read-only command. Fails open on unreadable input.
# Fields are split on \x1f, not tab: read merges empty leading tab fields.

p=$(cat)
IFS=$'\x1f' read -r agent_id sid path < <(printf '%s' "$p" |
  jq -r '[.agent_id // "", (.session_id // "" | gsub("[^a-zA-Z0-9-]"; "")),
          (.tool_input.file_path // .tool_input.notebook_path // "" | gsub("\\\\"; "/"))] | join("\u001f")' 2>/dev/null | tr -d '\r')
[ -z "$agent_id" ] && [ -n "$sid" ] && [ -n "$path" ] || exit 0
dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
f="$dir/foreman/state/active-$sid"
[ ! -L "$f" ] && [ -f "$f" ] || exit 0
case "$(head -n1 "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z')" in on|task) ;; *) exit 0 ;; esac

# Compare in one form: Git Bash sees /c/Users/..., tools send C:\Users\...
command -v cygpath >/dev/null && dir=$(cygpath -m "$dir") && path=$(cygpath -m "$path")
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }   # not ${x,,}: macOS ships bash 3.2
dir=$(lc "$dir") path=$(lc "$path")
case "$path" in
  "$dir"/*|*/temp/claude/*|*/tmp/claude*) exit 0 ;;
esac

reason="Foreman mode: the master does not edit work files. Hand this change to an agent (caveman:cavecrew-builder for 1-2 files, general-purpose otherwise). If the user wants you to edit directly, they run /foreman off."
jq -nc --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
