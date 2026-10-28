#!/usr/bin/env bash
# Deterministic checks for foreman's flag, agent board, status line badge and
# hooks. Runs against a throwaway CLAUDE_CONFIG_DIR; touches nothing real.
# Usage: bash eval/check.sh (from the repo root, or with any path to it)

here="$(cd "$(dirname "$0")/.." && pwd -P)" # -P: an inherited C:/ PWD would survive a relative cd
statusline="${STATUSLINE:-$here/bin/foreman-statusline.sh}"
export CLAUDE_CONFIG_DIR
CLAUDE_CONFIG_DIR=$(mktemp -d) || exit 1
trap 'rm -rf "$CLAUDE_CONFIG_DIR"' EXIT
s="$CLAUDE_CONFIG_DIR/foreman/state"
mkdir -p "$s"
sid=eval-sess
f="$s/active-$sid"
b="$s/board-$sid"
pass=0 fail=0

check() { # name expected actual
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: expected [$2] got [$3]"; fi
}
badge() {
  printf '{"session_id":"%s","model":{"display_name":"M"},"cwd":"/tmp"}' "$1" | bash "$statusline" |
    sed $'s/\033\\[[0-9;]*m//g' | grep -o 'FOREMAN:[A-Z]*' | head -n1
}
fullbadge() {
  printf '{"session_id":"%s","model":{"display_name":"M"},"cwd":"/tmp"}' "$1" | bash "$statusline" |
    sed $'s/\033\\[[0-9;]*m//g' | LC_ALL=C grep -o '\[FOREMAN:[^]]*\]' | head -n1
}
flag() { CLAUDE_CODE_SESSION_ID=$sid bash "$here/bin/foreman-state.sh" "$@" 2>/dev/null; }
start() { printf '{"session_id":"%s","source":"%s"}' "$sid" "$1" | bash "$here/hooks/session-start.sh"; }
guard() { printf '%s' "$1" | bash "$here/hooks/nested-agent-guard.sh"; }

# Status line badge
printf on > "$f";          check "badge on" "FOREMAN:ON" "$(badge $sid)"
printf task > "$f";        check "badge task" "FOREMAN:TASK" "$(badge $sid)"
printf 'task\nx' > "$f";   check "badge extra line" "FOREMAN:TASK" "$(badge $sid)"
printf 'evil$(x)' > "$f";  check "badge invalid" "FOREMAN:OFF" "$(badge $sid)"
rm -f "$f";                check "badge missing" "FOREMAN:OFF" "$(badge $sid)"
printf on > "$f";          check "badge other session" "FOREMAN:OFF" "$(badge other)"
                           check "badge no session id" "FOREMAN:OFF" "$(badge '')"

# Flag script
rm -f "$f"
flag task; check "task from off" "task" "$(flag get)"
flag end;  check "end removes task" "off" "$(flag get)"
flag on;   flag task; check "task keeps on" "on" "$(flag get)"
flag end;  check "end keeps on" "on" "$(flag get)"
flag off;  check "off" "off" "$(flag get)"
CLAUDE_CODE_SESSION_ID= bash "$here/bin/foreman-state.sh" on 2>/dev/null
check "no session id exits 1" "1" "$?"

# Agent board
flag on
check "empty board" "(no agents on the board)" "$(flag show)"
check "add prints 1" "1" "$(flag add general-purpose 'auth fix')"
check "add prints 2" "2" "$(flag add cavecrew-reviewer 'review #1' running)"
flag agent 1 a3f2c9d8e7b6
flag set 1 running
flag set 2 waiting $'needs-agent:\tfresh | review'
check "show row 1, full id" "| 1 | a3f2c9d8e7b6 | general-purpose | auth fix | 🔄 running |  |" "$(flag show | sed -n 3p)"
check "note sanitized" "| 2 | - | cavecrew-reviewer | review #1 | ⏸️ waiting | needs-agent: fresh / review |" "$(flag show | sed -n 4p)"
check "badge counts" "[FOREMAN:ON › 🔄 run:1 | ⏸️ wait:1]" "$(fullbadge $sid)"
flag set 1 bogus;          check "bad stage rejected" "2" "$?"
flag set 9 done;           check "missing row rejected" "2" "$?"
flag agent 9 x;            check "agent on missing row rejected" "2" "$?"
flag add general-purpose;  check "add without job rejected" "2" "$?"
flag add Plan x bogus;     check "add with bad stage rejected" "2" "$?"
flag set 1 done 'wrote C:\temp\new.md in D:\repo\new-api'
check "backslashes kept literally" "| 1 | a3f2c9d8e7b6 | general-purpose | auth fix | ✅ done | wrote C:\temp\new.md in D:\repo\new-api |" "$(flag show | sed -n 3p)"
check "board still two rows" "2" "$(wc -l < "$b" | tr -d ' ')"
check "done counted" "[FOREMAN:ON › ⏸️ wait:1 | ✅ done:1]" "$(fullbadge $sid)"
flag set 2 failed "gave up"
check "failed counted" "[FOREMAN:ON › ✅ done:1 | ❌ fail:1]" "$(fullbadge $sid)"
flag set 2 verifying
check "verifying counted" "[FOREMAN:ON › 🔍 check:1 | ✅ done:1]" "$(fullbadge $sid)"
flag set 2 waiting
flag prune
check "prune keeps unfinished" "1" "$(wc -l < "$b" | tr -d ' ')"
check "numbering continues" "3" "$(flag add Explore 'map config')"
flag task
check "task badge counts" "[FOREMAN:ON › ⏳ queue:1 | ⏸️ wait:1]" "$(fullbadge $sid)"
flag off; flag task; flag add Plan design running >/dev/null
check "task badge with counts" "[FOREMAN:TASK › 🔄 run:1]" "$(fullbadge $sid)"
flag off
check "off clears board" "no" "$([ -e "$b" ] && echo yes || echo no)"
flag task; flag add Plan design >/dev/null; flag end
check "end clears task board" "no" "$([ -e "$b" ] && echo yes || echo no)"
flag on; flag add Plan design >/dev/null; flag task; flag end
check "end keeps on board" "yes" "$([ -e "$b" ] && echo yes || echo no)"
flag off
flag on
for i in 1 2 3 4 5 6 7 8 9 10; do flag add Explore "job $i" >/dev/null & done; wait
check "parallel adds get unique rows" "10 10" "$(cut -f1 "$b" | sort -u | wc -l | tr -d ' ') $(wc -l < "$b" | tr -d ' ')"
check "lock released" "no" "$([ -e "$b.lock" ] && echo yes || echo no)"
mkdir "$b.lock"; touch -t 202001010000 "$b.lock"
check "stale lock broken" "11" "$(flag add Explore late)"
flag off

# SessionStart hook
flag on
check "re-inject names the skill dir" "yes" "$(start compact | jq -r '.hookSpecificOutput.additionalContext' | grep -qF "\${CLAUDE_SKILL_DIR} in it is $here)" && echo yes || echo no)"
check "compact re-injects" "yes" "$(start compact | jq -r '.hookSpecificOutput.additionalContext | test("Foreman mode is .on.") | if . then "yes" else "no" end')"
check "resume re-injects" "yes" "$(start resume | jq -r 'if .hookSpecificOutput.additionalContext then "yes" else "no" end')"
check "startup silent" "" "$(start startup)"
check "clear silent (new session id)" "" "$(start clear)"
touch -t 202001010000 "$f"
check "resumed old session keeps its flag" "yes" "$(start resume | jq -r 'if .hookSpecificOutput.additionalContext then "yes" else "no" end')"
flag off
check "no flag silent" "" "$(start compact)"
old="$s/active-old"; new="$s/active-new"; oldb="$s/board-old"
touch -t 202001010000 "$old" "$oldb"; touch "$new"; start startup >/dev/null
check "stale flag deleted" "no" "$([ -e "$old" ] && echo yes || echo no)"
check "stale board deleted" "no" "$([ -e "$oldb" ] && echo yes || echo no)"
check "fresh flag kept" "yes" "$([ -e "$new" ] && echo yes || echo no)"
sl="$CLAUDE_CONFIG_DIR/foreman/foreman-statusline.sh"
check "status line copied" "yes" "$(cmp -s "$here/bin/foreman-statusline.sh" "$sl" && echo yes || echo no)"
touch -t 202001010000 "$sl"; start startup >/dev/null
check "unchanged status line copy left alone" "$sl" "$(find "$sl" -mtime +14)"
printf 'old' > "$sl"; start startup >/dev/null
check "changed status line copy replaced" "yes" "$(cmp -s "$here/bin/foreman-statusline.sh" "$sl" && echo yes || echo no)"
rm -rf "$CLAUDE_CONFIG_DIR/foreman"; start startup >/dev/null
check "status line copy creates its dir" "yes" "$(cmp -s "$here/bin/foreman-statusline.sh" "$sl" && echo yes || echo no)"
mkdir -p "$s"

# Nested-agent guard
sub=$(printf '{"session_id":"%s","agent_id":"a1","tool_name":"Agent"}' "$sid")
main=$(printf '{"session_id":"%s","tool_name":"Agent"}' "$sid")
flag on
check "subagent denied" "deny" "$(guard "$sub" | jq -r '.hookSpecificOutput.permissionDecision')"
check "main allowed" "" "$(guard "$main")"
check "bad input fails open" "" "$(guard 'not json')"
flag task
check "subagent denied in task" "deny" "$(guard "$sub" | jq -r '.hookSpecificOutput.permissionDecision')"
flag off
flag end
check "subagent allowed when off" "" "$(guard "$sub")"
# Subagent calls beyond Agent/Task: messaging, workflows, schedules,
# orchestration skills. Other skills stay allowed.
call() { # tool [skill] [agent id]
  jq -nc --arg s "$sid" --arg t "$1" --arg k "${2:-}" --arg a "${3:-}" \
    '{session_id: $s, tool_name: $t, tool_input: {skill: $k}} + (if $a == "" then {} else {agent_id: $a} end)'
}
decision() { guard "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
flag on
check "subagent SendMessage denied" "deny" "$(decision "$(call SendMessage '' a1)")"
check "subagent Workflow denied" "deny" "$(decision "$(call Workflow '' a1)")"
check "subagent CronCreate denied" "deny" "$(decision "$(call CronCreate '' a1)")"
check "subagent SDD skill denied" "deny" "$(decision "$(call Skill superpowers:subagent-driven-development a1)")"
check "subagent foreman skill denied" "deny" "$(decision "$(call Skill foreman a1)")"
check "subagent other skill allowed" "" "$(decision "$(call Skill superpowers:writing-plans a1)")"
check "main SendMessage allowed" "" "$(decision "$(call SendMessage)")"
check "main SDD skill allowed" "" "$(decision "$(call Skill superpowers:subagent-driven-development)")"
# Each denied tool gets its own reason.
reason() { guard "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty'; }
has() { case "$2" in *"$1"*) echo yes ;; *) echo "no: $2" ;; esac; } # phrase text
check "Agent reason" "yes" "$(has 'do not spawn agents. Stop' "$(reason "$(call Agent '' a1)")")"
check "Task reason" "yes" "$(has 'do not spawn agents. Stop' "$(reason "$(call Task '' a1)")")"
check "SendMessage reason" "yes" "$(has 'do not message other agents' "$(reason "$(call SendMessage '' a1)")")"
check "Workflow reason" "yes" "$(has 'do not start workflows' "$(reason "$(call Workflow '' a1)")")"
check "CronCreate reason" "yes" "$(has 'needs-decision: <what should run, when>' "$(reason "$(call CronCreate '' a1)")")"
check "RemoteTrigger reason" "yes" "$(has 'needs-decision: <what should run, when>' "$(reason "$(call RemoteTrigger '' a1)")")"
check "subagent Monitor denied" "deny" "$(decision "$(call Monitor '' a1)")"
check "Monitor reason" "yes" "$(has 'background watchers' "$(reason "$(call Monitor '' a1)")")"
check "main Monitor allowed" "" "$(decision "$(call Monitor)")"
check "EnterWorktree reason" "yes" "$(has 'isolation: worktree' "$(reason "$(call EnterWorktree '' a1)")")"
check "Skill reason names skill" "yes" "$(has 'orchestration skills (subagent-driven-development)' "$(reason "$(call Skill superpowers:subagent-driven-development a1)")")"
check "fallback reason" "yes" "$(has 'start workflows/schedules/worktrees' "$(reason "$(call Other '' a1)")")"
flag off
# The matchers in the shipped hooks/hooks.json route these tools to the hooks.
settings="${SETTINGS:-$here/hooks/hooks.json}"
routed_ev() { # event hook-script tool; an entry without a matcher matches everything
  jq -r --arg e "$1" --arg h "$2" '.hooks[$e][]? | select(any(.hooks[]; .command | contains($h))) | .matcher // ".*"' "$settings" | tr -d '\r' |
    while IFS= read -r m; do [[ $3 =~ ^($m)$ ]] && echo yes; done | head -n1
}
routed() { routed_ev PreToolUse "$@"; } # hook-script tool
for t in Agent Task SendMessage Workflow CronCreate RemoteTrigger EnterWorktree Skill Monitor; do
  check "guard routes $t" "yes" "$(routed nested-agent-guard.sh $t)"
done
check "guard skips TaskCreate" "" "$(routed nested-agent-guard.sh TaskCreate)"
for t in Edit Write NotebookEdit; do
  check "edit guard routes $t" "yes" "$(routed master-edit-guard.sh $t)"
done
check "edit guard skips Read" "" "$(routed master-edit-guard.sh Read)"
check "board-sync routes PostToolUse Agent" "yes" "$(routed_ev PostToolUse board-sync.sh Agent)"
check "board-sync skips PostToolUse Bash" "" "$(routed_ev PostToolUse board-sync.sh Bash)"
check "board-sync on SubagentStart" "yes" "$(routed_ev SubagentStart board-sync.sh x)"
check "board-sync on SubagentStop" "yes" "$(routed_ev SubagentStop board-sync.sh x)"
check "contract on SubagentStart" "yes" "$(routed_ev SubagentStart subagent-contract.sh x)"

# Master edit guard
medit() { # path [tool] [agent id]
  jq -nc --arg s "$sid" --arg p "$1" --arg t "${2:-Edit}" --arg a "${3:-}" \
    '{session_id: $s, tool_name: $t, tool_input: (if $t == "NotebookEdit" then {notebook_path: $p} else {file_path: $p} end)}
     + (if $a == "" then {} else {agent_id: $a} end)' |
    bash "$here/hooks/master-edit-guard.sh" | jq -r '.hookSpecificOutput.permissionDecision // empty'
}
cfgwin=$CLAUDE_CONFIG_DIR; command -v cygpath >/dev/null && cfgwin=$(cygpath -w "$CLAUDE_CONFIG_DIR")
flag on
check "master repo edit denied" "deny" "$(medit 'C:\work\repo\src\a.ts')"
check "master unix path denied" "deny" "$(medit '/home/u/repo/src/a.ts' Write)"
check "master notebook denied" "deny" "$(medit 'C:\work\repo\nb.ipynb' NotebookEdit)"
check "master config dir allowed" "" "$(medit "$cfgwin\projects\x\memory\m.md")"
check "master scratchpad allowed" "" "$(medit 'C:\Users\U\AppData\Local\Temp\claude\abc\scratchpad\n.md' Write)"
check "master pr-body.md in work tree denied" "deny" "$(medit 'C:\work\repo\dev-reports\plans\f\pr-body.md' Write)"
check "subagent edit allowed" "" "$(medit 'C:\work\repo\src\a.ts' Edit a1)"
check "edit guard bad input fails open" "" "$(printf 'not json' | bash "$here/hooks/master-edit-guard.sh")"
flag task
check "master edit denied in task" "deny" "$(medit 'C:\work\repo\src\a.ts')"
flag off
check "master edit allowed when off" "" "$(medit 'C:\work\repo\src\a.ts')"

# Board hooks: payload shapes from real PostToolUse(Agent)/SubagentStart/Stop events
sync() { printf '%s' "$1" | bash "$here/hooks/board-sync.sh"; }
post() { # agent-id type job [status] [caller agent id]
  jq -nc --arg s "$sid" --arg r "$1" --arg t "$2" --arg d "$3" --arg st "${4:-async_launched}" --arg a "${5:-}" \
    '{session_id: $s, hook_event_name: "PostToolUse", tool_name: "Agent", tool_use_id: "toolu_1",
      tool_input: {description: $d, prompt: "p", subagent_type: $t},
      tool_response: {isAsync: true, status: $st, agentId: $r, description: $d}}
     + (if $a == "" then {} else {agent_id: $a, agent_type: "general-purpose"} end)'
}
sa() { # event agent-id [agent type]
  jq -nc --arg s "$sid" --arg e "$1" --arg a "$2" --arg t "${3-general-purpose}" \
    '{session_id: $s, hook_event_name: $e, agent_id: $a, agent_type: $t}'
}
rowid() { awk -F'\t' -v a="$1" '$2 == a { print $1 "|" $3 "|" $4 "|" $5 "|" $6 }' "$b"; }
rown() { awk -F'\t' -v n="$1" '$1 == n { print $2 "|" $3 "|" $4 "|" $5 }' "$b"; }
rows() { wc -l < "$b" | tr -d ' '; }
flag on
sync "$(post a1 Explore 'map config')"
check "hook adds row on spawn" "1|Explore|map config|running|" "$(rowid a1)"
sync "$(post a2 Explore x async_launched a1)"
check "hook ignores subagent Agent call" "1" "$(rows)"
sync "$(post a1 Explore 'map config')"
check "hook duplicate PostToolUse one row" "1" "$(rows)"
sync "$(post a3 Plan design completed)"
check "hook foreground lands verifying" "2|Plan|design|verifying|" "$(rowid a3)"
flag set a1 waiting 'needs-info'
check "set by agent id" "1|Explore|map config|waiting|needs-info" "$(rowid a1)"
flag set zz done; check "set unknown agent id rejected" "2" "$?"
sync "$(sa SubagentStop a1)"
check "stop keeps waiting row" "waiting" "$(rowid a1 | cut -d'|' -f4)"
sync "$(sa SubagentStart a1)"
check "start resumes waiting row" "running" "$(rowid a1 | cut -d'|' -f4)"
sync "$(sa SubagentStop a1 '')"
check "stop ignores empty agent_type" "running" "$(rowid a1 | cut -d'|' -f4)"
sync "$(sa SubagentStop a1)"
check "stop moves running to verifying" "verifying" "$(rowid a1 | cut -d'|' -f4)"
before=$(cat "$b"); sync "$(sa SubagentStop zz)"
check "stop ignores unknown id" "$before" "$(cat "$b")"
sync "$(sa SubagentStart a4)"; sync "$(post a4 Explore race)"
check "start before post then post adds running" "3|Explore|race|running|" "$(rowid a4)"
q=$(flag add general-purpose 'step one'); n0=$(rows)
sync "$(post a5 general-purpose 'step one')"
check "spawn claims queued row" "a5|general-purpose|step one|running $n0" "$(rown "$q") $(rows)"
q=$(flag add general-purpose 'step two')
sync "$(post a6 general-purpose 'step 2')"
check "spawn skips queued row with other job" "-|general-purpose|step two|queued $((q + 1))" "$(rown "$q") $(rowid a6 | cut -d'|' -f1)"
t1=$(flag add Explore twin); t2=$(flag add Explore twin)
sync "$(post a7 Explore twin)"
check "spawn claims lowest of two queued twins" "a7 -" "$(rown "$t1" | cut -d'|' -f1) $(rown "$t2" | cut -d'|' -f1)"
check "hook prints nothing" "" "$(sync "$(post a8 Plan quiet)"; sync "$(sa SubagentStart a8)"; sync "$(sa SubagentStop a8)")"
check "hook bad input fails open" "0:" "$(out=$(printf 'not json' | bash "$here/hooks/board-sync.sh"); echo "$?:$out")"
flag off
sync "$(post a9 Plan off)"
check "hook silent when off" "no" "$([ -e "$b" ] && echo yes || echo no)"

# SubagentStart contract hook: injects references/agent-contract.md while the flag is on|task
contract="$here/references/agent-contract.md"
ct() { printf '%s' "$1" | bash "$here/hooks/subagent-contract.sh"; }
ctx() { ct "$1" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null | tr -d "\r"; }
flag on
check "contract injected when on" "yes" "$([ "$(ctx "$(sa SubagentStart c1)")" = "$(cat "$contract")" ] && echo yes || echo no)"
flag task
check "contract injected in task" "yes" "$([ "$(ctx "$(sa SubagentStart c1)")" = "$(cat "$contract")" ] && echo yes || echo no)"
flag on
check "contract skips workflow-subagent" "" "$(ct "$(sa SubagentStart c2 workflow-subagent)")"
check "contract skips empty agent_type" "" "$(ct "$(sa SubagentStart c3 '')")"
c=$(ctx "$(sa SubagentStart c1)")
check "contract has needs-agent status" "yes" "$(has 'needs-agent:' "$c")"
check "contract has no-cd rule" "yes" "$(has 'Do not start a command with cd' "$c")"
check "contract has worktree rule" "yes" "$(has 'git worktree add/remove/prune' "$c")"
check "contract under 4000 chars" "yes" "$([ "${#c}" -gt 0 ] && [ "${#c}" -lt 4000 ] && echo yes || echo no)"
check "contract bad input fails open" "0:" "$(out=$(printf 'not json' | bash "$here/hooks/subagent-contract.sh"); echo "$?:$out")"
flag off
check "contract silent when off" "" "$(ct "$(sa SubagentStart c1)")"
flag on
for i in 1 2 3 4 5 6 7 8 9 10; do flag spawned "p$i" Explore "job $i" running & done; wait
check "parallel hook spawns unique rows" "10 10" "$(cut -f1 "$b" | sort -u | wc -l | tr -d ' ') $(rows)"
flag off

# foreman-vision launcher: repo from the hook in settings.json; starts no server
vis() { CLAUDE_CODE_SESSION_ID=$sid bash "$here/bin/foreman-vision.sh" "$@" 2>&1; }
fvrepo="$CLAUDE_CONFIG_DIR/fv repo"; mkdir -p "$fvrepo"
printf '{"hooks":{}}' > "$CLAUDE_CONFIG_DIR/settings.json"
check "vision without hook" "not installed" "$(vis status)"
jq -n --arg c "bash \"$fvrepo/hook/fv-hook.sh\" \"/x/spool\"" \
  '{hooks: {Stop: [{hooks: [{type: "command", command: $c}]}]}}' > "$CLAUDE_CONFIG_DIR/settings.json"
printf 'port=1\n' > "$CLAUDE_CONFIG_DIR/foreman-vision.conf" # nothing listens on port 1
check "vision stopped on a free port" "stopped" "$(vis status)"
check "vision url has session" "http://127.0.0.1:1/?session=$sid" "$(vis url)"
check "vision start needs a built UI" "foreman-vision: UI not built - run npm run build in $fvrepo" "$(vis start)"
check "vision stop when not running" "foreman-vision: not running" "$(vis stop)"
check "vision others when not running" "0" "$(vis others)"
check "vision hide when not running" $'foreman-vision: hide failed (no answer)\nexit 1' "$(vis hide; echo "exit $?")"
check "vision show when not running" $'foreman-vision: show failed (no answer)\nexit 1' "$(vis show; echo "exit $?")"
# A stand-in curl: / is the UI, /api/foremen answers $FV_FOREMEN (empty: 404,
# curl -f exit 22), a floor POST answers 204 only for this session's hide/show
# with the X-Foreman-Vision header, else 403; any other path 404.
fvis() { # foremen-body command
  ( curl() {
      local a u= h=
      for a; do case $a in http*) u=$a ;; 'X-Foreman-Vision: 1') h=1 ;; esac; done
      case $u in
        */) printf foreman-vision ;;
        */api/foremen) [ -n "$FV_FOREMEN" ] || return 22; printf '%s' "$FV_FOREMEN" ;;
        */api/floors/eval-sess/hide | */api/floors/eval-sess/show) [ -n "$h" ] && printf 204 || printf 403 ;;
        *) printf 404 ;;
      esac
    }
    export -f curl; FV_FOREMEN=$1 vis "${@:2}" )
}
check "vision others skips own session" $'2\nb\nc' "$(fvis '{"sessions":["eval-sess","b","c"]}' others)"
check "vision others alone" "0" "$(fvis '{"sessions":["eval-sess"]}' others)"
fverr=$'foreman-vision: others failed (bad /api/foremen answer)\nexit 1'
check "vision others on a non-json answer" "$fverr" "$(fvis '<!doctype html>' others; echo "exit $?")"
check "vision others on a 404" "$fverr" "$(fvis '' others; echo "exit $?")"
check "vision others without sessions" "$fverr" "$(fvis '{}' others; echo "exit $?")"
check "vision hide" "foreman-vision: floor hide ok" "$(fvis '' hide)"
check "vision show" "foreman-vision: floor show ok" "$(fvis '' show)"
check "vision hide without session id" $'foreman-vision: hide failed (no session id)\nexit 1' "$(sid='' fvis '' hide; echo "exit $?")"
check "vision show on 404" $'foreman-vision: show failed (HTTP 404)\nexit 1' "$(sid=old fvis '' show; echo "exit $?")"
check "vision hide on 404" $'foreman-vision: hide failed (HTTP 404)\nexit 1' "$(sid=old fvis '' hide; echo "exit $?")"
# Plugin install: the root comes from foreman-vision/plugin-root when
# settings.json has no fv-hook.sh; the "UI not built" line names the repo used.
fvplug="$CLAUDE_CONFIG_DIR/fv plugin"; fvmark="$CLAUDE_CONFIG_DIR/foreman-vision/plugin-root"
mkdir -p "$fvplug/hook" "$CLAUDE_CONFIG_DIR/foreman-vision"; : > "$fvplug/hook/fv-hook.sh"
printf '%s\n' "$fvplug" > "$fvmark"
check "vision settings hook wins over the plugin marker" "foreman-vision: UI not built - run npm run build in $fvrepo" "$(vis start)"
printf '{"hooks":{}}' > "$CLAUDE_CONFIG_DIR/settings.json"
check "vision repo from the plugin marker" "foreman-vision: UI not built - run npm run build in $fvplug" "$(vis start)"
check "vision stopped via the plugin marker" "stopped" "$(vis status)"
printf '%s\r\n' "$fvplug" > "$fvmark"
check "vision plugin marker with CRLF" "foreman-vision: UI not built - run npm run build in $fvplug" "$(vis start)"
printf '%s\n' "$fvrepo" > "$fvmark" # no hook/fv-hook.sh there
check "vision plugin marker without fv-hook.sh" $'not installed\nexit 2' "$(vis status; echo "exit $?")"

# Behaviour rules: each phrase must stay in SKILL.md or a reference, so moving
# a section into references/ keeps them; lines are joined so rewrapping is fine.
ruletext=$(cat "$here/SKILL.md" "$here"/references/*.md | tr -s '\n\t ' ' ')
has_rule() { # name phrase...; every phrase must appear, each searched literally
  local p miss=
  for p in "${@:2}"; do printf '%s' "$ruletext" | grep -qF -- "$p" || miss="$miss[$p]"; done
  check "rule $1" "" "$miss"
}
has_rule "C6 mid-task change" 'The user changes the ask mid-task'
has_rule "C8 PR URL" 'Every PR as its full `https://` URL'
has_rule "C8 final message stands alone" 'stands alone'
has_rule "C9 smallest alternative" 'smallest alternative'
has_rule "C10 effort" 'effort: "low"'
has_rule "C10 bug regression test" 'the reproduction becomes its regression test'
has_rule "D12 verified diff commit" "committing an agent's diff you have verified"
has_rule "A3 paste moments" 'only in the final report'
has_rule "one-shot stays open" 'stays open across gates'
has_rule "gates stay with you" 'gates stay with you'
has_rule "beads plan folder" 'No plan folder means no tracking'
has_rule "contract pointer" 'gives every agent the standing contract (`references/agent-contract.md`'
has_rule "description is job" "Give every Agent call a short \`description\`: it is the row's job"
has_rule "queued claim" 'the hook then takes over that row instead of opening a new one'
has_rule "TaskStop row" 'no hook fires for a stopped agent'
has_rule "vision language" "in the conversation's language"
has_rule "vision hide beside others" 'never offer `stop`' 'On yes run `hide`' 'run `show`'
has_rule "vision show after start" 'once it succeeds run `show` too' 'unless it prints an error'

# Sections moved out of SKILL.md: the reference exists and SKILL.md points to it
for r in called-skills one-shot wiring; do
  check "reference $r exists" yes "$([ -s "$here/references/$r.md" ] && echo yes || echo no)"
done
for r in called-skills one-shot beads wiring; do
  check "SKILL.md points to $r" yes "$(grep -qF "references/$r.md" "$here/SKILL.md" && echo yes || echo no)"
done

# ceiling = words after the 1.12.0 shrink + 15%; prune before raising it
words=$(wc -w < "$here/SKILL.md" | tr -d ' \r')
check "SKILL.md word ceiling" yes "$([ "$words" -le 2958 ] && echo yes || echo "no ($words words > 2958)")"

echo "foreman eval: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
