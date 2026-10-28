#!/usr/bin/env bash
# Starts and stops the foreman-vision web view for the master session.
# The repo is found from its installed hook (<repo>/hook/fv-hook.sh) in
# settings.json, which is only read; else from the root the foreman-vision
# plugin writes to foreman-vision/plugin-root, if <root>/hook/fv-hook.sh
# exists. The port comes from foreman-vision.conf
# (port=N), default 4780 - the same lookup foreman-vision itself does.
#
#   status   "not installed" (exit 2) | "stopped" (exit 1) | "running <url>" (exit 0)
#   url      print this session's URL: http://127.0.0.1:<port>/?session=<sid>
#   start    start `node <repo>/src/cli.ts serve` detached unless running; print the URL
#   stop     end the process listening on the port (with its child processes)
#   others   count of OTHER live foreman sessions, then their ids one per line;
#            0 when the server is not running
#   hide     hide this session's floor in the view (the server keeps running)
#   show     show it again
#   others/hide/show print one error line and exit 1 on a failed or bad answer

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
log="$cfg/foreman/state/vision.log"
port=$(sed -n 's/^[[:space:]]*port[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$cfg/foreman-vision.conf" 2>/dev/null | tail -n1)
port=${port:-4780}
sid=$(printf '%s' "${CLAUDE_CODE_SESSION_ID:-}" | tr -cd 'a-zA-Z0-9-')
url="http://127.0.0.1:$port/${sid:+?session=$sid}"

repo=$(jq -r '.. | strings | select(test("fv-hook\\.sh"))' "$cfg/settings.json" 2>/dev/null | tr -d '\r' |
  sed -n 's#^.*"\(.*\)/hook/fv-hook\.sh".*$#\1#p' | head -n1)
[ -n "$repo" ] || { # plugin install: no hook in settings.json, the plugin writes its root here
  repo=$(head -n1 "$cfg/foreman-vision/plugin-root" 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -f "$repo/hook/fv-hook.sh" ] || repo=
}
up() { curl -s --max-time 1 "http://127.0.0.1:$port/" 2>/dev/null | grep -q 'foreman-vision'; }
listener() { # pid of the process listening on the port
  if command -v lsof >/dev/null; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n1
  else # Windows netstat; the State column is localized, a 0.0.0.0:0 / [::]:0 peer means listening
    netstat -ano -p TCP 2>/dev/null | tr -d '\r' | awk -v p=":$port" \
      '$1 == "TCP" && substr($2, length($2) - length(p) + 1) == p && $3 ~ /:0$/ { print $5; exit }'
  fi
}

[ -n "$repo" ] || { echo "not installed"; exit 2; }
case "${1:-status}" in
  status) if up; then echo "running $url"; else echo stopped; exit 1; fi ;;
  url) echo "$url" ;;
  start)
    if up; then echo "$url"; exit 0; fi
    [ -f "$repo/web/dist/index.html" ] || { echo "foreman-vision: UI not built - run npm run build in $repo" >&2; exit 1; }
    mkdir -p "$(dirname "$log")"
    (cd "$repo" && node src/cli.ts serve --port "$port" </dev/null >"$log" 2>&1 &)
    for _ in $(seq 1 40); do up && { echo "$url"; exit 0; }; sleep 0.25; done
    echo "foreman-vision: did not start on port $port; log $log:" >&2; tail -n5 "$log" >&2; exit 1
    ;;
  stop)
    up || { echo "foreman-vision: not running"; exit 0; }
    pid=$(listener)
    [ -n "$pid" ] || { echo "foreman-vision: running but its process was not found - stop it by hand" >&2; exit 1; }
    if command -v taskkill >/dev/null; then taskkill //PID "$pid" //T //F >/dev/null
    else pkill -P "$pid" 2>/dev/null; kill "$pid"; fi
    for _ in $(seq 1 20); do up || { echo "foreman-vision: stopped"; exit 0; }; sleep 0.25; done
    echo "foreman-vision: pid $pid did not stop" >&2; exit 1
    ;;
  others)
    up || { echo 0; exit 0; }
    body=$(curl -sf --max-time 2 "http://127.0.0.1:$port/api/foremen" 2>/dev/null) && [ -n "$body" ] &&
      ids=$(printf '%s' "$body" | jq -r --arg s "$sid" '.sessions[] | strings | select(. != $s)' 2>/dev/null) ||
      { echo "foreman-vision: others failed (bad /api/foremen answer)" >&2; exit 1; }
    ids=${ids//$'\r'/}
    if [ -n "$ids" ]; then printf '%s\n' "$ids" | wc -l | tr -d ' '; printf '%s\n' "$ids"; else echo 0; fi
    ;;
  hide|show)
    [ -n "$sid" ] || { echo "foreman-vision: $1 failed (no session id)" >&2; exit 1; }
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 -X POST -H 'X-Foreman-Vision: 1' \
      "http://127.0.0.1:$port/api/floors/$sid/$1" 2>/dev/null)
    [ "$code" = 204 ] && { echo "foreman-vision: floor $1 ok"; exit 0; }
    [ "$code" = 000 ] && code="no answer" || code="HTTP $code"
    echo "foreman-vision: $1 failed ($code)" >&2; exit 1
    ;;
  *) echo "usage: foreman-vision.sh status|url|start|stop|others|hide|show" >&2; exit 2 ;;
esac
