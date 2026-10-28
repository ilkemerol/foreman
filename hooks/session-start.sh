#!/usr/bin/env bash
# SessionStart hook (wired in hooks/hooks.json, no matcher).
# - Every start: delete foreman flags and agent boards older than 14 days,
#   after refreshing this session's own so a resumed old session keeps them.
# - compact / resume: if this session's flag is set, re-inject the mode,
#   because the flag survives while the skill text may have left the context.
#   (/clear starts a new session id, so the mode simply ends there.)
# - Every start: copy bin/foreman-statusline.sh to $CLAUDE_CONFIG_DIR/foreman/
#   when missing or changed; the plugin's own dir moves on every update, so
#   statusLine points at this stable copy.
# Fails open: any parse problem exits 0 with no output.

dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/foreman/state"
p=$(cat)
sid=$(printf '%s' "$p" | jq -r '.session_id // empty' 2>/dev/null | tr -cd 'a-zA-Z0-9-')
src=$(printf '%s' "$p" | jq -r '.source // empty' 2>/dev/null)

[ -n "$sid" ] && touch -c "$dir/active-$sid" "$dir/board-$sid" 2>/dev/null
find "$dir" -maxdepth 1 -type f \( -name "active-*" -o -name "board-*" \) -mtime +14 -delete 2>/dev/null

root="$(cd "$(dirname "$0")/.." && pwd -P)" # -P: one spelling, not an inherited C:/ PWD
sl="${dir%/state}/foreman-statusline.sh"
cmp -s "$root/bin/foreman-statusline.sh" "$sl" ||
  { mkdir -p "${sl%/*}" && cp "$root/bin/foreman-statusline.sh" "$sl.tmp" && mv "$sl.tmp" "$sl"; } 2>/dev/null

case "$src" in compact|resume) ;; *) exit 0 ;; esac
[ -n "$sid" ] || exit 0

f="$dir/active-$sid"
[ ! -L "$f" ] && [ -f "$f" ] || exit 0
mode=$(head -n1 "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z')
case "$mode" in on|task) ;; *) exit 0 ;; esac

msg="Foreman mode is '$mode' in this session (session $src). The mode is already set: re-read $root/SKILL.md now (\${CLAUDE_SKILL_DIR} in it is $root), skip its argument table, and follow the rest before acting. After a resume, background agents from the previous process are gone; after a compaction they may still be running. Run foreman-state.sh show: the board lists every spawned agent with its full id and stage; reconcile its unfinished rows (and in_progress beads pieces, if tracked) against live agents before spawning replacements."

jq -nc --arg m "$msg" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$m}}'
