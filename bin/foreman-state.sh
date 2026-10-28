#!/usr/bin/env bash
# Sole writer of foreman's per-session state in $CLAUDE_CONFIG_DIR/foreman/state:
#   active-<sid>  mode flag, one line: "on" or "task"
#   board-<sid>   agent board, TSV: n, agent id, type, job, stage, note
# Read by bin/foreman-statusline.sh and this skill's hooks.
#
# Mode:   on | task | end | off | get
#   on    session-wide mode
#   task  one-shot run; never downgrades an existing "on"
#   end   end of a one-shot run; removes a "task" flag and its board
#   off   remove the flag and the board
#   get   print the current mode (on|task|off)
# Board:  add <type> <job> [stage]   add a row, print its number (stage: queued)
#         agent <n> <agent id>       record the spawned agent's id
#         set <n|agent id> <stage> [note]  stage: queued|running|waiting|verifying|done|failed
#         spawned <agent id> <type> <job> <stage>  upsert by agent id, else claim the
#                                    lowest queued row with no id and the same type + job
#         event start|stop <agent id>  start: row -> running; stop: running -> verifying
#         show                       markdown table
#         prune                      drop done/failed rows
#
# Subagents inherit the master's session id and an identical environment
# (CLAUDE_CODE_CHILD_SESSION=1 is set in the main session too), so nothing here
# can tell them apart: only the master's skill text mentions this script.
# Hooks tell them apart by the payload's agent_id (hooks/board-sync.sh calls
# spawned/event for the master's agents).

sid=$(printf '%s' "${CLAUDE_CODE_SESSION_ID:-}" | tr -cd 'a-zA-Z0-9-')
if [ -z "$sid" ]; then
  echo "foreman-state: no session id, status line badge unavailable" >&2
  exit 1
fi
dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/foreman/state"
mkdir -p "$dir" || exit 1
f="$dir/active-$sid"
b="$dir/board-$sid"
cur=$(head -n1 "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z')

clean() { printf '%s' "$1" | tr '\t\r\n|' '   /'; }
stage_ok() {
  case "$1" in queued|running|waiting|verifying|done|failed) return 0 ;; esac
  echo "foreman-state: stage must be queued|running|waiting|verifying|done|failed" >&2
  return 1
}
row_ok() {
  if ! awk -F'\t' -v n="$1" '$1 == n { found = 1 } END { exit !found }' "$b" 2>/dev/null; then
    echo "foreman-state: no board row $1" >&2
    return 1
  fi
}
lock() { # serialize board writes; a lock dir older than ~6s is a dead writer's
  until mkdir "$b.lock" 2>/dev/null; do
    # GNU stat (Linux, Git Bash) first, BSD stat (macOS) as the fallback. If the
    # lock vanishes between the two calls, GNU `stat -f` prints file-system text,
    # so only a plain number counts as an mtime.
    m=$(stat -c %Y "$b.lock" 2>/dev/null || stat -f %m "$b.lock" 2>/dev/null)
    case "$m" in
      ''|*[!0-9]*) ;;
      *) [ $(($(date +%s) - m)) -gt 6 ] && rmdir "$b.lock" 2>/dev/null ;;
    esac
    sleep 0.05
  done
  trap 'rmdir "$b.lock" 2>/dev/null' EXIT
}
update() { # n column value [column value]
  # Values go through ENVIRON: awk -v would turn "C:\new" into a newline.
  v1=$3 v2=${5:-} awk -F'\t' -v OFS='\t' -v n="$1" -v c1="$2" -v c2="${4:-0}" \
    '$1 == n { $c1 = ENVIRON["v1"]; if (c2) $c2 = ENVIRON["v2"] } { print }' "$b" > "$b.tmp" &&
    mv "$b.tmp" "$b"
}

id_row() { # print the row number holding agent id $1
  v=$(clean "$1") awk -F'\t' '$2 == ENVIRON["v"] { print $1; exit }' "$b" 2>/dev/null
}

case "${1:-get}" in
  on)   printf on > "$f" ;;
  task) [ "$cur" = on ] || printf task > "$f" ;;
  end)  if [ "$cur" = task ]; then lock; rm -f "$f" "$b"; fi ;;
  off)  lock; rm -f "$f" "$b" ;;
  get)  case "$cur" in on|task) echo "$cur" ;; *) echo off ;; esac ;;

  add)
    [ -n "${2:-}" ] && [ -n "${3:-}" ] || { echo "usage: add <type> <job> [stage]" >&2; exit 2; }
    stage=${4:-queued}; stage_ok "$stage" || exit 2
    lock
    n=$(( $(awk -F'\t' 'BEGIN { m = 0 } $1 > m { m = $1 } END { print m }' "$b" 2>/dev/null || echo 0) + 1 ))
    printf '%s\t-\t%s\t%s\t%s\t\n' "$n" "$(clean "$2")" "$(clean "$3")" "$stage" >> "$b"
    echo "$n"
    ;;
  agent)
    [ -n "${2:-}" ] && [ -n "${3:-}" ] || { echo "usage: agent <n> <agent id>" >&2; exit 2; }
    lock; row_ok "$2" || exit 2
    update "$2" 2 "$(clean "$3")"
    ;;
  set)
    [ -n "${2:-}" ] && [ -n "${3:-}" ] || { echo "usage: set <n|agent id> <stage> [note]" >&2; exit 2; }
    stage_ok "$3" || exit 2
    lock
    n=$2; [[ $n =~ ^[0-9]+$ ]] || n=$(id_row "$2")
    row_ok "${n:-$2}" || exit 2
    update "$n" 5 "$3" 6 "$(clean "${4:-}")"
    ;;
  spawned)
    [ -n "${2:-}" ] && [ -n "${3:-}" ] && [ -n "${4:-}" ] && [ -n "${5:-}" ] ||
      { echo "usage: spawned <agent id> <type> <job> <stage>" >&2; exit 2; }
    stage_ok "$5" || exit 2
    lock
    id=$(clean "$2") type=$(clean "$3") job=$(clean "$4")
    n=$(id_row "$id")
    if [ -n "$n" ]; then update "$n" 5 "$5"; exit; fi
    n=$(t=$type j=$job awk -F'\t' '$2 == "-" && $5 == "queued" && $3 == ENVIRON["t"] && $4 == ENVIRON["j"] &&
      (m == "" || $1 + 0 < m + 0) { m = $1 } END { print m }' "$b" 2>/dev/null)
    if [ -n "$n" ]; then update "$n" 2 "$id" 5 "$5"; exit; fi
    n=$(( $(awk -F'\t' 'BEGIN { m = 0 } $1 > m { m = $1 } END { print m }' "$b" 2>/dev/null || echo 0) + 1 ))
    printf '%s\t%s\t%s\t%s\t%s\t\n' "$n" "$id" "$type" "$job" "$5" >> "$b"
    ;;
  event) # unknown ids (internal and workflow agents) are left alone
    case "${2:-}" in start|stop) ;; *) echo "usage: event start|stop <agent id>" >&2; exit 2 ;; esac
    [ -n "${3:-}" ] && [ -f "$b" ] || exit 0
    lock
    n=$(id_row "$3"); [ -n "$n" ] || exit 0
    if [ "$2" = start ]; then update "$n" 5 running
    elif awk -F'\t' -v n="$n" '$1 == n && $5 == "running" { r = 1 } END { exit !r }' "$b"; then update "$n" 5 verifying
    fi
    ;;
  show)
    if [ ! -s "$b" ]; then echo "(no agents on the board)"; exit 0; fi
    echo "| # | Agent | Type | Job | Stage | Note |"
    echo "|---|-------|------|-----|-------|------|"
    awk -F'\t' '
      BEGIN { i["queued"] = "⏳"; i["running"] = "🔄"; i["waiting"] = "⏸️"
              i["verifying"] = "🔍"; i["done"] = "✅"; i["failed"] = "❌" }
      { printf "| %s | %s | %s | %s | %s %s | %s |\n", $1, $2, $3, $4, i[$5], $5, $6 }' "$b"
    ;;
  prune)
    [ -f "$b" ] || exit 0
    lock
    awk -F'\t' '$5 != "done" && $5 != "failed"' "$b" > "$b.tmp" && mv "$b.tmp" "$b"
    ;;
  *) echo "usage: foreman-state.sh on|task|end|off|get|add|agent|set|spawned|event|show|prune" >&2; exit 2 ;;
esac
