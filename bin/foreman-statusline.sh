#!/usr/bin/env bash
# foreman's status line segment. Reads Claude Code's statusLine JSON on stdin,
# prints [FOREMAN:ON|TASK|OFF] plus the board's stage counts.
# Pure bash 3.2+, no jq, no forks.
IFS= read -r -d '' in
re='"session_id"[[:space:]]*:[[:space:]]*"([^"]*)"'
[[ $in =~ $re ]] && sid=${BASH_REMATCH[1]//[^a-zA-Z0-9-]/}
dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/foreman/state"
f="$dir/active-$sid" b="$dir/board-$sid" mode=""
if [ -n "$sid" ] && [ ! -L "$f" ] && [ -f "$f" ]; then
  IFS= read -r mode < "$f"
fi
case "$mode" in
  on) label=ON ;;
  task) label=TASK ;;
  *) printf '\033[2m[FOREMAN:OFF]\033[0m'; exit 0 ;;
esac
q=0 r=0 w=0 v=0 d=0 x=0 counts=""
if [ ! -L "$b" ] && [ -f "$b" ]; then
  while IFS=$'\t' read -r _ _ _ _ st _; do
    case "$st" in queued) q=$((q+1));; running) r=$((r+1));; waiting) w=$((w+1));;
      verifying) v=$((v+1));; done) d=$((d+1));; failed) x=$((x+1));; esac
  done < "$b"
fi
for kv in "⏳ queue:$q" "🔄 run:$r" "⏸️ wait:$w" "🔍 check:$v" "✅ done:$d" "❌ fail:$x"; do
  [ "${kv#*:}" -gt 0 ] && counts+="${counts:+ | }$kv"
done
printf '\033[38;5;135m[FOREMAN:%s%s]\033[0m' "$label" "${counts:+ › $counts}"
